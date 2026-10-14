-- M6: daily drop terjadwal + notifikasi FCM, catch dikunci sampai drop turun,
-- token FCM per HP.
--
-- Alur:
--   09:55 WIB  pg_cron → schedule_daily_drop(): pilih jam acak 10:00–20:00 WIB
--              (sama untuk semua user), simpan di daily_drops.scheduled_at.
--   tiap menit pg_cron → dispatch_daily_drop(): kalau jadwal hari ini sudah lewat
--              dan belum terkirim, panggil Edge Function send-daily-drop lewat pg_net.
--   send-daily-drop → claim_daily_drop() mengisi sent_at (atomik, sekali sehari),
--              lalu kirim FCM ke semua token & hapus token yang tidak valid.
-- URL function dan secret-nya dibaca dari Supabase Vault (bukan dari migrasi):
--   daily_drop_url, daily_drop_secret.

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

-- ---------------------------------------------------------------------------
-- daily_drops: jadwal rahasia, user hanya melihat drop yang sudah turun.
-- ---------------------------------------------------------------------------
alter table public.daily_drops add column scheduled_at timestamptz;

drop policy "daily_drops: semua user login bisa membaca" on public.daily_drops;
create policy "daily_drops: user login membaca drop yang sudah turun"
  on public.daily_drops for select to authenticated
  using (sent_at is not null);

-- Jam drop tidak boleh bocor duluan: scheduled_at tidak bisa dibaca lewat API.
revoke select on public.daily_drops from authenticated;
grant select (drop_date, sent_at) on public.daily_drops to authenticated;

-- Jadwalkan drop hari ini (idempoten). Kalau dipanggil terlambat (cron 09:55
-- terlewat), jam acak dipilih dari sisa jendela; lewat 20:00 → sekarang.
create function public.schedule_daily_drop()
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_today date := public.jakarta_today();
  v_start timestamptz := greatest(
    now(), (v_today + time '10:00') at time zone 'Asia/Jakarta'
  );
  v_end timestamptz := (v_today + time '20:00') at time zone 'Asia/Jakarta';
  v_at timestamptz;
begin
  v_at := case
    when v_end > v_start then date_trunc('minute', v_start + random() * (v_end - v_start))
    else now()
  end;

  insert into public.daily_drops (drop_date, scheduled_at)
  values (v_today, v_at)
  on conflict (drop_date) do nothing;

  select d.scheduled_at into v_at
    from public.daily_drops d
    where d.drop_date = v_today;
  return v_at;
end;
$$;

-- Dipanggil pg_cron tiap menit. Mengembalikan id request pg_net, atau null
-- kalau belum waktunya / sudah terkirim / Vault belum diisi.
create function public.dispatch_daily_drop()
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_today date := public.jakarta_today();
  v_url text;
  v_secret text;
begin
  -- Jaga-jaga kalau job 09:55 tidak jalan.
  if now() >= (v_today + time '09:55') at time zone 'Asia/Jakarta' then
    perform public.schedule_daily_drop();
  end if;

  if not exists (
    select 1 from public.daily_drops d
    where d.drop_date = v_today and d.sent_at is null and d.scheduled_at <= now()
  ) then
    return null;
  end if;

  select s.decrypted_secret into v_url
    from vault.decrypted_secrets s where s.name = 'daily_drop_url';
  select s.decrypted_secret into v_secret
    from vault.decrypted_secrets s where s.name = 'daily_drop_secret';
  if v_url is null or v_secret is null then
    raise warning 'daily drop: isi Vault daily_drop_url & daily_drop_secret dulu';
    return null;
  end if;

  -- Kalau request gagal, sent_at tetap kosong dan menit berikutnya dicoba lagi.
  return net.http_post(
    url := v_url,
    body := jsonb_build_object('drop_date', v_today),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_secret
    ),
    timeout_milliseconds := 55000
  );
end;
$$;

-- Dipanggil send-daily-drop: tandai drop hari ini turun sekarang. Atomik, jadi
-- hanya satu pemanggil yang mendapat sent_at; sisanya null (sudah terkirim).
create function public.claim_daily_drop()
returns timestamptz
language sql
security definer
set search_path = ''
as $$
  update public.daily_drops
     set sent_at = now()
   where drop_date = public.jakarta_today()
     and sent_at is null
     and scheduled_at <= now()
  returning sent_at;
$$;

revoke execute on function public.schedule_daily_drop() from public, anon, authenticated;
revoke execute on function public.dispatch_daily_drop() from public, anon, authenticated;
revoke execute on function public.claim_daily_drop() from public, anon, authenticated;
grant execute on function public.schedule_daily_drop() to service_role;
grant execute on function public.dispatch_daily_drop() to service_role;
grant execute on function public.claim_daily_drop() to service_role;

-- 09:55 WIB = 02:55 UTC (pg_cron memakai UTC).
select cron.schedule('daily-drop-schedule', '55 2 * * *', 'select public.schedule_daily_drop()');
select cron.schedule('daily-drop-dispatch', '* * * * *', 'select public.dispatch_daily_drop()');

-- ---------------------------------------------------------------------------
-- Token FCM: diisi lewat RPC saja, satu token hanya untuk satu akun.
-- ---------------------------------------------------------------------------
revoke update (fcm_token) on public.profiles from authenticated;

create function public.set_fcm_token(p_token text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_token text := nullif(btrim(p_token), '');
begin
  if v_uid is null then
    raise exception 'harus login' using errcode = '28000';
  end if;
  if char_length(v_token) > 4096 then
    raise exception 'token tidak valid' using errcode = '22023';
  end if;

  if v_token is not null then
    -- HP yang sama dipakai akun lain tanpa keluar: lepas dari akun lama.
    update public.profiles set fcm_token = null
     where fcm_token = v_token and id <> v_uid;
  end if;
  update public.profiles set fcm_token = v_token where id = v_uid;
end;
$$;

revoke execute on function public.set_fcm_token(text) from public, anon;
grant execute on function public.set_fcm_token(text) to authenticated;

-- Untuk send-daily-drop (service role).
create function public.fcm_tokens()
returns setof text
language sql
stable
security definer
set search_path = ''
as $$
  select p.fcm_token from public.profiles p where p.fcm_token is not null;
$$;

create function public.clear_fcm_tokens(p_tokens text[])
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count int;
begin
  update public.profiles set fcm_token = null where fcm_token = any (p_tokens);
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke execute on function public.fcm_tokens() from public, anon, authenticated;
revoke execute on function public.clear_fcm_tokens(text[]) from public, anon, authenticated;
grant execute on function public.fcm_tokens() to service_role;
grant execute on function public.clear_fcm_tokens(text[]) to service_role;

-- ---------------------------------------------------------------------------
-- create_catch v4: dikunci sampai daily drop hari ini turun (FR005).
-- ---------------------------------------------------------------------------
create or replace function public.create_catch(
  p_catch_id uuid,
  p_animal_name text,
  p_animal_kind text,
  p_area_label text,
  p_location_hidden boolean,
  p_animal_type text default null,
  p_personality text default null,
  p_animal_id uuid default null
)
returns public.catches
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_today date := public.jakarta_today();
  v_folder text;
  v_area text := nullif(btrim(p_area_label), '');
  v_hidden boolean := coalesce(p_location_hidden, false);
  v_type text := nullif(lower(btrim(p_animal_type)), '');
  v_sent_at timestamptz;
  v_animal_id uuid;
  v_ai public.ai_identifications;
  v_catch public.catches;
begin
  if v_uid is null then
    raise exception 'harus login' using errcode = '28000';
  end if;

  select d.sent_at into v_sent_at
    from public.daily_drops d
    where d.drop_date = v_today;
  if v_sent_at is null then
    raise exception 'daily drop belum turun' using errcode = 'FR005';
  end if;

  if exists (
    select 1 from public.catches where user_id = v_uid and catch_date = v_today
  ) then
    raise exception 'sudah catch hari ini' using errcode = 'FR001';
  end if;

  if p_animal_id is not null and not exists (
    select 1 from public.animals where id = p_animal_id and owner_id = v_uid
  ) then
    raise exception 'hewan bukan milikmu' using errcode = 'FR004';
  end if;

  v_folder := v_uid::text || '/' || p_catch_id::text || '/';
  if (
    select count(*) from storage.objects
    where bucket_id = 'catch-photos'
      and name in (v_folder || 'animal.jpg', v_folder || 'selfie.jpg')
  ) < 2 then
    raise exception 'foto belum ter-upload' using errcode = 'FR002';
  end if;

  if v_hidden or v_area is null then
    v_hidden := true;
    v_area := null;
  end if;

  select * into v_ai
    from public.ai_identifications a
    where a.catch_id = p_catch_id and a.user_id = v_uid and a.status = 'ok'
    order by a.created_at desc
    limit 1;

  begin
    if p_animal_id is not null then
      -- ketemu lagi: nama & jenis mengikuti hewan lama; isi jenis kalau masih kosong.
      v_animal_id := p_animal_id;
      update public.animals
         set animal_type = coalesce(animal_type, v_type)
       where id = p_animal_id;
    else
      insert into public.animals (owner_id, name, kind, animal_type)
      values (v_uid, btrim(p_animal_name), p_animal_kind, v_type)
      returning id into v_animal_id;
    end if;

    insert into public.catches (
      id, user_id, animal_id, animal_photo_path, selfie_photo_path,
      ai_type, ai_confidence, ai_candidates, ai_personality, personality,
      area_label, location_hidden, is_late, catch_date
    )
    values (
      p_catch_id, v_uid, v_animal_id, v_folder || 'animal.jpg', v_folder || 'selfie.jpg',
      v_ai.animal_type, v_ai.confidence, v_ai.candidates, v_ai.personality,
      nullif(btrim(p_personality), ''),
      v_area, v_hidden, now() > v_sent_at + interval '1 hour', v_today
    )
    returning * into v_catch;
  exception when unique_violation then
    raise exception 'sudah catch hari ini' using errcode = 'FR001';
  end;

  return v_catch;
end;
$$;
