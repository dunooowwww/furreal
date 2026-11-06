-- M14: notifikasi reaksi/komentar di catch sendiri + pengingat streak.
--
-- - Reaksi & komentar orang lain di catch user masuk antrean
--   activity_notifications (trigger). pg_cron tiap menit memanggil Edge
--   Function send-activity lewat pg_net kalau ada antrean; fungsi itu
--   mengklaim antrean (dikelompokkan per penerima & catch) lalu kirim FCM.
--   Reaksi dari orang yang sama ke catch yang sama hanya dikabarkan sekali
--   (bolak-balik toggle tidak spam).
-- - 20:00 WIB: pengingat ke user yang streak-nya masih hidup (catch terakhir
--   kemarin) tapi belum catch hari ini. Sekali per hari (streaks.reminded_on).
--
-- URL fungsi diturunkan dari Vault daily_drop_url (send-daily-drop →
-- send-activity) dan memakai Bearer daily_drop_secret yang sama, jadi tidak
-- ada Vault baru yang perlu diisi.

create table public.activity_notifications (
  id bigint generated always as identity primary key,
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  actor_id uuid not null references public.profiles (id) on delete cascade,
  catch_id uuid not null references public.catches (id) on delete cascade,
  kind text not null check (kind in ('reaction', 'comment')),
  comment_id uuid references public.comments (id) on delete cascade,
  created_at timestamptz not null default now(),
  sent_at timestamptz
);

create unique index activity_notifications_reaction_once
  on public.activity_notifications (recipient_id, actor_id, catch_id)
  where kind = 'reaction';
create index activity_notifications_unsent_idx
  on public.activity_notifications (created_at) where sent_at is null;
create index activity_notifications_actor_idx on public.activity_notifications (actor_id);
create index activity_notifications_catch_idx on public.activity_notifications (catch_id);
create index activity_notifications_comment_idx on public.activity_notifications (comment_id);

-- Hanya untuk server (service role lewat RPC); tidak ada akses lewat API.
alter table public.activity_notifications enable row level security;
revoke all on public.activity_notifications from anon, authenticated;

create function public.queue_activity_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
begin
  select c.user_id into v_owner from public.catches c where c.id = new.catch_id;
  if v_owner is null or v_owner = new.user_id then
    return null;
  end if;
  if tg_table_name = 'reactions' then
    insert into public.activity_notifications (recipient_id, actor_id, catch_id, kind)
    values (v_owner, new.user_id, new.catch_id, 'reaction')
    on conflict (recipient_id, actor_id, catch_id) where kind = 'reaction' do nothing;
  else
    insert into public.activity_notifications (recipient_id, actor_id, catch_id, kind, comment_id)
    values (v_owner, new.user_id, new.catch_id, 'comment', new.id);
  end if;
  return null;
end;
$$;

revoke execute on function public.queue_activity_notification() from public, anon, authenticated;

create trigger reactions_queue_activity
  after insert on public.reactions
  for each row execute function public.queue_activity_notification();

create trigger comments_queue_activity
  after insert on public.comments
  for each row execute function public.queue_activity_notification();

-- Dipanggil send-activity: ambil semua antrean (sekali saja), dikelompokkan
-- per penerima & catch. Penerima tanpa token / kabar lebih dari 6 jam ikut
-- ditandai terkirim tapi tidak dikembalikan.
create function public.claim_activity_notifications()
returns table (
  token text,
  catch_id uuid,
  animal_name text,
  actor_names text[],
  reactions int,
  comments int,
  last_comment text
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
    with claimed as (
      update public.activity_notifications a
         set sent_at = now()
       where a.id in (
         select a2.id from public.activity_notifications a2
         where a2.sent_at is null
         for update skip locked
       )
      returning a.*
    ),
    per_actor as (
      select cl.recipient_id, cl.catch_id, cl.actor_id,
             max(cl.created_at) as last_at,
             count(*) filter (where cl.kind = 'reaction') as r,
             count(*) filter (where cl.kind = 'comment') as cm
      from claimed cl
      group by cl.recipient_id, cl.catch_id, cl.actor_id
    )
    select p.fcm_token,
           pa.catch_id,
           an.name,
           array_agg(coalesce(ap.display_name, ap.username, 'teman lo') order by pa.last_at desc),
           sum(pa.r)::int,
           sum(pa.cm)::int,
           (
             select coalesce(cp.display_name, cp.username, 'teman lo') || ': ' || co.body
             from claimed cl2
             join public.comments co on co.id = cl2.comment_id
             join public.profiles cp on cp.id = co.user_id
             where cl2.recipient_id = pa.recipient_id
               and cl2.catch_id = pa.catch_id
               and cl2.kind = 'comment'
             order by cl2.created_at desc
             limit 1
           )
    from per_actor pa
    join public.profiles p on p.id = pa.recipient_id
    join public.profiles ap on ap.id = pa.actor_id
    join public.catches c on c.id = pa.catch_id
    left join public.animals an on an.id = c.animal_id
    where p.fcm_token is not null
      and pa.last_at > now() - interval '6 hours'
    group by p.fcm_token, pa.recipient_id, pa.catch_id, an.name;
end;
$$;

-- Pengingat streak: user yang catch terakhirnya kemarin (streak masih hidup)
-- dan belum catch hari ini. Sekali per hari per user.
alter table public.streaks add column reminded_on date;

create function public.claim_streak_reminders()
returns table (token text, streak int)
language sql
security definer
set search_path = ''
as $$
  update public.streaks s
     set reminded_on = public.jakarta_today()
    from public.profiles p
   where p.id = s.user_id
     and p.fcm_token is not null
     and s.current > 0
     and s.last_catch_date = public.jakarta_today() - 1
     and s.reminded_on is distinct from public.jakarta_today()
  returning p.fcm_token, s.current;
$$;

-- Kirim POST ke send-activity (pg_net). Null kalau Vault belum diisi.
create function public.post_send_activity(p_job text)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text;
  v_secret text;
begin
  select s.decrypted_secret into v_url
    from vault.decrypted_secrets s where s.name = 'daily_drop_url';
  select s.decrypted_secret into v_secret
    from vault.decrypted_secrets s where s.name = 'daily_drop_secret';
  if v_url is null or v_secret is null then
    raise warning 'send-activity: isi Vault daily_drop_url & daily_drop_secret dulu';
    return null;
  end if;
  return net.http_post(
    url := replace(v_url, 'send-daily-drop', 'send-activity'),
    body := jsonb_build_object('job', p_job),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_secret
    ),
    timeout_milliseconds := 55000
  );
end;
$$;

-- Tiap menit: panggil send-activity kalau ada antrean; bersihkan yang lama.
create function public.dispatch_activity_notifications()
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.activity_notifications
   where sent_at is not null and sent_at < now() - interval '7 days';
  if not exists (
    select 1 from public.activity_notifications where sent_at is null
  ) then
    return null;
  end if;
  return public.post_send_activity('activity');
end;
$$;

create function public.dispatch_streak_reminders()
returns bigint
language sql
security definer
set search_path = ''
as $$
  select public.post_send_activity('streak');
$$;

revoke execute on function public.claim_activity_notifications() from public, anon, authenticated;
revoke execute on function public.claim_streak_reminders() from public, anon, authenticated;
revoke execute on function public.post_send_activity(text) from public, anon, authenticated;
revoke execute on function public.dispatch_activity_notifications() from public, anon, authenticated;
revoke execute on function public.dispatch_streak_reminders() from public, anon, authenticated;
grant execute on function public.claim_activity_notifications() to service_role;
grant execute on function public.claim_streak_reminders() to service_role;

select cron.schedule('activity-dispatch', '* * * * *', 'select public.dispatch_activity_notifications()');
-- 20:00 WIB = 13:00 UTC.
select cron.schedule('streak-reminder', '0 13 * * *', 'select public.dispatch_streak_reminders()');
