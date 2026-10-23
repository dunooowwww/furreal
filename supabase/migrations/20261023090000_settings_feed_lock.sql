-- M9: feed dikunci sampai catch (ala BeReal), foto profil, keluar circle.
--
-- Kunci feed ditegakkan di server: catch anggota circle dari HARI INI
-- (Asia/Jakarta) baru terbuka setelah pemanggil sendiri catch hari ini.
-- Berlaku untuk baris catches, foto di storage, reaksi, komentar, dan feed.
-- Catch hari-hari sebelumnya tidak terkunci.

-- ---------------------------------------------------------------------------
-- Kunci feed
-- ---------------------------------------------------------------------------
create function public.has_caught_today()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.catches c
    where c.user_id = auth.uid() and c.catch_date = public.jakarta_today()
  );
$$;

-- Isi catch (foto, nama hewan, kepribadian, reaksi, komentar) boleh dilihat:
-- milik sendiri, atau satu circle dan (bukan catch hari ini, atau saya
-- sudah catch hari ini).
create function public.can_view_catch_content(p_owner uuid, p_catch_date date)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_owner = auth.uid()
    or (
      public.shares_circle(auth.uid(), p_owner)
      and (p_catch_date <> public.jakarta_today() or public.has_caught_today())
    );
$$;

revoke execute on function public.has_caught_today() from public, anon;
revoke execute on function public.can_view_catch_content(uuid, date) from public, anon;
grant execute on function public.has_caught_today() to authenticated;
grant execute on function public.can_view_catch_content(uuid, date) to authenticated;

drop policy "catches: baca milik sendiri atau satu circle" on public.catches;

create policy "catches: baca milik sendiri, atau satu circle setelah catch hari ini"
  on public.catches for select to authenticated
  using (public.can_view_catch_content(user_id, catch_date));

-- Dipakai policy reactions & comments: ikut terkunci.
create or replace function public.can_see_catch(p_catch_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.catches c
    where c.id = p_catch_id
      and public.can_view_catch_content(c.user_id, c.catch_date)
  );
$$;

-- Foto catch: {owner}/{catch_id}/animal|selfie.jpg. Pemilik selalu boleh
-- (termasuk sebelum baris catch dibuat); orang lain ikut aturan kunci.
create or replace function public.can_read_catch_photo(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
  v_catch uuid;
  v_date date;
begin
  if p_name !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/' then
    return false;
  end if;
  v_owner := split_part(p_name, '/', 1)::uuid;
  if v_owner = auth.uid() then
    return true;
  end if;
  v_catch := split_part(p_name, '/', 2)::uuid;
  select c.catch_date into v_date
    from public.catches c
   where c.id = v_catch and c.user_id = v_owner;
  if not found then
    return false;
  end if;
  return public.can_view_catch_content(v_owner, v_date);
end;
$$;

-- ---------------------------------------------------------------------------
-- Foto profil: bucket private avatars, {uid}/{uuid}.jpg (nama baru tiap ganti
-- supaya cache gambar tidak basi). Terlihat oleh diri sendiri & satu circle.
-- ---------------------------------------------------------------------------
alter table public.profiles add column avatar_path text
  check (avatar_path ~ ('^' || id::text || '/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$'));

grant select (avatar_path) on public.profiles to authenticated;
grant update (avatar_path) on public.profiles to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', false, 1048576, array['image/jpeg'])
on conflict (id) do nothing;

create function public.is_own_avatar_path(p_name text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select p_name ~ '^[0-9a-f-]{36}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$'
    and split_part(p_name, '/', 1) = auth.uid()::text;
$$;

create function public.can_read_avatar(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when split_part(p_name, '/', 1) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then split_part(p_name, '/', 1)::uuid = auth.uid()
        or public.shares_circle(auth.uid(), split_part(p_name, '/', 1)::uuid)
    else false
  end;
$$;

revoke execute on function public.is_own_avatar_path(text) from public, anon;
revoke execute on function public.can_read_avatar(text) from public, anon;
grant execute on function public.is_own_avatar_path(text) to authenticated;
grant execute on function public.can_read_avatar(text) to authenticated;

create policy "avatars: upload ke folder sendiri"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and public.is_own_avatar_path(name));

create policy "avatars: timpa file sendiri"
  on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and public.is_own_avatar_path(name))
  with check (bucket_id = 'avatars' and public.is_own_avatar_path(name));

create policy "avatars: hapus file sendiri"
  on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and public.is_own_avatar_path(name));

create policy "avatars: baca milik sendiri atau satu circle"
  on storage.objects for select to authenticated
  using (bucket_id = 'avatars' and public.can_read_avatar(name));

-- Hapus akun: foto profil juga dihapus lewat Storage API. Khusus service role.
create function public.account_avatar_paths(p_user_id uuid)
returns setof text
language sql
stable
security definer
set search_path = ''
as $$
  select o.name
  from storage.objects o
  where o.bucket_id = 'avatars'
    and left(o.name, 37) = p_user_id::text || '/'
  order by o.name;
$$;

revoke execute on function public.account_avatar_paths(uuid) from public, anon, authenticated;
grant execute on function public.account_avatar_paths(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- Keluar circle. Circle yang jadi kosong ikut terhapus (trigger M7).
-- ---------------------------------------------------------------------------
create function public.leave_circle(p_circle_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'harus login' using errcode = '28000';
  end if;
  delete from public.circle_members m
   where m.circle_id = p_circle_id and m.user_id = auth.uid();
  if not found then
    raise exception 'bukan anggota circle ini' using errcode = 'P0002';
  end if;
end;
$$;

revoke execute on function public.leave_circle(uuid) from public, anon;
grant execute on function public.leave_circle(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Feed v2: security definer supaya baris yang terkunci tetap muncul (siapa
-- yang sudah catch, jam, tepat waktu/telat) tanpa isinya. Hanya anggota
-- circle yang mendapat hasil.
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
  locked boolean,
  animal_name text,
  animal_type text,
  encounter_count int,
  personality text,
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
    f.locked,
    case when not f.locked then a.name end,
    case when not f.locked then coalesce(a.animal_type, f.ai_type) end,
    case when not f.locked then coalesce(a.encounter_count, 1) end,
    case when not f.locked then coalesce(f.personality, f.ai_personality) end,
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

-- Komentar v2: tambah foto profil penulis.
drop function public.catch_comments(uuid);

create function public.catch_comments(p_catch_id uuid)
returns table (
  id uuid,
  user_id uuid,
  username text,
  display_name text,
  avatar_path text,
  body text,
  created_at timestamptz,
  is_mine boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select m.id, m.user_id, p.username, p.display_name, p.avatar_path, m.body,
         m.created_at, m.user_id = auth.uid()
  from public.comments m
  join public.profiles p on p.id = m.user_id
  where m.catch_id = p_catch_id
    and public.can_see_catch(p_catch_id)
  order by m.created_at;
$$;

revoke execute on function public.catch_comments(uuid) from public, anon;
grant execute on function public.catch_comments(uuid) to authenticated;
