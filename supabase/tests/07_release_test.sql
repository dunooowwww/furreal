-- M7: pedoman kesejahteraan hewan, hapus akun (cascade), circle kosong.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(18);

-- alice & bob satu circle; carol sendirian di circle-nya.
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.com'),
  ('33333333-3333-3333-3333-333333333333', 'carol@example.com');
insert into public.circles (id, name, invite_code, created_by) values
  ('cccccccc-0000-0000-0000-000000000001', 'kos ceria', 'KSE234', '11111111-1111-1111-1111-111111111111'),
  ('cccccccc-0000-0000-0000-000000000002', 'sendiri', 'SND234', '33333333-3333-3333-3333-333333333333');
insert into public.circle_members (circle_id, user_id) values
  ('cccccccc-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111'),
  ('cccccccc-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222'),
  ('cccccccc-0000-0000-0000-000000000002', '33333333-3333-3333-3333-333333333333');

-- alice: hewan, catch, streak, log AI; bob bereaksi & berkomentar di catch alice,
-- alice bereaksi & berkomentar di catch bob.
insert into public.animals (id, owner_id, name, kind) values
  ('dddddddd-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Milo', 'pet'),
  ('dddddddd-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'Pak Kwek', 'wild');
insert into public.catches (id, user_id, animal_id, animal_photo_path, selfie_photo_path, location_hidden, catch_date) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'dddddddd-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/animal.jpg',
   '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/selfie.jpg', true, public.jakarta_today()),
  ('aaaaaaaa-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'dddddddd-0000-0000-0000-000000000002',
   '22222222-2222-2222-2222-222222222222/aaaaaaaa-0000-0000-0000-000000000002/animal.jpg',
   '22222222-2222-2222-2222-222222222222/aaaaaaaa-0000-0000-0000-000000000002/selfie.jpg', true, public.jakarta_today());
insert into public.reactions (catch_id, user_id, type) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'like'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'laugh');
insert into public.comments (catch_id, user_id, body) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'lucu!'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'bebeknya galak');
insert into public.ai_identifications (user_id, catch_id, provider, status) values
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-0000-0000-0000-000000000001', 'mock', 'ok');

-- === pedoman =================================================================
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);

select is(
  (select guidelines_accepted_at from public.profiles where id = auth.uid()),
  null,
  'pedoman belum disetujui untuk akun baru'
);
select isnt(public.accept_guidelines(), null, 'user menyetujui pedoman');
select is(
  (select guidelines_accepted_at from public.profiles where id = auth.uid()),
  now(),
  'waktu persetujuan tersimpan dan terbaca pemiliknya'
);
select throws_ok(
  $$update public.profiles set guidelines_accepted_at = null where id = auth.uid()$$,
  '42501', null,
  'persetujuan tidak bisa diubah langsung'
);
select throws_ok(
  $$select public.account_photo_paths('11111111-1111-1111-1111-111111111111')$$,
  '42501', null,
  'user tidak bisa melihat daftar file akun orang lain'
);

-- Foto alice di storage (lewat policy upload biasa).
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
insert into storage.objects (bucket_id, name) values
  ('catch-photos', '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/animal.jpg'),
  ('catch-photos', '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/selfie.jpg'),
  ('catch-photos', '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000009/animal.jpg');
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
insert into storage.objects (bucket_id, name) values
  ('catch-photos', '22222222-2222-2222-2222-222222222222/aaaaaaaa-0000-0000-0000-000000000002/animal.jpg');

set local role anon;
select throws_ok('select public.accept_guidelines()', '42501', null, 'anon tidak bisa menyetujui pedoman');

-- === daftar file (service role) ==============================================
set local role service_role;
select results_eq(
  $$select public.account_photo_paths('11111111-1111-1111-1111-111111111111')$$,
  $$values
    ('11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/animal.jpg'::text),
    ('11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/selfie.jpg'),
    ('11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000009/animal.jpg')$$,
  'semua file alice, termasuk foto catch yang batal diposting, dan bukan milik orang lain'
);
reset role;

-- === hapus akun bob ==========================================================
-- storage.objects tidak punya FK ke auth.users: foto TIDAK ikut terhapus oleh
-- cascade, makanya delete-account menghapusnya dulu lewat Storage API.
select lives_ok(
  $$delete from auth.users where id = '22222222-2222-2222-2222-222222222222'$$,
  'menghapus user auth berhasil'
);
select is((select count(*)::int from public.profiles where id = '22222222-2222-2222-2222-222222222222'), 0, 'profil terhapus');
select is((select count(*)::int from public.catches where user_id = '22222222-2222-2222-2222-222222222222'), 0, 'catch terhapus');
select is((select count(*)::int from public.animals where owner_id = '22222222-2222-2222-2222-222222222222'), 0, 'hewan terhapus');
select is(
  (select count(*)::int from public.reactions where user_id = '22222222-2222-2222-2222-222222222222'
     or catch_id = 'aaaaaaaa-0000-0000-0000-000000000002'),
  0,
  'reaksi bob & reaksi di catch bob terhapus'
);
select is(
  (select count(*)::int from public.comments where user_id = '22222222-2222-2222-2222-222222222222'
     or catch_id = 'aaaaaaaa-0000-0000-0000-000000000002'),
  0,
  'komentar bob & komentar di catch bob terhapus'
);
select is((select count(*)::int from public.circle_members where user_id = '22222222-2222-2222-2222-222222222222'), 0, 'keanggotaan circle terhapus');

select results_eq(
  $$select (select count(*) from public.catches where user_id = '11111111-1111-1111-1111-111111111111')::int,
           (select count(*) from public.reactions where user_id = '11111111-1111-1111-1111-111111111111')::int,
           (select count(*) from public.comments where user_id = '11111111-1111-1111-1111-111111111111')::int,
           (select count(*) from public.ai_identifications where user_id = '11111111-1111-1111-1111-111111111111')::int$$,
  $$values (1, 0, 0, 1)$$,
  'data alice tetap ada (kecuali reaksi/komentarnya di catch bob)'
);
select is(
  (select count(*)::int from public.circles where id = 'cccccccc-0000-0000-0000-000000000001'),
  1,
  'circle yang masih punya anggota tetap ada'
);

-- === carol: anggota terakhir circle-nya ======================================
select lives_ok(
  $$delete from auth.users where id = '33333333-3333-3333-3333-333333333333'$$,
  'menghapus anggota terakhir circle'
);
select is(
  (select count(*)::int from public.circles where id = 'cccccccc-0000-0000-0000-000000000002'),
  0,
  'circle tanpa anggota ikut terhapus'
);

select * from finish();
rollback;
