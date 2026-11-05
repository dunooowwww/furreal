-- M11: potongan foto hewan (cutout.png) untuk kartu koleksi.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(14);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.com'),
  ('33333333-3333-3333-3333-333333333333', 'carol@example.com');
insert into public.circles (id, name, invite_code, created_by) values
  ('cccccccc-0000-0000-0000-000000000001', 'kos', 'KSE234', '11111111-1111-1111-1111-111111111111');
insert into public.circle_members (circle_id, user_id) values
  ('cccccccc-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111'),
  ('cccccccc-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222');

insert into public.animals (id, owner_id, name, kind, animal_type) values
  ('dddddddd-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Milo', 'pet', 'kucing');
-- catch kemarin (supaya tidak kena kunci feed hari ini)
insert into public.catches (id, user_id, animal_id, animal_photo_path, selfie_photo_path, catch_date)
values ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
        'dddddddd-0000-0000-0000-000000000001',
        '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/animal.jpg',
        '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/selfie.jpg',
        public.jakarta_today() - 1);

select is(
  (select allowed_mime_types from storage.buckets where id = 'catch-photos'),
  array['image/jpeg', 'image/png'],
  'bucket catch-photos menerima PNG (potongan transparan)'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select throws_ok(
  $$select public.set_catch_cutout('aaaaaaaa-0000-0000-0000-000000000001', true)$$,
  'FR002', null,
  'potongan harus sudah ter-upload'
);
select lives_ok(
  $$insert into storage.objects (bucket_id, name) values
    ('catch-photos', '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/cutout.png')$$,
  'pemilik upload cutout.png ke folder catch-nya'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name) values
    ('catch-photos', '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/lain.png')$$,
  '42501', null,
  'nama file lain tetap ditolak'
);
select is(
  public.set_catch_cutout('aaaaaaaa-0000-0000-0000-000000000001', true),
  '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/cutout.png',
  'set_catch_cutout mengisi path potongan'
);
select results_eq(
  $$select last_catch_id, last_cutout_path, last_cutout_attempted from public.my_collection()$$,
  $$values ('aaaaaaaa-0000-0000-0000-000000000001'::uuid,
            '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/cutout.png'::text,
            true)$$,
  'koleksi menyertakan catch terakhir + potongannya'
);
select results_eq(
  $$select last_catch_date, last_area_label from public.my_collection()$$,
  $$values (public.jakarta_today() - 1, null::text)$$,
  'koleksi menyertakan tanggal & label area catch terakhir (untuk kartu)'
);
select is(public.set_catch_cutout('aaaaaaaa-0000-0000-0000-000000000001', false), null,
  'tanpa hewan terdeteksi: path dikosongkan');
select results_eq(
  $$select last_cutout_path, last_cutout_attempted from public.my_collection()$$,
  $$values (null::text, true)$$,
  'sudah dicoba → tidak diproses ulang'
);
select throws_ok(
  $$update public.catches set cutout_path = 'x', cutout_attempted = false$$,
  '42501', null,
  'kolom potongan tidak bisa diubah langsung'
);

-- bob (satu circle) bisa membaca potongan; carol tidak.
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select throws_ok(
  $$select public.set_catch_cutout('aaaaaaaa-0000-0000-0000-000000000001', false)$$,
  'P0002', null,
  'tidak bisa menandai catch orang lain'
);
select is(
  (select count(*)::int from storage.objects where name like '%/cutout.png'),
  1,
  'teman satu circle bisa membaca potongan'
);
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
select is(
  (select count(*)::int from storage.objects where name like '%/cutout.png'),
  0,
  'beda circle tidak bisa membaca potongan'
);

reset role;
set local role service_role;
select ok(
  (select bool_or(p like '%/cutout.png') from public.account_photo_paths('11111111-1111-1111-1111-111111111111') p),
  'hapus akun ikut menghapus potongan (folder catch-photos yang sama)'
);
reset role;

select * from finish();
rollback;
