-- M7: pedoman kesejahteraan hewan (onboarding) dan hapus akun.
--
-- Hapus akun dijalankan Edge Function delete-account (service role):
--   1. account_photo_paths(user) → hapus semua foto lewat Storage API
--      (DELETE langsung ke storage.objects ditolak storage.protect_delete);
--   2. auth.admin.deleteUser(user) → profil dan semua data turunannya ikut
--      terhapus lewat FK on delete cascade (catches, animals, reactions,
--      comments, streaks, ai_identifications, circle_members);
--   3. circle yang tidak punya anggota lagi ikut dihapus (trigger di bawah).

-- ---------------------------------------------------------------------------
-- Pedoman kesejahteraan hewan: sekali per akun, setelah pilih username.
-- ---------------------------------------------------------------------------
alter table public.profiles add column guidelines_accepted_at timestamptz;

grant select (guidelines_accepted_at) on public.profiles to authenticated;

create function public.accept_guidelines()
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_at timestamptz;
begin
  if v_uid is null then
    raise exception 'harus login' using errcode = '28000';
  end if;
  update public.profiles
     set guidelines_accepted_at = coalesce(guidelines_accepted_at, now())
   where id = v_uid
  returning guidelines_accepted_at into v_at;
  return v_at;
end;
$$;

revoke execute on function public.accept_guidelines() from public, anon;
grant execute on function public.accept_guidelines() to authenticated;

-- ---------------------------------------------------------------------------
-- Hapus akun.
-- ---------------------------------------------------------------------------

-- Semua file milik user di bucket catch-photos (termasuk foto catch yang batal
-- diposting). Khusus service role.
create function public.account_photo_paths(p_user_id uuid)
returns setof text
language sql
stable
security definer
set search_path = ''
as $$
  select o.name
  from storage.objects o
  where o.bucket_id = 'catch-photos'
    and left(o.name, 37) = p_user_id::text || '/'
  order by o.name;
$$;

revoke execute on function public.account_photo_paths(uuid) from public, anon, authenticated;
grant execute on function public.account_photo_paths(uuid) to service_role;

-- Circle tanpa anggota (anggota terakhirnya menghapus akun) ikut dihapus.
create function public.delete_empty_circle()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.circles c
   where c.id = old.circle_id
     and not exists (
       select 1 from public.circle_members m where m.circle_id = old.circle_id
     );
  return null;
end;
$$;

create trigger circle_members_delete_empty_circle
  after delete on public.circle_members
  for each row
  execute function public.delete_empty_circle();
