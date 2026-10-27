-- Perbaikan audit (27 Okt 2026).
--
-- 1. Catch tidak bisa dihapus user. Sebelumnya hapus → catch ulang bisa
--    mengakali "satu catch per hari" dan mengirim notifikasi "teman udah
--    catch" berkali-kali. Hapus catch untuk development lewat skrip lokal
--    (supabase/scripts/reset_dev_today.ts, service role); hapus akun tetap
--    lewat delete-account (service role + FK cascade).
-- 2. Foto catch yang sudah terposting tidak bisa dihapus atau ditimpa user.
--    App membuang foto saat batal posting; kalau posting sebenarnya sudah
--    berhasil tapi balasannya hilang (sinyal jelek), foto catch itu dulu ikut
--    terhapus. Juga menutup penggantian foto setelah posting.
-- 3. create_catch v6 idempoten: panggilan ulang dengan p_catch_id yang sudah
--    jadi catch milik pemanggil mengembalikan catch itu (bukan FR001), jadi
--    "posting lagi" setelah balasan hilang tetap berhasil.

-- ---------------------------------------------------------------------------
-- 1. Catch tidak bisa dihapus user
-- ---------------------------------------------------------------------------
drop policy "catches: hapus milik sendiri" on public.catches;
revoke delete on public.catches from authenticated;

-- ---------------------------------------------------------------------------
-- 2. Foto catch yang sudah terposting dikunci
-- ---------------------------------------------------------------------------
-- {owner}/{catch_id}/... milik catch yang sudah ada.
create function public.is_posted_catch_photo(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_name !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/' then
    return false;
  end if;
  return exists (
    select 1 from public.catches c
    where c.id = split_part(p_name, '/', 2)::uuid
      and c.user_id = split_part(p_name, '/', 1)::uuid
  );
end;
$$;

revoke execute on function public.is_posted_catch_photo(text) from public, anon;
grant execute on function public.is_posted_catch_photo(text) to authenticated;

drop policy "catch-photos: timpa file sendiri" on storage.objects;
drop policy "catch-photos: hapus file sendiri" on storage.objects;

create policy "catch-photos: timpa file sendiri yang belum diposting"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'catch-photos'
    and public.is_own_catch_photo_path(name)
    and not public.is_posted_catch_photo(name)
  )
  with check (
    bucket_id = 'catch-photos'
    and public.is_own_catch_photo_path(name)
    and not public.is_posted_catch_photo(name)
  );

create policy "catch-photos: hapus file sendiri yang belum diposting"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'catch-photos'
    and public.is_own_catch_photo_path(name)
    and not public.is_posted_catch_photo(name)
  );

-- ---------------------------------------------------------------------------
-- 3. create_catch v6: idempoten untuk p_catch_id yang sama
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
  v_timing text;
  v_animal_id uuid;
  v_ai public.ai_identifications;
  v_catch public.catches;
begin
  if v_uid is null then
    raise exception 'harus login' using errcode = '28000';
  end if;

  -- Posting ulang catch yang sama (balasan pertama tidak sampai ke app).
  select * into v_catch
    from public.catches c
   where c.id = p_catch_id and c.user_id = v_uid;
  if found then
    return v_catch;
  end if;

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
      area_label, location_hidden, is_late, timing, catch_date
    )
    values (
      p_catch_id, v_uid, v_animal_id, v_folder || 'animal.jpg', v_folder || 'selfie.jpg',
      v_ai.animal_type, v_ai.confidence, v_ai.candidates, v_ai.personality,
      nullif(btrim(p_personality), ''),
      v_area, v_hidden, v_timing = 'late', v_timing, v_today
    )
    returning * into v_catch;
  exception when unique_violation then
    raise exception 'sudah catch hari ini' using errcode = 'FR001';
  end;

  return v_catch;
end;
$$;
