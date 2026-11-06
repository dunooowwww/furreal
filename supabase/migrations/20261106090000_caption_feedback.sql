-- M12: caption manual di feed (kepribadian AI hanya untuk koleksi) dan
-- saran fitur / laporan bug dari pengaturan.

alter table public.catches
  add column caption text check (char_length(caption) <= 150);

-- ---------------------------------------------------------------------------
-- create_catch v6: + p_caption (opsional, maks 150 karakter).
-- ---------------------------------------------------------------------------
drop function public.create_catch(uuid, text, text, text, boolean, text, text, uuid);

create function public.create_catch(
  p_catch_id uuid,
  p_animal_name text,
  p_animal_kind text,
  p_area_label text,
  p_location_hidden boolean,
  p_animal_type text default null,
  p_personality text default null,
  p_animal_id uuid default null,
  p_caption text default null
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
  v_timing text;
  v_animal_id uuid;
  v_ai public.ai_identifications;
  v_catch public.catches;
begin
  if v_uid is null then
    raise exception 'harus login' using errcode = '28000';
  end if;

  -- M10: tidak dikunci. Sebelum drop turun → 'early'.
  select d.sent_at into v_sent_at
    from public.daily_drops d
    where d.drop_date = v_today;
  v_timing := case
    when v_sent_at is null or v_sent_at > now() then 'early'
    when now() > v_sent_at + interval '1 hour' then 'late'
    else 'on_time'
  end;

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
      area_label, location_hidden, is_late, timing, catch_date, caption
    )
    values (
      p_catch_id, v_uid, v_animal_id, v_folder || 'animal.jpg', v_folder || 'selfie.jpg',
      v_ai.animal_type, v_ai.confidence, v_ai.candidates, v_ai.personality,
      nullif(btrim(p_personality), ''),
      v_area, v_hidden, v_timing = 'late', v_timing, v_today,
      left(nullif(btrim(p_caption), ''), 150)
    )
    returning * into v_catch;
  exception when unique_violation then
    raise exception 'sudah catch hari ini' using errcode = 'FR001';
  end;

  return v_catch;
end;
$$;

revoke execute on function public.create_catch(uuid, text, text, text, boolean, text, text, uuid, text)
  from public, anon;
grant execute on function public.create_catch(uuid, text, text, text, boolean, text, text, uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Feed v4: caption menggantikan kepribadian (kepribadian tetap di koleksi).
-- ---------------------------------------------------------------------------
drop function public.circle_feed(uuid);

create function public.circle_feed(p_circle_id uuid)
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
  laughed_by_me boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  with feed as (
    select c.*, not public.can_view_catch_content(c.user_id, c.catch_date) as locked
    from public.circle_members cm
    join public.catches c on c.user_id = cm.user_id
    where cm.circle_id = p_circle_id
      and c.catch_date = public.jakarta_today()
      and public.is_circle_member(p_circle_id)
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
            where r.catch_id = f.id and r.type = 'laugh' and r.user_id = auth.uid())
  from feed f
  left join public.profiles p on p.id = f.user_id
  left join public.animals a on a.id = f.animal_id
  left join public.daily_drops d on d.drop_date = f.catch_date
  order by f.created_at desc;
$$;

revoke execute on function public.circle_feed(uuid) from public, anon;
grant execute on function public.circle_feed(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Saran & laporan bug. User hanya bisa mengirim; dibaca pengelola lewat
-- dashboard Supabase (Table Editor), tidak lewat API app.
-- ---------------------------------------------------------------------------
create table public.feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  category text not null check (category in ('feature', 'bug')),
  message text not null check (char_length(btrim(message)) between 1 and 1000),
  app_version text check (char_length(app_version) <= 40),
  created_at timestamptz not null default now()
);

create index feedback_created_at_idx on public.feedback (created_at desc);
create index feedback_user_id_idx on public.feedback (user_id);

alter table public.feedback enable row level security;
revoke all on public.feedback from anon, authenticated;
grant insert (category, message, app_version) on public.feedback to authenticated;

create policy "feedback: kirim atas nama sendiri"
  on public.feedback for insert to authenticated
  with check (user_id = auth.uid());
