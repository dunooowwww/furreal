-- M15: edit & hapus hewan dari koleksi.
--
-- - edit_animal: nama, peliharaan/liar, jenis, dan kepribadian kartu.
--   Kepribadian disimpan di animals.personality (menimpa kepribadian catch
--   terakhir; kosong = kembali ke kepribadian catch terakhir).
-- - remove_animal: hewan hilang dari koleksi (removed_at), tapi catch & foto
--   tetap (feed, streak, riwayat tidak berubah). Keputusan user.

alter table public.animals
  add column personality text check (char_length(personality) between 1 and 300),
  add column removed_at timestamptz;

create function public.edit_animal(
  p_animal_id uuid,
  p_name text,
  p_kind text,
  p_animal_type text,
  p_personality text
)
returns public.animals
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text := btrim(p_name);
  v_type text := nullif(lower(btrim(p_animal_type)), '');
  v_animal public.animals;
begin
  if auth.uid() is null then
    raise exception 'harus login' using errcode = '28000';
  end if;
  if v_name is null or char_length(v_name) not between 1 and 40 then
    raise exception 'nama hewan 1–40 karakter' using errcode = '22023';
  end if;
  if p_kind is null or p_kind not in ('pet', 'wild') then
    raise exception 'kind harus pet atau wild' using errcode = '22023';
  end if;
  if char_length(v_type) > 40 then
    raise exception 'jenis hewan maks 40 karakter' using errcode = '22023';
  end if;

  update public.animals
     set name = v_name,
         kind = p_kind,
         animal_type = v_type,
         personality = left(nullif(btrim(p_personality), ''), 300)
   where id = p_animal_id
     and owner_id = auth.uid()
     and removed_at is null
  returning * into v_animal;
  if not found then
    raise exception 'hewan bukan milikmu' using errcode = 'P0002';
  end if;
  return v_animal;
end;
$$;

create function public.remove_animal(p_animal_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'harus login' using errcode = '28000';
  end if;
  update public.animals
     set removed_at = now()
   where id = p_animal_id
     and owner_id = auth.uid()
     and removed_at is null;
  if not found then
    raise exception 'hewan bukan milikmu' using errcode = 'P0002';
  end if;
end;
$$;

revoke execute on function public.edit_animal(uuid, text, text, text, text) from public, anon;
revoke execute on function public.remove_animal(uuid) from public, anon;
grant execute on function public.edit_animal(uuid, text, text, text, text) to authenticated;
grant execute on function public.remove_animal(uuid) to authenticated;

-- Koleksi v3: tanpa hewan yang dihapus; kepribadian kartu = milik hewan
-- (kalau diedit) atau catch terakhir.
create or replace function public.my_collection()
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
         lc.animal_photo_path, coalesce(a.personality, lc.personality),
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
    and a.removed_at is null
  order by a.last_seen_at desc, a.name;
$$;
