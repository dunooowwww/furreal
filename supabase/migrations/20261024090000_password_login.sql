-- M8: masuk pakai username + password.
--
-- Supabase Auth hanya mengenal email + password. App memanggil
-- resolve_login(username, password) untuk mendapat email pemilik username,
-- lalu signInWithPassword(email, password) seperti biasa (rate limit Auth
-- tetap per IP HP). Email hanya dikembalikan kalau password-nya benar, jadi
-- email user tidak bisa diintip lewat username. Percobaan gagal dibatasi
-- per username supaya fungsi ini tidak jadi jalan menebak password.

create extension if not exists pgcrypto with schema extensions;

create table public.login_attempts (
  username text not null,
  attempted_at timestamptz not null default now()
);

create index login_attempts_username_idx on public.login_attempts (username, attempted_at);

-- Hanya dipakai resolve_login (security definer); tidak terbaca lewat API.
alter table public.login_attempts enable row level security;
revoke all on public.login_attempts from anon, authenticated;

create function public.resolve_login(p_username text, p_password text)
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_username text := lower(btrim(coalesce(p_username, '')));
  v_email text;
  v_hash text;
  max_failures constant int := 10;
  window_size constant interval := interval '15 minutes';
begin
  if (select count(*) from public.login_attempts a
      where a.username = v_username and a.attempted_at > now() - window_size) >= max_failures then
    raise exception 'terlalu banyak percobaan masuk' using errcode = 'FR006';
  end if;

  select u.email, u.encrypted_password into v_email, v_hash
    from public.profiles p
    join auth.users u on u.id = p.id
   where p.username = v_username;

  -- Hash palsu untuk username tak dikenal / akun tanpa password (Google):
  -- bcrypt tetap dihitung sekali, jadi waktu jawab tidak membocorkan
  -- username mana yang ada.
  if v_hash is null or v_hash = '' then
    v_hash := '$2a$10$yEUryarb6qOHP/EW7I4aluOLAleBWLZS6MFqKiCvehDLnts6HY4wC';
    v_email := null;
  end if;

  if extensions.crypt(coalesce(p_password, ''), v_hash) = v_hash
     and v_email is not null then
    delete from public.login_attempts a where a.username = v_username;
    return v_email;
  end if;

  insert into public.login_attempts (username) values (v_username);
  -- Bersihkan percobaan lama sesekali.
  delete from public.login_attempts a where a.attempted_at < now() - interval '1 day';
  return null;
end;
$$;

revoke execute on function public.resolve_login(text, text) from public;
grant execute on function public.resolve_login(text, text) to anon, authenticated;
