-- M9: feed dikunci sampai catch, foto profil (avatars), keluar circle.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(35);

-- alice & bob satu circle (kos), carol di luar circle.
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.com'),
  ('33333333-3333-3333-3333-333333333333', 'carol@example.com');
update public.profiles set username = 'alice', display_name = 'Alice' where id = '11111111-1111-1111-1111-111111111111';
update public.profiles set username = 'bob', display_name = 'Bob' where id = '22222222-2222-2222-2222-222222222222';
update public.profiles set username = 'carol', display_name = 'Carol' where id = '33333333-3333-3333-3333-333333333333';

insert into public.circles (id, name, invite_code, created_by) values
  ('cccccccc-0000-0000-0000-000000000001', 'kos', 'KSE234', '11111111-1111-1111-1111-111111111111'),
  ('cccccccc-0000-0000-0000-000000000002', 'lain', 'LNA234', '33333333-3333-3333-3333-333333333333');
insert into public.circle_members (circle_id, user_id) values
  ('cccccccc-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111'),
  ('cccccccc-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222'),
  ('cccccccc-0000-0000-0000-000000000002', '33333333-3333-3333-3333-333333333333');

delete from public.daily_drops;
insert into public.daily_drops (drop_date, scheduled_at, sent_at)
values (public.jakarta_today(), now() - interval '10 minutes', now() - interval '10 minutes');

insert into public.animals (id, owner_id, name, kind, animal_type) values
  ('dddddddd-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Milo', 'pet', 'kucing'),
  ('dddddddd-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'Pak Kwek', 'wild', 'bebek');

-- alice: catch hari ini (a1) dan kemarin (a0).
insert into public.catches
  (id, user_id, animal_id, animal_photo_path, selfie_photo_path, personality, catch_date, created_at)
values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'dddddddd-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/animal.jpg',
   '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/selfie.jpg',
   'bos kos.', public.jakarta_today(), now() - interval '5 minutes'),
  ('aaaaaaaa-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111',
   'dddddddd-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000000/animal.jpg',
   '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000000/selfie.jpg',
   'kemarin.', public.jakarta_today() - 1, now() - interval '1 day');
insert into storage.objects (bucket_id, name, owner) values
  ('catch-photos', '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/animal.jpg', '11111111-1111-1111-1111-111111111111'),
  ('catch-photos', '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/selfie.jpg', '11111111-1111-1111-1111-111111111111'),
  ('catch-photos', '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000000/animal.jpg', '11111111-1111-1111-1111-111111111111'),
  ('catch-photos', '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000000/selfie.jpg', '11111111-1111-1111-1111-111111111111');
insert into public.comments (catch_id, user_id, body) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'milo lapar');
insert into public.reactions (catch_id, user_id, type) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'like');

-- === bob belum catch hari ini: catch alice hari ini terkunci ================
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);

select is(public.has_caught_today(), false, 'bob belum catch hari ini');
select is(
  (select array_agg(id::text) from public.catches),
  array['aaaaaaaa-0000-0000-0000-000000000000'],
  'bob hanya bisa membaca catch alice kemarin'
);
select is(
  (select count(*)::int from storage.objects where bucket_id = 'catch-photos'),
  2,
  'bob hanya bisa membaca foto catch kemarin'
);
select results_eq(
  $$select username, locked, animal_name, personality, animal_photo_path, selfie_photo_path, like_count, comment_count
    from public.circle_feed('cccccccc-0000-0000-0000-000000000001')$$,
  $$values ('alice'::text, true, null::text, null::text, null::text, null::text, 0, 0)$$,
  'feed: catch alice muncul terkunci, tanpa isi'
);
select is(
  (select count(*)::int from public.catch_comments('aaaaaaaa-0000-0000-0000-000000000001')),
  0,
  'komentar catch terkunci tidak terbaca'
);
select is(
  (select count(*)::int from public.reactions),
  0,
  'reaksi catch terkunci tidak terbaca'
);
select throws_ok(
  $$insert into public.reactions (catch_id, type) values ('aaaaaaaa-0000-0000-0000-000000000001', 'laugh')$$,
  '42501', null,
  'tidak bisa memberi reaksi ke catch terkunci'
);
select throws_ok(
  $$insert into public.comments (catch_id, body) values ('aaaaaaaa-0000-0000-0000-000000000001', 'intip')$$,
  '42501', null,
  'tidak bisa berkomentar di catch terkunci'
);
select is(public.can_read_catch_photo('11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/animal.jpg'),
  false, 'foto catch terkunci tidak bisa di-signed URL');
select is(public.can_read_catch_photo('11111111-1111-1111-1111-111111111111/zzz/animal.jpg'),
  false, 'path foto tidak valid ditolak');

-- === alice tetap melihat miliknya sendiri =====================================
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
select is(
  (select locked from public.circle_feed('cccccccc-0000-0000-0000-000000000001')),
  false,
  'pemilik selalu melihat catch-nya sendiri'
);
select is(public.can_read_catch_photo('11111111-1111-1111-1111-111111111111/eeeeeeee-0000-0000-0000-000000000001/animal.jpg'),
  true, 'pemilik boleh membaca foto sendiri sebelum catch dibuat');

-- === bob catch → feed terbuka ==================================================
reset role;
insert into public.catches
  (id, user_id, animal_id, animal_photo_path, selfie_photo_path, catch_date)
values
  ('bbbbbbbb-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222',
   'dddddddd-0000-0000-0000-000000000002',
   '22222222-2222-2222-2222-222222222222/bbbbbbbb-0000-0000-0000-000000000001/animal.jpg',
   '22222222-2222-2222-2222-222222222222/bbbbbbbb-0000-0000-0000-000000000001/selfie.jpg',
   public.jakarta_today());
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);

select is(public.has_caught_today(), true, 'bob sudah catch hari ini');
select is((select count(*)::int from public.catches), 3, 'setelah catch, bob membaca semua catch circle');
select is(
  (select count(*)::int from storage.objects where bucket_id = 'catch-photos'),
  4,
  'setelah catch, foto alice hari ini terbaca'
);
select results_eq(
  $$select username, locked, animal_name, personality, like_count, comment_count
    from public.circle_feed('cccccccc-0000-0000-0000-000000000001') where username = 'alice'$$,
  $$values ('alice'::text, false, 'Milo'::text, 'bos kos.'::text, 1, 1)$$,
  'feed: catch alice terbuka lengkap'
);
select is(
  (select count(*)::int from public.catch_comments('aaaaaaaa-0000-0000-0000-000000000001')),
  1,
  'komentar terbaca setelah catch'
);
select lives_ok(
  $$insert into public.reactions (catch_id, type) values ('aaaaaaaa-0000-0000-0000-000000000001', 'laugh')$$,
  'reaksi bisa diberikan setelah catch'
);

-- === carol (beda circle) ======================================================
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
select is(
  (select count(*)::int from public.circle_feed('cccccccc-0000-0000-0000-000000000001')),
  0,
  'bukan anggota: circle_feed kosong walau security definer'
);
select is((select count(*)::int from public.catches), 0, 'carol tidak membaca catch circle lain (termasuk kemarin)');

-- === foto profil =============================================================
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
select lives_ok(
  $$insert into storage.objects (bucket_id, name) values
    ('avatars', '11111111-1111-1111-1111-111111111111/f0000000-0000-0000-0000-000000000001.jpg')$$,
  'alice upload foto profil ke foldernya'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name) values
    ('avatars', '22222222-2222-2222-2222-222222222222/f0000000-0000-0000-0000-000000000002.jpg')$$,
  '42501', null,
  'tidak bisa upload foto profil ke folder orang lain'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name) values
    ('avatars', '11111111-1111-1111-1111-111111111111/foto.png')$$,
  '42501', null,
  'nama file foto profil harus {uuid}.jpg'
);
select lives_ok(
  $$update public.profiles set avatar_path = '11111111-1111-1111-1111-111111111111/f0000000-0000-0000-0000-000000000001.jpg'
    where id = '11111111-1111-1111-1111-111111111111'$$,
  'alice memasang foto profil'
);
select throws_ok(
  $$update public.profiles set avatar_path = '22222222-2222-2222-2222-222222222222/f0000000-0000-0000-0000-000000000002.jpg'
    where id = '11111111-1111-1111-1111-111111111111'$$,
  '23514', null,
  'avatar_path harus di folder sendiri'
);

select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select is(
  (select count(*)::int from storage.objects where bucket_id = 'avatars'),
  1,
  'teman satu circle bisa membaca foto profil alice'
);
select is(
  (select avatar_path from public.circle_feed('cccccccc-0000-0000-0000-000000000001') where username = 'alice'),
  '11111111-1111-1111-1111-111111111111/f0000000-0000-0000-0000-000000000001.jpg',
  'feed menyertakan foto profil'
);

select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
select is(
  (select count(*)::int from storage.objects where bucket_id = 'avatars'),
  0,
  'beda circle tidak bisa membaca foto profil alice'
);
select throws_ok(
  $$select public.account_avatar_paths('11111111-1111-1111-1111-111111111111')$$,
  '42501', null,
  'account_avatar_paths hanya untuk service role'
);

reset role;
set local role service_role;
select is(
  (select array_agg(p) from public.account_avatar_paths('11111111-1111-1111-1111-111111111111') p),
  array['11111111-1111-1111-1111-111111111111/f0000000-0000-0000-0000-000000000001.jpg'],
  'service role mendapat daftar foto profil untuk hapus akun'
);
reset role;

-- === keluar circle ===========================================================
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select lives_ok(
  $$select public.leave_circle('cccccccc-0000-0000-0000-000000000001')$$,
  'bob keluar dari circle kos'
);
select is((select count(*)::int from public.circles), 0, 'bob tidak lagi punya circle');
select is(
  (select count(*)::int from public.catches where user_id = '11111111-1111-1111-1111-111111111111'),
  0,
  'setelah keluar, catch alice tidak terbaca lagi'
);
select throws_ok(
  $$select public.leave_circle('cccccccc-0000-0000-0000-000000000001')$$,
  'P0002', null,
  'keluar dari circle yang bukan miliknya ditolak'
);

select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
select public.leave_circle('cccccccc-0000-0000-0000-000000000001');
reset role;
select is(
  (select count(*)::int from public.circles where id = 'cccccccc-0000-0000-0000-000000000001'),
  0,
  'anggota terakhir keluar → circle ikut terhapus'
);

select * from finish();
rollback;
