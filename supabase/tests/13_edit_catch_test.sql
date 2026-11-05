-- M13: edit caption & hapus catch sendiri (streak dihitung ulang).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(9);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.com');
insert into public.animals (id, owner_id, name, kind) values
  ('dddddddd-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Milo', 'pet');

-- alice catch kemarin & hari ini → streak 2.
insert into public.catches (id, user_id, animal_id, animal_photo_path, selfie_photo_path, catch_date, caption)
values
  ('aaaaaaaa-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111',
   'dddddddd-0000-0000-0000-000000000001', 'x', 'y', public.jakarta_today() - 1, null),
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'dddddddd-0000-0000-0000-000000000001', 'x', 'y', public.jakarta_today(), 'lama');

select is((select current from public.streaks where user_id = '11111111-1111-1111-1111-111111111111'), 2,
  'streak 2 setelah catch kemarin & hari ini');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select is(
  (select caption from public.edit_catch('aaaaaaaa-0000-0000-0000-000000000001', '  baru  ')),
  'baru',
  'pemilik mengubah caption (dirapikan)'
);
select is(
  (select caption from public.edit_catch('aaaaaaaa-0000-0000-0000-000000000001', '   ')),
  null,
  'caption kosong → dihapus'
);
select lives_ok(
  $$update public.animals set name = 'Milo Baru' where id = 'dddddddd-0000-0000-0000-000000000001'$$,
  'pemilik mengganti nama hewan'
);

select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select throws_ok(
  $$select public.edit_catch('aaaaaaaa-0000-0000-0000-000000000001', 'iseng')$$,
  'P0002', null,
  'tidak bisa mengedit catch orang lain'
);

-- alice menghapus catch hari ini → streak kembali 1 (kemarin).
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
delete from public.catches where id = 'aaaaaaaa-0000-0000-0000-000000000001';
reset role;
select results_eq(
  $$select current, last_catch_date from public.streaks where user_id = '11111111-1111-1111-1111-111111111111'$$,
  $$values (1, public.jakarta_today() - 1)$$,
  'hapus catch hari ini → streak dihitung ulang'
);
select is(
  (select encounter_count from public.animals where id = 'dddddddd-0000-0000-0000-000000000001'),
  1,
  'pertemuan hewan ikut turun'
);

-- hapus semua catch → streak 0.
delete from public.catches where user_id = '11111111-1111-1111-1111-111111111111';
select is((select current from public.streaks where user_id = '11111111-1111-1111-1111-111111111111'), 0,
  'tanpa catch → streak 0');

-- hapus akun tetap berantai bersih (trigger dilewati di hapus berantai).
insert into public.catches (user_id, animal_photo_path, selfie_photo_path, catch_date)
values ('11111111-1111-1111-1111-111111111111', 'x', 'y', public.jakarta_today());
select lives_ok(
  $$delete from auth.users where id = '11111111-1111-1111-1111-111111111111'$$,
  'hapus akun tidak gagal karena hitung ulang streak'
);

select * from finish();
rollback;
