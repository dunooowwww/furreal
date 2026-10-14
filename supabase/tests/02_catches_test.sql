-- M2: catches, animals, daily_drops, storage catch-photos.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(31);

-- alice & bob satu circle, carol di luar circle.
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.com'),
  ('33333333-3333-3333-3333-333333333333', 'carol@example.com');
insert into public.circles (id, name, invite_code, created_by) values
  ('cccccccc-0000-0000-0000-000000000001', 'kos ceria', 'KSE234', '11111111-1111-1111-1111-111111111111');
insert into public.circle_members (circle_id, user_id) values
  ('cccccccc-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111'),
  ('cccccccc-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222');

-- === alice ==================================================================
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select lives_ok(
  $$insert into storage.objects (bucket_id, name) values
    ('catch-photos', '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/animal.jpg'),
    ('catch-photos', '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/selfie.jpg')$$,
  'upload foto ke folder sendiri diizinkan'
);

select throws_ok(
  $$insert into storage.objects (bucket_id, name) values
    ('catch-photos', '22222222-2222-2222-2222-222222222222/aaaaaaaa-0000-0000-0000-000000000009/animal.jpg')$$,
  '42501', null,
  'upload ke folder user lain ditolak'
);

select throws_ok(
  $$insert into storage.objects (bucket_id, name) values
    ('catch-photos', '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/lain.png')$$,
  '42501', null,
  'nama file selain animal.jpg/selfie.jpg ditolak'
);

select throws_ok(
  $$insert into public.catches (user_id, animal_photo_path, selfie_photo_path, catch_date)
    values ('11111111-1111-1111-1111-111111111111', 'a', 'b', current_date)$$,
  '42501', null,
  'tidak bisa insert langsung ke catches'
);

select lives_ok(
  $$select public.create_catch('aaaaaaaa-0000-0000-0000-000000000001', '  Milo ', 'pet', 'sekitar Depok, Sleman', false)$$,
  'alice bisa membuat catch lewat RPC'
);

select results_eq(
  $$select catch_date = public.jakarta_today(), is_late, user_id::text,
           animal_photo_path, selfie_photo_path, area_label, location_hidden
    from public.catches$$,
  $$values (true, false, '11111111-1111-1111-1111-111111111111',
    '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/animal.jpg',
    '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/selfie.jpg',
    'sekitar Depok, Sleman', false)$$,
  'catch tersimpan: tanggal Asia/Jakarta, tidak telat tanpa daily drop, path foto benar'
);

select results_eq(
  $$select a.name, a.kind, a.encounter_count
    from public.catches c join public.animals a on a.id = c.animal_id$$,
  $$values ('Milo', 'pet', 1)$$,
  'hewan baru dibuat (nama di-trim) dan terhubung ke catch'
);

insert into storage.objects (bucket_id, name) values
  ('catch-photos', '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000002/animal.jpg'),
  ('catch-photos', '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000002/selfie.jpg');

select throws_ok(
  $$select public.create_catch('aaaaaaaa-0000-0000-0000-000000000002', 'Milo', 'pet', null, true)$$,
  'FR001', 'sudah catch hari ini',
  'catch kedua di hari yang sama ditolak'
);

select is(
  (select count(*)::int from public.animals),
  1,
  'catch yang ditolak tidak meninggalkan hewan yatim'
);

select throws_ok(
  $$update public.catches set is_late = true$$,
  '42501', null,
  'is_late tidak bisa diubah user'
);

select lives_ok(
  $$update public.catches set area_label = null, location_hidden = true$$,
  'pemilik bisa menyembunyikan lokasi catch-nya'
);

reset role;

-- === carol (di luar circle) =================================================
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);

select throws_ok(
  $$select public.create_catch('aaaaaaaa-0000-0000-0000-000000000003', 'Kiko', 'wild', null, false)$$,
  'FR002', 'foto belum ter-upload',
  'catch tanpa foto ter-upload ditolak'
);

select is_empty('select id from public.catches', 'user di luar circle tidak bisa membaca catch');
select is_empty('select id from public.animals', 'user di luar circle tidak bisa membaca hewan');
select is_empty(
  $$select id from storage.objects where bucket_id = 'catch-photos'$$,
  'user di luar circle tidak bisa membaca foto catch'
);

select throws_ok(
  $$insert into storage.objects (bucket_id, name) values
    ('catch-photos', '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/animal.jpg')$$,
  '42501', null,
  'user lain tidak bisa upload ke folder alice'
);

-- DELETE langsung ke storage.objects ditolak Supabase (wajib lewat Storage API),
-- jadi aturan hapus/timpa dicek lewat helper yang dipakai policy-nya.
select is(
  public.is_own_catch_photo_path('11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/animal.jpg'),
  false,
  'user lain tidak boleh menghapus/menimpa foto alice'
);

reset role;

-- === bob (satu circle dengan alice) =========================================
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);

select is((select count(*)::int from public.catches), 1, 'anggota circle bisa membaca catch alice');
select is((select count(*)::int from public.animals), 1, 'anggota circle bisa membaca hewan alice');
select is(
  (select count(*)::int from storage.objects where bucket_id = 'catch-photos'),
  4,
  'anggota circle bisa membaca foto alice'
);

delete from public.catches;
delete from public.animals;
update public.catches set location_hidden = false, area_label = 'diretas';

-- daily drop terkirim 2 jam lalu → catch sekarang telat.
reset role;
insert into public.daily_drops (drop_date, sent_at) values (public.jakarta_today(), now() - interval '2 hours');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);

insert into storage.objects (bucket_id, name) values
  ('catch-photos', '22222222-2222-2222-2222-222222222222/bbbbbbbb-0000-0000-0000-000000000001/animal.jpg'),
  ('catch-photos', '22222222-2222-2222-2222-222222222222/bbbbbbbb-0000-0000-0000-000000000001/selfie.jpg');

select results_eq(
  $$select is_late, location_hidden, area_label
    from public.create_catch('bbbbbbbb-0000-0000-0000-000000000001', 'Pak Kwek', 'wild', '  ', false)$$,
  $$values (true, true, null::text)$$,
  'telat > 1 jam setelah daily drop; area kosong → lokasi disembunyikan'
);

select throws_ok(
  $$select public.create_catch('bbbbbbbb-0000-0000-0000-000000000002', 'Pak Kwek', 'ikan', null, true)$$,
  'FR001', null,
  'bob juga hanya boleh satu catch per hari'
);

reset role;

-- === cek sebagai admin ======================================================
select results_eq(
  $$select location_hidden, area_label from public.catches
    where user_id = '11111111-1111-1111-1111-111111111111'$$,
  $$values (true, null::text)$$,
  'anggota circle tidak bisa menghapus atau mengubah catch alice'
);
select is(
  (select count(*)::int from public.animals where owner_id = '11111111-1111-1111-1111-111111111111'),
  1,
  'anggota circle tidak bisa menghapus hewan alice'
);
select ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and cmd = 'DELETE' and qual like '%is_own_catch_photo_path(name)%'
  ),
  'hapus foto catch dijaga is_own_catch_photo_path'
);
select is(
  (select count(*)::int from public.daily_drops),
  1,
  'daily_drops terisi untuk test is_late'
);

-- === alice: hapus catch hari ini lalu catch ulang (alur debug) ==============
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select is((select count(*)::int from public.daily_drops), 1, 'user login bisa membaca daily_drops');
select throws_ok(
  $$insert into public.daily_drops (drop_date, sent_at) values (current_date + 1, now())$$,
  '42501', null,
  'user tidak bisa menulis daily_drops'
);

select ok(
  public.is_own_catch_photo_path('11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/selfie.jpg'),
  'pemilik boleh menghapus/menimpa foto di foldernya sendiri'
);
select lives_ok(
  $$delete from public.catches where catch_date = public.jakarta_today()$$,
  'pemilik bisa menghapus catch hari ini'
);
select lives_ok(
  $$select public.create_catch('aaaaaaaa-0000-0000-0000-000000000002', 'Milo', 'pet', null, false)$$,
  'setelah dihapus, pemilik bisa catch lagi hari ini'
);

reset role;

select * from finish();
rollback;
