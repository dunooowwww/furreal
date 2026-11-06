-- Gabungan audit (27 Okt) + M13/M16: user boleh menghapus catch sendiri lagi
-- (tombol "hapus" di beranda, feed, riwayat). Celah yang tadinya ditutup
-- dengan melarang hapus (hapus lalu catch ulang → notifikasi "teman udah
-- catch" berkali-kali) ditutup dengan catatan notifikasi per user per hari
-- yang tidak ikut terhapus bersama catch-nya.
--
-- Yang tetap dari audit: foto catch yang sudah diposting tidak bisa DITIMPA
-- (hanya dihapus), dan create_catch idempoten untuk catch_id yang sama.

-- ---------------------------------------------------------------------------
-- 1. Hapus catch sendiri (sama seperti sejak M2)
-- ---------------------------------------------------------------------------
grant delete on public.catches to authenticated;

create policy "catches: hapus milik sendiri"
  on public.catches for delete to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 2. Hapus file foto sendiri (app menghapus foto + potongan saat catch dihapus)
-- ---------------------------------------------------------------------------
drop policy "catch-photos: hapus file sendiri yang belum diposting" on storage.objects;

create policy "catch-photos: hapus file sendiri"
  on storage.objects for delete to authenticated
  using (bucket_id = 'catch-photos' and public.is_own_catch_photo_path(name));

-- ---------------------------------------------------------------------------
-- 3. Notifikasi "teman udah catch" maksimal sekali per user per hari
-- ---------------------------------------------------------------------------
create table public.catch_notification_log (
  user_id uuid not null references public.profiles (id) on delete cascade,
  notify_date date not null,
  primary key (user_id, notify_date)
);

-- Hanya dipakai claim_catch_notification (security definer); tidak terbaca API.
alter table public.catch_notification_log enable row level security;
revoke all on public.catch_notification_log from anon, authenticated;

create or replace function public.claim_catch_notification(p_catch_id uuid, p_user_id uuid)
returns table (sender_name text, token text, recipient_caught boolean)
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.catches c
     set notified_at = now()
   where c.id = p_catch_id
     and c.user_id = p_user_id
     and c.catch_date = public.jakarta_today()
     and c.notified_at is null;
  if not found then
    return;
  end if;

  -- Sekali per user per hari: hapus catch lalu catch ulang tidak mengirim lagi.
  insert into public.catch_notification_log (user_id, notify_date)
  values (p_user_id, public.jakarta_today())
  on conflict do nothing;
  if not found then
    return;
  end if;

  return query
    select coalesce(me.display_name, me.username, 'teman lo'),
           p.fcm_token,
           exists (
             select 1 from public.catches c2
             where c2.user_id = p.id and c2.catch_date = public.jakarta_today()
           )
    from public.profiles p
    join public.profiles me on me.id = p_user_id
    where p.id <> p_user_id
      and p.fcm_token is not null
      and public.shares_circle(p_user_id, p.id);
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. create_catch idempoten lagi (v7 = v6 dari M12 + pengaman posting ulang)
-- ---------------------------------------------------------------------------
create or replace function public.create_catch(
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

  -- Posting ulang catch yang sama (balasan pertama tidak sampai ke app):
  -- kembalikan catch yang sudah ada. Hilang saat M12 menulis ulang fungsi ini.
  select * into v_catch
    from public.catches c
   where c.id = p_catch_id and c.user_id = v_uid;
  if found then
    return v_catch;
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
