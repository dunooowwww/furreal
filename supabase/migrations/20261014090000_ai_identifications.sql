-- M3: hasil AI identify-animal disimpan di server, lalu disalin create_catch.

-- ---------------------------------------------------------------------------
-- Log panggilan + hasil AI. Hanya service role (Edge Function) yang akses.
-- ---------------------------------------------------------------------------
create table public.ai_identifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  catch_id uuid not null,
  provider text not null,
  model text,
  status text not null default 'pending' check (status in ('pending', 'ok', 'error')),
  error_code text,
  animal_type text,
  confidence numeric,
  candidates jsonb,
  personality text,
  call_date date not null default public.jakarta_today(),
  created_at timestamptz not null default now()
);

create index ai_identifications_user_day_idx
  on public.ai_identifications (user_id, call_date);
create index ai_identifications_catch_idx
  on public.ai_identifications (catch_id, created_at desc);

-- RLS aktif tanpa policy: anon/authenticated tidak bisa apa-apa.
alter table public.ai_identifications enable row level security;
revoke all on public.ai_identifications from anon, authenticated;

-- Catat panggilan baru secara atomik. p_daily_limit null = tanpa batas (mock).
-- Error FR003 = jatah harian habis.
create function public.claim_ai_call(
  p_user_id uuid,
  p_catch_id uuid,
  p_provider text,
  p_model text,
  p_daily_limit int
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  -- serialisasi per user supaya dua panggilan bersamaan tidak lolos batas
  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text, 0));

  if p_daily_limit is not null and (
    select count(*) from public.ai_identifications
    where user_id = p_user_id
      and call_date = public.jakarta_today()
      and provider <> 'mock'
  ) >= p_daily_limit then
    raise exception 'jatah AI hari ini habis' using errcode = 'FR003';
  end if;

  insert into public.ai_identifications (user_id, catch_id, provider, model)
  values (p_user_id, p_catch_id, p_provider, p_model)
  returning id into v_id;
  return v_id;
end;
$$;

revoke execute on function public.claim_ai_call(uuid, uuid, text, text, int)
  from public, anon, authenticated;
grant execute on function public.claim_ai_call(uuid, uuid, text, text, int)
  to service_role;

-- ---------------------------------------------------------------------------
-- Kartu kepribadian final (boleh diedit user); ai_personality tetap asli AI.
-- ---------------------------------------------------------------------------
alter table public.catches
  add column personality text check (char_length(personality) between 1 and 300);

grant update (personality) on public.catches to authenticated;

alter table public.animals
  add constraint animals_animal_type_check
  check (char_length(animal_type) between 1 and 40);

-- ---------------------------------------------------------------------------
-- create_catch v2: + jenis & kepribadian final, salin hasil AI dari server.
-- Dua parameter baru punya default, jadi panggilan 5 argumen tetap jalan.
-- ---------------------------------------------------------------------------
drop function public.create_catch(uuid, text, text, text, boolean);

create function public.create_catch(
  p_catch_id uuid,
  p_animal_name text,
  p_animal_kind text,
  p_area_label text,
  p_location_hidden boolean,
  p_animal_type text default null,
  p_personality text default null
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

  -- Hasil AI terakhir yang sukses untuk catch ini, milik user ini.
  select * into v_ai
    from public.ai_identifications a
    where a.catch_id = p_catch_id and a.user_id = v_uid and a.status = 'ok'
    order by a.created_at desc
    limit 1;

  begin
    insert into public.animals (owner_id, name, kind, animal_type)
    values (
      v_uid, btrim(p_animal_name), p_animal_kind,
      nullif(lower(btrim(p_animal_type)), '')
    )
    returning id into v_animal_id;

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

revoke execute on function public.create_catch(uuid, text, text, text, boolean, text, text)
  from public, anon;
grant execute on function public.create_catch(uuid, text, text, text, boolean, text, text)
  to authenticated;
