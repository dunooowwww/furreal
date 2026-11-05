-- M11: kartu koleksi — foto hewan tanpa latar (dipotong di HP dengan ML Kit).
--
-- File: {uid}/{catch_id}/cutout.png di bucket catch-photos (aturan baca sama
-- dengan foto catch, termasuk kunci feed M9). Setelah upload, app memanggil
-- set_catch_cutout(catch, true). Kalau tidak ada hewan yang terdeteksi, app
-- memanggil set_catch_cutout(catch, false) supaya tidak dicoba lagi.

update storage.buckets
   set allowed_mime_types = array['image/jpeg', 'image/png']
 where id = 'catch-photos';

-- Path yang boleh di-upload pemilik: animal.jpg, selfie.jpg, cutout.png.
create or replace function public.is_own_catch_photo_path(p_name text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select p_name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/((animal|selfie)\.jpg|cutout\.png)$'
    and split_part(p_name, '/', 1) = auth.uid()::text;
$$;

alter table public.catches
  add column cutout_path text,
  add column cutout_attempted boolean not null default false;

create function public.set_catch_cutout(p_catch_id uuid, p_has_cutout boolean)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_path text := v_uid::text || '/' || p_catch_id::text || '/cutout.png';
begin
  if v_uid is null then
    raise exception 'harus login' using errcode = '28000';
  end if;
  if not exists (
    select 1 from public.catches c where c.id = p_catch_id and c.user_id = v_uid
  ) then
    raise exception 'catch bukan milikmu' using errcode = 'P0002';
  end if;
  if p_has_cutout and not exists (
    select 1 from storage.objects o
    where o.bucket_id = 'catch-photos' and o.name = v_path
  ) then
    raise exception 'potongan belum ter-upload' using errcode = 'FR002';
  end if;

  update public.catches
     set cutout_path = case when p_has_cutout then v_path end,
         cutout_attempted = true
   where id = p_catch_id;
  return case when p_has_cutout then v_path end;
end;
$$;

revoke execute on function public.set_catch_cutout(uuid, boolean) from public, anon;
grant execute on function public.set_catch_cutout(uuid, boolean) to authenticated;

-- Koleksi v2: + catch terakhir (id, tanggal, label area), potongannya, dan
-- apakah sudah dicoba. Dipakai kartu koleksi.
drop function public.my_collection();

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
  last_personality text,
  last_catch_id uuid,
  last_cutout_path text,
  last_cutout_attempted boolean,
  last_catch_date date,
  last_area_label text
)
language sql
stable
set search_path = ''
as $$
  select a.id, a.name, a.kind, a.animal_type, a.encounter_count,
         a.first_seen_at, a.last_seen_at,
         lc.animal_photo_path, lc.personality,
         lc.id, lc.cutout_path, coalesce(lc.cutout_attempted, false),
         lc.catch_date, lc.area_label
  from public.animals a
  left join lateral (
    select c.id, c.animal_photo_path, c.cutout_path, c.cutout_attempted,
           c.catch_date, c.area_label,
           coalesce(c.personality, c.ai_personality) as personality
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
