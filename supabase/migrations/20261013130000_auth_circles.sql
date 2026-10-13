-- M1: profil, circle, keanggotaan circle (PRD §5).
-- Semua tabel RLS aktif. Tulis ke circles/circle_members hanya lewat RPC.

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  -- null sampai user memilih username setelah login pertama.
  username text unique check (username ~ '^[a-z0-9_.]{3,20}$'),
  display_name text check (char_length(display_name) between 1 and 40),
  avatar_url text,
  fcm_token text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- fcm_token tidak boleh terbaca anggota circle lain: hak baca per kolom.
revoke all on public.profiles from anon, authenticated;
grant select (id, username, display_name, avatar_url, created_at)
  on public.profiles to authenticated;
grant update (username, display_name, avatar_url, fcm_token)
  on public.profiles to authenticated;

-- Profil dibuat otomatis saat user baru terdaftar di auth.users.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- circles & circle_members
-- ---------------------------------------------------------------------------
create table public.circles (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 40),
  invite_code text not null unique check (invite_code ~ '^[A-HJ-NP-Z2-9]{6}$'),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.circle_members (
  circle_id uuid not null references public.circles (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (circle_id, user_id)
);

create index circle_members_user_id_idx on public.circle_members (user_id);

alter table public.circles enable row level security;
alter table public.circle_members enable row level security;

revoke all on public.circles from anon, authenticated;
revoke all on public.circle_members from anon, authenticated;
grant select on public.circles to authenticated;
grant select on public.circle_members to authenticated;

-- ---------------------------------------------------------------------------
-- Helper untuk policy. security definer agar tidak rekursif lewat RLS.
-- ---------------------------------------------------------------------------
create function public.is_circle_member(p_circle_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.circle_members
    where circle_id = p_circle_id and user_id = auth.uid()
  );
$$;

create function public.shares_circle(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.circle_members m1
    join public.circle_members m2 on m2.circle_id = m1.circle_id
    where m1.user_id = a and m2.user_id = b
  );
$$;

-- ---------------------------------------------------------------------------
-- Policies
-- ---------------------------------------------------------------------------
create policy "profiles: baca sendiri atau satu circle"
  on public.profiles for select to authenticated
  using (id = auth.uid() or public.shares_circle(auth.uid(), id));

create policy "profiles: ubah milik sendiri"
  on public.profiles for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy "circles: hanya anggota yang bisa membaca"
  on public.circles for select to authenticated
  using (public.is_circle_member(id));

create policy "circle_members: hanya anggota yang bisa membaca"
  on public.circle_members for select to authenticated
  using (public.is_circle_member(circle_id));

-- ---------------------------------------------------------------------------
-- RPC
-- ---------------------------------------------------------------------------
-- Kode 6 karakter tanpa karakter mirip (0/O, 1/I).
create function public.generate_invite_code()
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  bytes bytea := uuid_send(gen_random_uuid());
  code text := '';
begin
  for i in 0..5 loop
    code := code || substr(alphabet, (get_byte(bytes, i) % 32) + 1, 1);
  end loop;
  return code;
end;
$$;

create function public.create_circle(p_name text)
returns public.circles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_circle public.circles;
begin
  if v_uid is null then
    raise exception 'harus login' using errcode = '28000';
  end if;

  loop
    begin
      insert into public.circles (name, invite_code, created_by)
      values (btrim(p_name), public.generate_invite_code(), v_uid)
      returning * into v_circle;
      exit;
    exception when unique_violation then
      -- kode bentrok, coba lagi
    end;
  end loop;

  insert into public.circle_members (circle_id, user_id)
  values (v_circle.id, v_uid);

  return v_circle;
end;
$$;

create function public.join_circle(invite_code text)
returns public.circles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_circle public.circles;
begin
  if v_uid is null then
    raise exception 'harus login' using errcode = '28000';
  end if;

  select * into v_circle
  from public.circles c
  where c.invite_code = upper(btrim(join_circle.invite_code));

  if not found then
    raise exception 'kode undangan tidak ditemukan' using errcode = 'P0002';
  end if;

  insert into public.circle_members (circle_id, user_id)
  values (v_circle.id, v_uid)
  on conflict do nothing;

  return v_circle;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.generate_invite_code() from public, anon, authenticated;
revoke execute on function public.is_circle_member(uuid) from public, anon;
revoke execute on function public.shares_circle(uuid, uuid) from public, anon;
revoke execute on function public.create_circle(text) from public, anon;
revoke execute on function public.join_circle(text) from public, anon;
grant execute on function public.is_circle_member(uuid) to authenticated;
grant execute on function public.shares_circle(uuid, uuid) to authenticated;
grant execute on function public.create_circle(text) to authenticated;
grant execute on function public.join_circle(text) to authenticated;
