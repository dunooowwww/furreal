-- M15: edit & hapus hewan dari koleksi (catch tetap ada).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(11);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.com');
insert into public.animals (id, owner_id, name, kind, animal_type) values
  ('dddddddd-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Milo', 'pet', 'kucing'),
  ('dddddddd-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'Kiko', 'wild', 'burung');
insert into public.catches (id, user_id, animal_id, animal_photo_path, selfie_photo_path, catch_date, ai_personality)
values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'dddddddd-0000-0000-0000-000000000001', 'x', 'y', public.jakarta_today() - 1, 'si tukang tidur. hobi makan.'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111',
   'dddddddd-0000-0000-0000-000000000002', 'x', 'y', public.jakarta_today(), 'si berisik.');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select results_eq(
  $$select name, kind, animal_type, personality
    from public.edit_animal('dddddddd-0000-0000-0000-000000000001', '  Milo Gendut ', 'wild', '  Musang ', '  si raja parkiran.  ')$$,
  $$values ('Milo Gendut'::text, 'wild'::text, 'musang'::text, 'si raja parkiran.'::text)$$,
  'pemilik mengedit nama, kind, jenis (huruf kecil), kepribadian (dirapikan)'
);
select is(
  (select last_personality from public.my_collection() where animal_id = 'dddddddd-0000-0000-0000-000000000001'),
  'si raja parkiran.',
  'kartu koleksi memakai kepribadian hasil edit'
);
select is(
  (select personality from public.edit_animal('dddddddd-0000-0000-0000-000000000001', 'Milo', 'pet', '', '   ')),
  null,
  'kepribadian kosong → dihapus'
);
select results_eq(
  $$select animal_type, last_personality from public.my_collection() where animal_id = 'dddddddd-0000-0000-0000-000000000001'$$,
  $$values (null::text, 'si tukang tidur. hobi makan.'::text)$$,
  'tanpa kepribadian hewan → kembali ke kepribadian catch terakhir; jenis kosong → null'
);
select throws_ok(
  $$select public.edit_animal('dddddddd-0000-0000-0000-000000000001', '   ', 'pet', null, null)$$,
  '22023', null, 'nama kosong ditolak'
);
select throws_ok(
  $$select public.edit_animal('dddddddd-0000-0000-0000-000000000001', 'Milo', 'naga', null, null)$$,
  '22023', null, 'kind tidak dikenal ditolak'
);

-- hapus dari koleksi
select lives_ok(
  $$select public.remove_animal('dddddddd-0000-0000-0000-000000000002')$$,
  'pemilik menghapus hewan dari koleksi'
);
select results_eq(
  $$select name from public.my_collection()$$,
  $$values ('Milo'::text)$$,
  'hewan yang dihapus tidak muncul di koleksi'
);
select is(
  (select animal_id::text from public.catches where id = 'aaaaaaaa-0000-0000-0000-000000000002'),
  'dddddddd-0000-0000-0000-000000000002',
  'catch-nya tetap ada'
);
select throws_ok(
  $$select public.edit_animal('dddddddd-0000-0000-0000-000000000002', 'X', 'pet', null, null)$$,
  'P0002', null, 'hewan yang sudah dihapus tidak bisa diedit'
);

select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select throws_ok(
  $$select public.remove_animal('dddddddd-0000-0000-0000-000000000001')$$,
  'P0002', null, 'tidak bisa menghapus hewan orang lain'
);

select * from finish();
rollback;
