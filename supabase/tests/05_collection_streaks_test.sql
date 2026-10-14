-- M5: streak, ketemu lagi (encounter_count), kepemilikan hewan, koleksi.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(28);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.com');

insert into public.animals (id, owner_id, name, kind, animal_type) values
  ('dddddddd-0000-0000-0000-00000000000a', '11111111-1111-1111-1111-111111111111', 'Milo', 'pet', 'kucing'),
  ('dddddddd-0000-0000-0000-00000000000b', '22222222-2222-2222-2222-222222222222', 'Pak Kwek', 'wild', null);

-- create_catch butuh daily drop hari ini yang sudah turun (M6).
delete from public.daily_drops;
insert into public.daily_drops (drop_date, scheduled_at, sent_at)
  values (public.jakarta_today(), now(), now());

-- helper: catch alice di tanggal tertentu (sebagai admin, trigger tetap jalan)
create function pg_temp.alice_catch(p_id text, p_days_ago int) returns void language sql as $$
  insert into public.catches (id, user_id, animal_id, animal_photo_path, selfie_photo_path, location_hidden, catch_date, created_at)
  values (p_id::uuid, '11111111-1111-1111-1111-111111111111', 'dddddddd-0000-0000-0000-00000000000a',
          '11111111-1111-1111-1111-111111111111/' || p_id || '/animal.jpg',
          '11111111-1111-1111-1111-111111111111/' || p_id || '/selfie.jpg',
          true, public.jakarta_today() - p_days_ago, now() - make_interval(days => p_days_ago));
$$;

create function pg_temp.alice_streak() returns text language sql as $$
  select current || '/' || longest || '@' || (public.jakarta_today() - last_catch_date)
  from public.streaks where user_id = '11111111-1111-1111-1111-111111111111';
$$;

-- === streak ==================================================================
select pg_temp.alice_catch('aaaaaaaa-0000-0000-0000-000000000004', 4);
select is(pg_temp.alice_streak(), '1/1@4', 'catch pertama → streak 1');

select pg_temp.alice_catch('aaaaaaaa-0000-0000-0000-000000000003', 3);
select is(pg_temp.alice_streak(), '2/2@3', 'catch hari berikutnya → streak lanjut +1');

-- hari yang sama: hapus lalu catch ulang di tanggal yang sama
delete from public.catches where id = 'aaaaaaaa-0000-0000-0000-000000000003';
select pg_temp.alice_catch('aaaaaaaa-0000-0000-0000-000000000033', 3);
select is(pg_temp.alice_streak(), '2/2@3', 'catch di hari yang sama → streak tidak berubah');

-- terlewat 1 hari (2 hari lalu kosong)
select pg_temp.alice_catch('aaaaaaaa-0000-0000-0000-000000000001', 1);
select is(pg_temp.alice_streak(), '1/2@1', 'hari terlewat → streak reset ke 1, longest tetap');

select pg_temp.alice_catch('aaaaaaaa-0000-0000-0000-000000000000', 0);
select is(pg_temp.alice_streak(), '2/2@0', 'lanjut lagi sampai hari ini');

-- backfill: catch bertanggal lampau tidak mengubah streak
select pg_temp.alice_catch('aaaaaaaa-0000-0000-0000-000000000002', 2);
select is(pg_temp.alice_streak(), '2/2@0', 'catch bertanggal lampau (backfill) diabaikan trigger');

-- === my_streak =============================================================
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
select results_eq(
  'select current, longest from public.my_streak()',
  $$values (2, 2)$$,
  'my_streak: streak aktif ditampilkan'
);
select is_empty(
  $$select user_id from public.streaks where user_id = '22222222-2222-2222-2222-222222222222'$$,
  'user tidak bisa membaca streak orang lain'
);
select throws_ok(
  $$update public.streaks set current = 99$$,
  '42501', null,
  'user tidak bisa mengubah streak'
);
select throws_ok(
  $$select public.recompute_streak('11111111-1111-1111-1111-111111111111')$$,
  '42501', null,
  'recompute_streak khusus service role'
);
reset role;

-- streak putus: catch terakhir 3 hari lalu → tampil 0
update public.streaks set last_catch_date = public.jakarta_today() - 3
  where user_id = '11111111-1111-1111-1111-111111111111';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
select results_eq(
  'select current, longest from public.my_streak()',
  $$values (0, 2)$$,
  'my_streak: streak yang sudah putus ditampilkan 0'
);
reset role;

set local role service_role;
select results_eq(
  $$select current, longest from public.recompute_streak('11111111-1111-1111-1111-111111111111')$$,
  $$values (5, 5)$$,
  'recompute_streak menghitung ulang dari riwayat (4 hari lalu s/d hari ini)'
);
reset role;

-- === ketemu lagi =============================================================
select is(
  (select encounter_count from public.animals where id = 'dddddddd-0000-0000-0000-00000000000a'),
  5,
  'encounter_count = jumlah catch hewan itu'
);
delete from public.catches where id = 'aaaaaaaa-0000-0000-0000-000000000002';
select is(
  (select encounter_count from public.animals where id = 'dddddddd-0000-0000-0000-00000000000a'),
  4,
  'hapus catch mengurangi encounter_count'
);

-- bob: catch lama 3 hari lalu dengan Pak Kwek
insert into public.catches (id, user_id, animal_id, animal_photo_path, selfie_photo_path, location_hidden, catch_date, created_at)
values ('bbbbbbbb-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222', 'dddddddd-0000-0000-0000-00000000000b',
        'x/animal.jpg', 'x/selfie.jpg', true, public.jakarta_today() - 3, now() - interval '3 days');

select throws_ok(
  $$insert into public.catches (user_id, animal_id, animal_photo_path, selfie_photo_path, location_hidden, catch_date)
    values ('22222222-2222-2222-2222-222222222222', 'dddddddd-0000-0000-0000-00000000000a',
            'y/animal.jpg', 'y/selfie.jpg', true, public.jakarta_today() - 5)$$,
  'FR004', 'hewan bukan milikmu',
  'database menolak catch yang terhubung ke hewan milik orang lain'
);
select throws_ok(
  $$update public.catches set animal_id = 'dddddddd-0000-0000-0000-00000000000a'
    where id = 'bbbbbbbb-0000-0000-0000-000000000003'$$,
  'FR004', null,
  'mengubah animal_id ke hewan orang lain juga ditolak'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
insert into storage.objects (bucket_id, name) values
  ('catch-photos', '22222222-2222-2222-2222-222222222222/bbbbbbbb-0000-0000-0000-000000000000/animal.jpg'),
  ('catch-photos', '22222222-2222-2222-2222-222222222222/bbbbbbbb-0000-0000-0000-000000000000/selfie.jpg');

select throws_ok(
  $$select public.create_catch('bbbbbbbb-0000-0000-0000-000000000000', 'Milo', 'pet', null, true,
    null, null, 'dddddddd-0000-0000-0000-00000000000a')$$,
  'FR004', 'hewan bukan milikmu',
  'create_catch menolak "ketemu lagi" hewan milik orang lain'
);
select throws_ok(
  $$update public.animals set encounter_count = 99$$,
  '42501', null,
  'encounter_count tidak bisa diubah dari app'
);

select lives_ok(
  $$select public.create_catch('bbbbbbbb-0000-0000-0000-000000000000', 'abaikan', 'pet', null, true,
    '  Bebek ', 'patroli lagi.', 'dddddddd-0000-0000-0000-00000000000b')$$,
  'bob "ketemu lagi" Pak Kwek'
);
select results_eq(
  $$select name, kind, animal_type, encounter_count, last_seen_at > now() - interval '1 minute'
    from public.animals where id = 'dddddddd-0000-0000-0000-00000000000b'$$,
  $$values ('Pak Kwek'::text, 'wild'::text, 'bebek'::text, 2, true)$$,
  'ketemu lagi: encounter_count +1, last_seen_at diperbarui, nama/jenis hewan lama tetap, jenis kosong diisi'
);
select is(
  (select count(*)::int from public.animals where owner_id = '22222222-2222-2222-2222-222222222222'),
  1,
  'ketemu lagi tidak membuat hewan baru'
);
select results_eq(
  'select current from public.my_streak()',
  $$values (1)$$,
  'bob: catch hari ini setelah 3 hari bolong → streak 1'
);

select results_eq(
  $$select name, encounter_count, last_animal_photo_path, last_personality from public.my_collection()$$,
  $$values ('Pak Kwek'::text, 2,
    '22222222-2222-2222-2222-222222222222/bbbbbbbb-0000-0000-0000-000000000000/animal.jpg'::text,
    'patroli lagi.'::text)$$,
  'my_collection: hewan milik sendiri + foto & kepribadian catch terakhir'
);
select is(
  (select count(*)::int from public.my_collection() where name = 'Milo'),
  0,
  'my_collection hanya berisi hewan milik sendiri'
);
reset role;

-- hewan lama tanpa jenis tetap null kalau user tidak mengisi
select is(
  (select animal_type from public.animals where id = 'dddddddd-0000-0000-0000-00000000000a'),
  'kucing',
  'jenis hewan lama tidak tertimpa'
);

-- hapus akun: penghapusan berantai tidak bentrok dengan trigger encounter
select lives_ok(
  $$delete from auth.users where id = '11111111-1111-1111-1111-111111111111'$$,
  'hapus akun (cascade ke catch & hewan) tetap jalan'
);
select is(
  (select count(*)::int from public.animals where owner_id = '11111111-1111-1111-1111-111111111111')
  + (select count(*)::int from public.catches where user_id = '11111111-1111-1111-1111-111111111111')
  + (select count(*)::int from public.streaks where user_id = '11111111-1111-1111-1111-111111111111'),
  0,
  'data hewan, catch, dan streak ikut terhapus'
);
select is(
  (select current from public.streaks where user_id = '22222222-2222-2222-2222-222222222222'),
  1,
  'streak user lain tidak terganggu'
);

select * from finish();
rollback;
