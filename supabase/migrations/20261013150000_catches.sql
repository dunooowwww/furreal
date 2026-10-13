-- M2: hewan, catch harian, daily_drops (diisi di M6), storage foto catch.
-- Foto: {user_id}/{catch_id}/animal.jpg dan selfie.jpg di bucket private catch-photos.

-- ---------------------------------------------------------------------------
-- Tanggal "hari ini" untuk catch selalu zona Asia/Jakarta.
-- ---------------------------------------------------------------------------
create function public.jakarta_today()
returns date
language sql
stable
set search_path = ''
as $$
  select (now() at time zone 'Asia/Jakarta')::date;
$$;

-- ---------------------------------------------------------------------------
-- animals
-- ---------------------------------------------------------------------------
create table public.animals (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 40),
  kind text not null check (kind in ('pet', 'wild')),
  animal_type text,
  encounter_count int not null default 1,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create index animals_owner_id_idx on public.animals (owner_id);

-- ---------------------------------------------------------------------------
-- daily_drops: satu baris per hari, diisi send-daily-drop (M6).
-- ---------------------------------------------------------------------------
create table public.daily_drops (
  drop_date date primary key,
  sent_at timestamptz
);

-- ---------------------------------------------------------------------------
-- catches
-- ---------------------------------------------------------------------------
create table public.catches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  animal_id uuid references public.animals (id) on delete set null,
  animal_photo_path text not null,
  selfie_photo_path text not null,
  ai_type text,
  ai_confidence numeric,
  ai_candidates jsonb,
  ai_personality text,
  area_label text check (char_length(area_label) between 1 and 80),
  location_hidden boolean not null default false,
  is_late boolean not null default false,
  catch_date date not null,
  created_at timestamptz not null default now(),
  -- satu catch per user per hari
  unique (user_id, catch_date),
  check (not location_hidden or area_label is null)
);

create index catches_animal_id_idx on public.catches (animal_id);
create index catches_catch_date_idx on public.catches (catch_date);

-- ---------------------------------------------------------------------------
-- RLS & hak akses. Insert hanya lewat RPC create_catch.
-- ---------------------------------------------------------------------------
alter table public.animals enable row level security;
alter table public.daily_drops enable row level security;
alter table public.catches enable row level security;

revoke all on public.animals from anon, authenticated;
revoke all on public.daily_drops from anon, authenticated;
revoke all on public.catches from anon, authenticated;

grant select, delete on public.animals to authenticated;
grant update (name, kind) on public.animals to authenticated;
grant select on public.daily_drops to authenticated;
grant select, delete on public.catches to authenticated;
grant update (area_label, location_hidden) on public.catches to authenticated;

create policy "animals: baca milik sendiri atau satu circle"
  on public.animals for select to authenticated
  using (owner_id = auth.uid() or public.shares_circle(auth.uid(), owner_id));

create policy "animals: ubah milik sendiri"
  on public.animals for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy "animals: hapus milik sendiri"
  on public.animals for delete to authenticated
  using (owner_id = auth.uid());

create policy "daily_drops: semua user login bisa membaca"
  on public.daily_drops for select to authenticated
  using (true);

create policy "catches: baca milik sendiri atau satu circle"
  on public.catches for select to authenticated
  using (user_id = auth.uid() or public.shares_circle(auth.uid(), user_id));

create policy "catches: ubah milik sendiri"
  on public.catches for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "catches: hapus milik sendiri"
  on public.catches for delete to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- RPC create_catch: buat hewan baru + catch secara atomik.
-- Foto harus sudah di-upload ke {uid}/{p_catch_id}/animal.jpg & selfie.jpg.
-- Error: FR001 = sudah catch hari ini, FR002 = foto belum ter-upload.
-- ---------------------------------------------------------------------------
create function public.create_catch(
  p_catch_id uuid,
  p_animal_name text,
  p_animal_kind text,
  p_area_label text,
  p_location_hidden boolean
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
  v_is_late boolean;
  v_animal_id uuid;
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

  v_folder := v_uid::text || '/' || p_catch_id::text || '/';
  if (
    select count(*) from storage.objects
    where bucket_id = 'catch-photos'
      and name in (v_folder || 'animal.jpg', v_folder || 'selfie.jpg')
  ) < 2 then
    raise exception 'foto belum ter-upload' using errcode = 'FR002';
  end if;

  -- Lokasi disembunyikan atau tidak tersedia → tanpa area_label.
  if v_hidden or v_area is null then
    v_hidden := true;
    v_area := null;
  end if;

  -- Belum ada daily drop hari ini (M6) → tidak telat.
  select coalesce(now() > d.sent_at + interval '1 hour', false)
    into v_is_late
    from public.daily_drops d
    where d.drop_date = v_today;
  v_is_late := coalesce(v_is_late, false);

  begin
    insert into public.animals (owner_id, name, kind)
    values (v_uid, btrim(p_animal_name), p_animal_kind)
    returning id into v_animal_id;

    insert into public.catches (
      id, user_id, animal_id, animal_photo_path, selfie_photo_path,
      area_label, location_hidden, is_late, catch_date
    )
    values (
      p_catch_id, v_uid, v_animal_id, v_folder || 'animal.jpg', v_folder || 'selfie.jpg',
      v_area, v_hidden, v_is_late, v_today
    )
    returning * into v_catch;
  exception when unique_violation then
    -- balapan dua request di hari yang sama
    raise exception 'sudah catch hari ini' using errcode = 'FR001';
  end;

  return v_catch;
end;
$$;

revoke execute on function public.create_catch(uuid, text, text, text, boolean) from public, anon;
grant execute on function public.create_catch(uuid, text, text, text, boolean) to authenticated;
revoke execute on function public.jakarta_today() from public, anon;
grant execute on function public.jakarta_today() to authenticated;

-- ---------------------------------------------------------------------------
-- Storage: bucket private catch-photos (JPEG, maks 5 MB per file).
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('catch-photos', 'catch-photos', false, 5242880, array['image/jpeg'])
on conflict (id) do nothing;

-- Path valid: {uid}/{uuid}/animal.jpg atau selfie.jpg, di folder milik sendiri.
create function public.is_own_catch_photo_path(p_name text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select p_name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/(animal|selfie)\.jpg$'
    and split_part(p_name, '/', 1) = auth.uid()::text;
$$;

-- Baca: pemilik foto atau anggota circle yang sama.
create function public.can_read_catch_photo(p_name text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select case
    when split_part(p_name, '/', 1) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then split_part(p_name, '/', 1)::uuid = auth.uid()
        or public.shares_circle(auth.uid(), split_part(p_name, '/', 1)::uuid)
    else false
  end;
$$;

revoke execute on function public.is_own_catch_photo_path(text) from public, anon;
revoke execute on function public.can_read_catch_photo(text) from public, anon;
grant execute on function public.is_own_catch_photo_path(text) to authenticated;
grant execute on function public.can_read_catch_photo(text) to authenticated;

create policy "catch-photos: upload ke folder sendiri"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'catch-photos' and public.is_own_catch_photo_path(name));

create policy "catch-photos: timpa file sendiri"
  on storage.objects for update to authenticated
  using (bucket_id = 'catch-photos' and public.is_own_catch_photo_path(name))
  with check (bucket_id = 'catch-photos' and public.is_own_catch_photo_path(name));

create policy "catch-photos: hapus file sendiri"
  on storage.objects for delete to authenticated
  using (bucket_id = 'catch-photos' and public.is_own_catch_photo_path(name));

create policy "catch-photos: baca milik sendiri atau satu circle"
  on storage.objects for select to authenticated
  using (bucket_id = 'catch-photos' and public.can_read_catch_photo(name));
