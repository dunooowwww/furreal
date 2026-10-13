-- M1: profil otomatis, RLS profiles/circles/circle_members, RPC create_circle & join_circle.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(25);

-- alice & bob akan satu circle, carol di luar circle.
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.com'),
  ('33333333-3333-3333-3333-333333333333', 'carol@example.com');

select is(
  (select count(*)::int from public.profiles),
  3,
  'profil dibuat otomatis untuk setiap user baru'
);

update public.profiles set username = 'alice', display_name = 'alice', fcm_token = 'token-alice'
  where id = '11111111-1111-1111-1111-111111111111';
update public.profiles set username = 'bob', display_name = 'bob'
  where id = '22222222-2222-2222-2222-222222222222';
update public.profiles set username = 'carol', display_name = 'carol'
  where id = '33333333-3333-3333-3333-333333333333';

-- --- anon -------------------------------------------------------------------
set local role anon;
select throws_ok(
  'select id from public.profiles',
  '42501',
  null,
  'anon tidak bisa membaca profiles'
);
reset role;

-- --- alice: belum punya circle ----------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select results_eq(
  'select username from public.profiles',
  $$values ('alice')$$,
  'tanpa circle, alice hanya melihat profilnya sendiri'
);

select throws_ok(
  'select fcm_token from public.profiles',
  '42501',
  null,
  'kolom fcm_token tidak bisa dibaca lewat API'
);

select lives_ok(
  $$select public.create_circle('  kos ceria  ')$$,
  'alice bisa membuat circle'
);

select results_eq(
  'select name from public.circles',
  $$values ('kos ceria')$$,
  'nama circle di-trim dan alice bisa membaca circle miliknya'
);

select matches(
  (select invite_code from public.circles where name = 'kos ceria'),
  '^[A-HJ-NP-Z2-9]{6}$',
  'kode undangan 6 karakter tanpa karakter mirip'
);

select is(
  (select count(*)::int from public.circle_members),
  1,
  'pembuat circle otomatis jadi anggota'
);

select throws_ok(
  $$select public.create_circle('')$$,
  '23514',
  null,
  'nama circle kosong ditolak'
);

reset role;
select set_config('test.code', (select invite_code from public.circles where name = 'kos ceria'), true);

-- --- bob: belum gabung ------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);

select is_empty('select id from public.circles', 'bob belum bisa melihat circle alice');
select is_empty('select user_id from public.circle_members', 'bob belum bisa melihat anggota circle alice');
select is_empty(
  $$select id from public.profiles where username = 'alice'$$,
  'bob belum bisa melihat profil alice'
);

select throws_ok(
  $$select public.join_circle('ZZZZZZ')$$,
  'P0002',
  'kode undangan tidak ditemukan',
  'kode undangan salah ditolak'
);

select is(
  (select name from public.join_circle(lower(current_setting('test.code')))),
  'kos ceria',
  'bob bisa gabung lewat kode (tidak peka huruf besar/kecil)'
);

select lives_ok(
  $$select public.join_circle(current_setting('test.code'))$$,
  'gabung dua kali tidak error'
);

select is((select count(*)::int from public.circle_members), 2, 'bob melihat 2 anggota circle');
select results_eq(
  'select username from public.profiles order by username',
  $$values ('alice'), ('bob')$$,
  'setelah gabung, bob bisa melihat profil alice'
);

update public.profiles set display_name = 'diretas'
  where id = '11111111-1111-1111-1111-111111111111';

reset role;
select is(
  (select display_name from public.profiles where id = '11111111-1111-1111-1111-111111111111'),
  'alice',
  'bob tidak bisa mengubah profil alice'
);

-- --- carol: di luar circle --------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);

select is_empty('select id from public.circles', 'user di luar circle tidak bisa membaca circle');
select is_empty('select user_id from public.circle_members', 'user di luar circle tidak bisa membaca anggota');
select results_eq(
  'select username from public.profiles',
  $$values ('carol')$$,
  'user di luar circle tidak bisa membaca profil anggota circle'
);

select throws_ok(
  $$insert into public.circle_members (circle_id, user_id)
    select id, '33333333-3333-3333-3333-333333333333' from public.circles$$,
  '42501',
  null,
  'tidak bisa insert langsung ke circle_members'
);

select throws_ok(
  $$insert into public.circles (name, invite_code) values ('palsu', 'ABCDEF')$$,
  '42501',
  null,
  'tidak bisa insert langsung ke circles'
);

select throws_ok(
  $$update public.profiles set username = 'alice'
    where id = '33333333-3333-3333-3333-333333333333'$$,
  '23505',
  null,
  'username harus unik'
);

select lives_ok(
  $$update public.profiles set username = 'carol_baru', display_name = 'carol'
    where id = '33333333-3333-3333-3333-333333333333'$$,
  'user bisa mengubah username sendiri'
);

reset role;

select * from finish();
rollback;
