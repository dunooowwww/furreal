-- M8: resolve_login (username + password → email) dan batas percobaan.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(13);

insert into auth.users (id, email, encrypted_password) values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.com', extensions.crypt('rahasia-alice', extensions.gen_salt('bf', 4))),
  -- akun Google: tanpa password
  ('22222222-2222-2222-2222-222222222222', 'bob@example.com', '');
update public.profiles set username = 'alice' where id = '11111111-1111-1111-1111-111111111111';
update public.profiles set username = 'bob' where id = '22222222-2222-2222-2222-222222222222';

set local role anon;

select is(public.resolve_login('alice', 'rahasia-alice'), 'alice@example.com',
  'username + password benar → email (bisa dipanggil sebelum login)');
select is(public.resolve_login('  Alice ', 'rahasia-alice'), 'alice@example.com',
  'username tidak peka huruf besar & spasi');
select is(public.resolve_login('alice', 'salah'), null, 'password salah → null (email tidak bocor)');
select is(public.resolve_login('tidakada', 'rahasia-alice'), null, 'username tak dikenal → null');
select is(public.resolve_login('bob', ''), null, 'akun tanpa password (Google) → null');
select is(public.resolve_login(null, null), null, 'input kosong → null');

select throws_ok($$select * from public.login_attempts$$, '42501', null,
  'login_attempts tidak terbaca lewat API');

-- 10 gagal dalam 15 menit → dikunci, termasuk dengan password benar.
reset role;
delete from public.login_attempts;
insert into public.login_attempts (username)
  select 'alice' from generate_series(1, 9);
set local role anon;
select is(public.resolve_login('alice', 'salah'), null, 'percobaan gagal ke-10 masih dijawab');
select throws_ok($$select public.resolve_login('alice', 'rahasia-alice')$$, 'FR006', null,
  'setelah 10 kali gagal, username dikunci sementara');
select is(public.resolve_login('bob', 'apa'), null, 'kunci hanya untuk username itu');

reset role;
update public.login_attempts set attempted_at = now() - interval '16 minutes';
set local role anon;
select is(public.resolve_login('alice', 'rahasia-alice'), 'alice@example.com',
  'setelah 15 menit bisa masuk lagi');

reset role;
select is((select count(*)::int from public.login_attempts where username = 'alice'), 0,
  'masuk berhasil menghapus catatan gagal');

update public.login_attempts set attempted_at = now() - interval '2 days';
set local role anon;
select public.resolve_login('carol', 'x');
reset role;
select is((select count(*)::int from public.login_attempts), 1,
  'catatan lebih dari sehari dibersihkan');

select * from finish();
rollback;
