-- M5: streak harian, "ketemu lagi" (encounter_count), koleksi.

-- ---------------------------------------------------------------------------
-- streaks: diisi trigger, user hanya bisa membaca miliknya sendiri.
-- ---------------------------------------------------------------------------
create table public.streaks (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  current int not null default 0 check (current >= 0),
  longest int not null default 0 check (longest >= 0),
  last_catch_date date
);

alter table public.streaks enable row level security;
revoke all on public.streaks from anon, authenticated;
grant select on public.streaks to authenticated;

create policy "streaks: baca milik sendiri"
  on public.streaks for select to authenticated
  using (user_id = auth.uid());

-- Saat catch baru (catch_date sudah Asia/Jakarta):
--   kemarin → +1, hari yang sama → tetap, terlewat → 1, lebih lama (backfill) → abaikan.
create function public.update_streak_on_catch()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  s public.streaks;
  v_current int;
begin
  select * into s from public.streaks where user_id = new.user_id for update;

  if not found then
    insert into public.streaks (user_id, current, longest, last_catch_date)
    values (new.user_id, 1, 1, new.catch_date);
    return new;
  end if;

  if s.last_catch_date is null or new.catch_date > s.last_catch_date + 1 then
    v_current := 1;
  elsif new.catch_date = s.last_catch_date + 1 then
    v_current := s.current + 1;
  else
    -- hari yang sama, atau catch bertanggal lampau: tidak mengubah streak
    return new;
  end if;

  update public.streaks
     set current = v_current,
         longest = greatest(longest, v_current),
         last_catch_date = new.catch_date
   where user_id = new.user_id;
  return new;
end;
$$;

create trigger catches_update_streak
  after insert on public.catches
  for each row execute function public.update_streak_on_catch();

-- Streak untuk ditampilkan: 0 kalau catch terakhir lebih lama dari kemarin.
create function public.my_streak()
returns table (current int, longest int, last_catch_date date)
language sql
stable
set search_path = ''
as $$
  select
    case when s.last_catch_date >= public.jakarta_today() - 1 then s.current else 0 end,
    s.longest,
    s.last_catch_date
  from public.streaks s
  where s.user_id = auth.uid();
$$;

revoke execute on function public.my_streak() from public, anon;
grant execute on function public.my_streak() to authenticated;

-- Hitung ulang streak dari riwayat catch (dipakai skrip debug lokal, service role).
create function public.recompute_streak(p_user_id uuid)
returns public.streaks
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current int := 0;
  v_longest int := 0;
  v_last date;
  v_row public.streaks;
begin
  with days as (
    select distinct catch_date from public.catches where user_id = p_user_id
  ),
  runs as (
    select count(*)::int as len, max(catch_date) as last_day
    from (
      select catch_date,
             catch_date - (row_number() over (order by catch_date))::int as grp
      from days
    ) g
    group by grp
  )
  select
    coalesce((select len from runs order by last_day desc limit 1), 0),
    coalesce((select max(len) from runs), 0),
    (select max(last_day) from runs)
  into v_current, v_longest, v_last;

  insert into public.streaks (user_id, current, longest, last_catch_date)
  values (p_user_id, v_current, v_longest, v_last)
  on conflict (user_id) do update
    set current = excluded.current,
        longest = greatest(public.streaks.longest, excluded.longest),
        last_catch_date = excluded.last_catch_date
  returning * into v_row;
  return v_row;
end;
$$;

revoke execute on function public.recompute_streak(uuid) from public, anon, authenticated;
grant execute on function public.recompute_streak(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- Catch hanya boleh terhubung ke hewan milik pemilik catch. Error FR004.
-- ---------------------------------------------------------------------------
create function public.ensure_catch_animal_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.animal_id is not null and not exists (
    select 1 from public.animals a
    where a.id = new.animal_id and a.owner_id = new.user_id
  ) then
    raise exception 'hewan bukan milikmu' using errcode = 'FR004';
  end if;
  return new;
end;
$$;

create trigger catches_animal_owner
  before insert or update of animal_id, user_id on public.catches
  for each row execute function public.ensure_catch_animal_owner();

-- ---------------------------------------------------------------------------
-- encounter_count = jumlah catch hewan itu; last_seen_at = catch terbaru.
-- Dihitung ulang saat catch dibuat/dihapus langsung. Penghapusan berantai
-- (mis. hapus akun) dilewati supaya tidak bentrok dengan penghapusan hewannya.
-- ---------------------------------------------------------------------------
create function public.refresh_animal_encounters()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_animal uuid := case when tg_op = 'DELETE' then old.animal_id else new.animal_id end;
begin
  if v_animal is null then
    return null;
  end if;
  update public.animals a
     set encounter_count = greatest(1, (
           select count(*) from public.catches c where c.animal_id = v_animal)),
         last_seen_at = coalesce((
           select max(c.created_at) from public.catches c where c.animal_id = v_animal),
           a.last_seen_at)
   where a.id = v_animal;
  return null;
end;
$$;

create trigger catches_refresh_encounters_insert
  after insert on public.catches
  for each row execute function public.refresh_animal_encounters();

create trigger catches_refresh_encounters_delete
  after delete on public.catches
  for each row
  when (pg_trigger_depth() < 1)
  execute function public.refresh_animal_encounters();

-- encounter_count & waktu dihitung server, bukan dari app.
revoke update on public.animals from authenticated;
grant update (name, kind) on public.animals to authenticated;

-- ---------------------------------------------------------------------------
-- create_catch v3: + p_animal_id ("ketemu lagi" hewan lama milik sendiri).
-- ---------------------------------------------------------------------------
drop function public.create_catch(uuid, text, text, text, boolean, text, text);

create function public.create_catch(
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
  v_is_late boolean;
  v_animal_id uuid;
  v_ai public.ai_identifications;
  v_catch public.catches;
begin
  if v_uid is null then
    raise exception 'harus login' using errcode = '28000';
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

  select coalesce(now() > d.sent_at + interval '1 hour', false)
    into v_is_late
    from public.daily_drops d
    where d.drop_date = v_today;
  v_is_late := coalesce(v_is_late, false);

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
      v_area, v_hidden, v_is_late, v_today
    )
    returning * into v_catch;
  exception when unique_violation then
    raise exception 'sudah catch hari ini' using errcode = 'FR001';
  end;

  return v_catch;
end;
$$;

revoke execute on function public.create_catch(uuid, text, text, text, boolean, text, text, uuid)
  from public, anon;
grant execute on function public.create_catch(uuid, text, text, text, boolean, text, text, uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Koleksi hewan milik saya + foto & kepribadian dari catch terakhirnya.
-- ---------------------------------------------------------------------------
create function public.my_collection()
returns table (
  animal_id uuid,
  name text,
  kind text,
  animal_type text,
  encounter_count int,
  first_seen_at timestamptz,
  last_seen_at timestamptz,
  last_animal_photo_path text,
  last_personality text
)
language sql
stable
set search_path = ''
as $$
  select a.id, a.name, a.kind, a.animal_type, a.encounter_count,
         a.first_seen_at, a.last_seen_at,
         lc.animal_photo_path, lc.personality
  from public.animals a
  left join lateral (
    select c.animal_photo_path, coalesce(c.personality, c.ai_personality) as personality
    from public.catches c
    where c.animal_id = a.id
    order by c.created_at desc
    limit 1
  ) lc on true
  where a.owner_id = auth.uid()
  order by a.last_seen_at desc, a.name;
$$;

revoke execute on function public.my_collection() from public, anon;
grant execute on function public.my_collection() to authenticated;

-- Backfill: streak & jumlah pertemuan untuk catch yang dibuat sebelum M5.
select public.recompute_streak(user_id) from (select distinct user_id from public.catches) u;
update public.animals a
   set encounter_count = greatest(1, (select count(*) from public.catches c where c.animal_id = a.id));
