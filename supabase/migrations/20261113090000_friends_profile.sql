-- M18: teman di luar circle (minta + terima, ala BeReal friends).
--
-- - friendships: satu baris per pasangan (requester → addressee), status
--   pending/accepted. Hanya lewat RPC; user cuma bisa membaca baris miliknya.
-- - shares_circle(a, b) kini berarti "satu circle ATAU berteman". Semua aturan
--   lihat (profil, foto, catch + kunci feed, koleksi, komentar, reaksi,
--   notifikasi "teman udah catch") otomatis berlaku untuk teman.
-- - friends_feed(): catch hari ini milik sendiri + teman (bentuk sama dengan
--   circle_feed v5, ikut terkunci sebelum catch).
-- - find_user(username): cari user untuk ditambah (data publik minimal).
-- - Notifikasi permintaan teman & diterima lewat antrean friend_notifications
--   (dikirim send-activity bersama antrean reaksi/komentar).
-- - Profil (M19): user_profile(id) & user_collection(id) untuk diri sendiri,
--   teman, dan anggota satu circle.

create table public.friendships (
  requester_id uuid not null references public.profiles (id) on delete cascade,
  addressee_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  primary key (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);

-- Satu baris per pasangan, ke arah mana pun.
create unique index friendships_pair_idx
  on public.friendships (least(requester_id, addressee_id), greatest(requester_id, addressee_id));
create index friendships_addressee_idx on public.friendships (addressee_id);

alter table public.friendships enable row level security;
revoke all on public.friendships from anon, authenticated;
grant select on public.friendships to authenticated;

create policy "friendships: baca milik sendiri"
  on public.friendships for select to authenticated
  using (auth.uid() in (requester_id, addressee_id));

create function public.are_friends(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and least(f.requester_id, f.addressee_id) = least(a, b)
      and greatest(f.requester_id, f.addressee_id) = greatest(a, b)
  );
$$;

revoke execute on function public.are_friends(uuid, uuid) from public, anon;
grant execute on function public.are_friends(uuid, uuid) to authenticated;

-- "Terhubung": satu circle ATAU berteman (nama lama dipertahankan karena
-- dipakai banyak policy).
create or replace function public.shares_circle(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.circle_members m1
    join public.circle_members m2 on m2.circle_id = m1.circle_id
    where m1.user_id = a and m2.user_id = b
  ) or public.are_friends(a, b);
$$;

-- ---------------------------------------------------------------------------
-- Notifikasi teman
-- ---------------------------------------------------------------------------
create table public.friend_notifications (
  id bigint generated always as identity primary key,
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  actor_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null check (kind in ('request', 'accepted')),
  created_at timestamptz not null default now(),
  sent_at timestamptz
);
create index friend_notifications_unsent_idx
  on public.friend_notifications (created_at) where sent_at is null;
create index friend_notifications_recipient_idx on public.friend_notifications (recipient_id);
create index friend_notifications_actor_idx on public.friend_notifications (actor_id);

alter table public.friend_notifications enable row level security;
revoke all on public.friend_notifications from anon, authenticated;

create function public.claim_friend_notifications()
returns table (token text, actor_name text, kind text, actor_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
    with claimed as (
      update public.friend_notifications n
         set sent_at = now()
       where n.id in (
         select n2.id from public.friend_notifications n2
         where n2.sent_at is null
         for update skip locked
       )
      returning n.*
    )
    select p.fcm_token, coalesce(a.display_name, a.username, 'seseorang'),
           c.kind, c.actor_id
    from claimed c
    join public.profiles p on p.id = c.recipient_id
    join public.profiles a on a.id = c.actor_id
    where p.fcm_token is not null
      and c.created_at > now() - interval '1 day';
end;
$$;

revoke execute on function public.claim_friend_notifications() from public, anon, authenticated;
grant execute on function public.claim_friend_notifications() to service_role;

-- Dispatch tiap menit juga melihat antrean teman.
create or replace function public.dispatch_activity_notifications()
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.activity_notifications
   where sent_at is not null and sent_at < now() - interval '7 days';
  delete from public.friend_notifications
   where sent_at is not null and sent_at < now() - interval '7 days';
  if not exists (select 1 from public.activity_notifications where sent_at is null)
     and not exists (select 1 from public.friend_notifications where sent_at is null) then
    return null;
  end if;
  return public.post_send_activity('activity');
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC teman
-- ---------------------------------------------------------------------------
-- Hubungan pemanggil dengan user lain.
create function public.friend_relation(p_other uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p_other = auth.uid() then 'self'
    else coalesce((
      select case
        when f.status = 'accepted' then 'friend'
        when f.requester_id = auth.uid() then 'outgoing'
        else 'incoming'
      end
      from public.friendships f
      where least(f.requester_id, f.addressee_id) = least(auth.uid(), p_other)
        and greatest(f.requester_id, f.addressee_id) = greatest(auth.uid(), p_other)
    ), 'none')
  end;
$$;

revoke execute on function public.friend_relation(uuid) from public, anon;
grant execute on function public.friend_relation(uuid) to authenticated;

-- Cari user lewat username persis (tanpa awalan/daftar, supaya tidak bisa
-- dipakai mengumpulkan semua username).
create function public.find_user(p_username text)
returns table (user_id uuid, username text, display_name text, avatar_path text, relation text)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.username, p.display_name, p.avatar_path, public.friend_relation(p.id)
  from public.profiles p
  where auth.uid() is not null
    and p.username = lower(btrim(p_username));
$$;

revoke execute on function public.find_user(text) from public, anon;
grant execute on function public.find_user(text) to authenticated;

-- Kirim permintaan. Kalau dia sudah meminta duluan → langsung berteman.
-- Hasil: relasi baru ('outgoing' / 'friend').
create function public.send_friend_request(p_user_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_rel text;
begin
  if v_uid is null then
    raise exception 'harus login' using errcode = '28000';
  end if;
  if p_user_id is null or p_user_id = v_uid
     or not exists (select 1 from public.profiles where id = p_user_id) then
    raise exception 'user tidak ditemukan' using errcode = 'FR008';
  end if;

  v_rel := public.friend_relation(p_user_id);
  if v_rel in ('friend', 'outgoing') then
    return v_rel;
  end if;
  if v_rel = 'incoming' then
    update public.friendships
       set status = 'accepted', responded_at = now()
     where requester_id = p_user_id and addressee_id = v_uid;
    insert into public.friend_notifications (recipient_id, actor_id, kind)
    values (p_user_id, v_uid, 'accepted');
    return 'friend';
  end if;

  if (select count(*) from public.friendships
      where requester_id = v_uid and status = 'pending') >= 50 then
    raise exception 'terlalu banyak permintaan menunggu' using errcode = 'FR009';
  end if;

  insert into public.friendships (requester_id, addressee_id)
  values (v_uid, p_user_id)
  on conflict do nothing;
  insert into public.friend_notifications (recipient_id, actor_id, kind)
  values (p_user_id, v_uid, 'request');
  return 'outgoing';
end;
$$;

-- Terima / tolak permintaan masuk.
create function public.respond_friend_request(p_user_id uuid, p_accept boolean)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'harus login' using errcode = '28000';
  end if;
  if coalesce(p_accept, false) then
    update public.friendships
       set status = 'accepted', responded_at = now()
     where requester_id = p_user_id and addressee_id = v_uid and status = 'pending';
    if not found then
      raise exception 'permintaan tidak ditemukan' using errcode = 'P0002';
    end if;
    insert into public.friend_notifications (recipient_id, actor_id, kind)
    values (p_user_id, v_uid, 'accepted');
    return 'friend';
  end if;
  delete from public.friendships
   where requester_id = p_user_id and addressee_id = v_uid and status = 'pending';
  return 'none';
end;
$$;

-- Batalkan permintaan keluar atau hapus pertemanan.
create function public.remove_friend(p_user_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.friendships f
   where auth.uid() is not null
     and least(f.requester_id, f.addressee_id) = least(auth.uid(), p_user_id)
     and greatest(f.requester_id, f.addressee_id) = greatest(auth.uid(), p_user_id);
$$;

-- Teman + permintaan masuk/keluar milik pemanggil.
create function public.my_friends()
returns table (
  user_id uuid,
  username text,
  display_name text,
  avatar_path text,
  relation text,
  since timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select o.id, o.username, o.display_name, o.avatar_path,
         case
           when f.status = 'accepted' then 'friend'
           when f.requester_id = auth.uid() then 'outgoing'
           else 'incoming'
         end,
         coalesce(f.responded_at, f.created_at)
  from public.friendships f
  join public.profiles o
    on o.id = case when f.requester_id = auth.uid() then f.addressee_id else f.requester_id end
  where auth.uid() in (f.requester_id, f.addressee_id)
  order by (f.status = 'pending' and f.addressee_id = auth.uid()) desc,
           coalesce(o.display_name, o.username);
$$;

revoke execute on function public.send_friend_request(uuid) from public, anon;
revoke execute on function public.respond_friend_request(uuid, boolean) from public, anon;
revoke execute on function public.remove_friend(uuid) from public, anon;
revoke execute on function public.my_friends() from public, anon;
grant execute on function public.send_friend_request(uuid) to authenticated;
grant execute on function public.respond_friend_request(uuid, boolean) to authenticated;
grant execute on function public.remove_friend(uuid) to authenticated;
grant execute on function public.my_friends() to authenticated;

-- ---------------------------------------------------------------------------
-- Feed teman (bentuk sama dengan circle_feed v5)
-- ---------------------------------------------------------------------------
create function public.friends_feed()
returns table (
  catch_id uuid,
  user_id uuid,
  username text,
  display_name text,
  avatar_path text,
  created_at timestamptz,
  is_late boolean,
  late_minutes int,
  timing text,
  locked boolean,
  animal_name text,
  animal_type text,
  encounter_count int,
  caption text,
  animal_photo_path text,
  selfie_photo_path text,
  like_count int,
  laugh_count int,
  comment_count int,
  liked_by_me boolean,
  laughed_by_me boolean,
  reaction_counts jsonb,
  my_reactions text[]
)
language sql
stable
security definer
set search_path = ''
as $$
  with feed as (
    select c.*, not public.can_view_catch_content(c.user_id, c.catch_date) as locked
    from public.catches c
    where c.catch_date = public.jakarta_today()
      and (c.user_id = auth.uid() or public.are_friends(auth.uid(), c.user_id))
  )
  select
    f.id,
    f.user_id,
    p.username,
    p.display_name,
    p.avatar_path,
    f.created_at,
    f.is_late,
    case when f.is_late then
      greatest(0, floor(extract(epoch from (f.created_at - (d.sent_at + interval '1 hour'))) / 60))::int
    end,
    f.timing,
    f.locked,
    case when not f.locked then a.name end,
    case when not f.locked then coalesce(a.animal_type, f.ai_type) end,
    case when not f.locked then coalesce(a.encounter_count, 1) end,
    case when not f.locked then f.caption end,
    case when not f.locked then f.animal_photo_path end,
    case when not f.locked then f.selfie_photo_path end,
    case when f.locked then 0 else
      (select count(*)::int from public.reactions r where r.catch_id = f.id and r.type = 'like') end,
    case when f.locked then 0 else
      (select count(*)::int from public.reactions r where r.catch_id = f.id and r.type = 'laugh') end,
    case when f.locked then 0 else
      (select count(*)::int from public.comments m where m.catch_id = f.id) end,
    exists (select 1 from public.reactions r
            where r.catch_id = f.id and r.type = 'like' and r.user_id = auth.uid()),
    exists (select 1 from public.reactions r
            where r.catch_id = f.id and r.type = 'laugh' and r.user_id = auth.uid()),
    case when f.locked then '{}'::jsonb else
      coalesce((select jsonb_object_agg(x.type, x.n)
                from (select r.type, count(*)::int as n from public.reactions r
                      where r.catch_id = f.id group by r.type) x), '{}'::jsonb) end,
    coalesce((select array_agg(r.type order by r.type) from public.reactions r
              where r.catch_id = f.id and r.user_id = auth.uid()), '{}')
  from feed f
  left join public.profiles p on p.id = f.user_id
  left join public.animals a on a.id = f.animal_id
  left join public.daily_drops d on d.drop_date = f.catch_date
  order by f.created_at desc;
$$;

revoke execute on function public.friends_feed() from public, anon;
grant execute on function public.friends_feed() to authenticated;

-- ---------------------------------------------------------------------------
-- Profil (M19): diri sendiri, teman, atau satu circle
-- ---------------------------------------------------------------------------
create function public.user_profile(p_user_id uuid)
returns table (
  user_id uuid,
  username text,
  display_name text,
  avatar_path text,
  streak int,
  longest_streak int,
  animal_count int,
  catch_count int,
  friend_count int,
  relation text
)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.username, p.display_name, p.avatar_path,
         coalesce(case when s.last_catch_date >= public.jakarta_today() - 1 then s.current end, 0),
         coalesce(s.longest, 0),
         (select count(*)::int from public.animals a where a.owner_id = p.id and a.removed_at is null),
         (select count(*)::int from public.catches c where c.user_id = p.id),
         (select count(*)::int from public.friendships f
           where f.status = 'accepted' and p.id in (f.requester_id, f.addressee_id)),
         public.friend_relation(p.id)
  from public.profiles p
  left join public.streaks s on s.user_id = p.id
  where p.id = p_user_id
    and (p.id = auth.uid() or public.shares_circle(auth.uid(), p.id));
$$;

-- Koleksi user lain (bentuk sama dengan my_collection v4).
create function public.user_collection(p_user_id uuid)
returns table (
  animal_id uuid,
  name text,
  kind text,
  animal_type text,
  encounter_count int,
  first_seen_at timestamptz,
  last_seen_at timestamptz,
  last_animal_photo_path text,
  last_personality text,
  last_catch_id uuid,
  last_cutout_path text,
  last_cutout_attempted boolean,
  last_catch_date date,
  last_area_label text,
  pinned_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select a.id, a.name, a.kind, a.animal_type, a.encounter_count,
         a.first_seen_at, a.last_seen_at,
         lc.animal_photo_path, coalesce(a.personality, lc.personality),
         lc.id, lc.cutout_path, coalesce(lc.cutout_attempted, false),
         lc.catch_date, lc.area_label, a.pinned_at
  from public.animals a
  left join lateral (
    -- Catch terakhir yang boleh dilihat (catch hari ini terkunci sebelum
    -- pemanggil catch).
    select c.id, c.animal_photo_path, c.cutout_path, c.cutout_attempted,
           c.catch_date, c.area_label,
           coalesce(c.personality, c.ai_personality) as personality
    from public.catches c
    where c.animal_id = a.id
      and public.can_view_catch_content(c.user_id, c.catch_date)
    order by c.created_at desc
    limit 1
  ) lc on true
  where a.owner_id = p_user_id
    and a.removed_at is null
    and (p_user_id = auth.uid() or public.shares_circle(auth.uid(), p_user_id))
  order by a.last_seen_at desc, a.name;
$$;

revoke execute on function public.user_profile(uuid) from public, anon;
revoke execute on function public.user_collection(uuid) from public, anon;
grant execute on function public.user_profile(uuid) to authenticated;
grant execute on function public.user_collection(uuid) to authenticated;
