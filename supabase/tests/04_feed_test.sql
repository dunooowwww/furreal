-- M4: reactions, comments, circle_feed, catch_comments.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(32);

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

insert into public.animals (id, owner_id, name, kind, animal_type, encounter_count) values
  ('dddddddd-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Milo', 'pet', 'kucing', 3),
  ('dddddddd-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'Pak Kwek', 'wild', null, 1);

insert into public.catches
  (id, user_id, animal_id, animal_photo_path, selfie_photo_path, ai_type, personality, ai_personality,
   location_hidden, is_late, catch_date, created_at)
values
  -- alice hari ini (lebih dulu)
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'dddddddd-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/animal.jpg',
   '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/selfie.jpg',
   'kucing', 'bos parkiran.', 'si penjaga parkiran.', true, false, public.jakarta_today(), now() - interval '30 minutes'),
  -- bob hari ini (lebih baru, telat)
  ('aaaaaaaa-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'dddddddd-0000-0000-0000-000000000002',
   '22222222-2222-2222-2222-222222222222/aaaaaaaa-0000-0000-0000-000000000002/animal.jpg',
   '22222222-2222-2222-2222-222222222222/aaaaaaaa-0000-0000-0000-000000000002/selfie.jpg',
   'bebek', null, 'patroli selokan.', true, true, public.jakarta_today(), now() - interval '5 minutes'),
  -- bob kemarin: tidak boleh muncul di feed hari ini
  ('aaaaaaaa-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222', 'dddddddd-0000-0000-0000-000000000002',
   '22222222-2222-2222-2222-222222222222/aaaaaaaa-0000-0000-0000-000000000003/animal.jpg',
   '22222222-2222-2222-2222-222222222222/aaaaaaaa-0000-0000-0000-000000000003/selfie.jpg',
   'bebek', null, null, true, false, public.jakarta_today() - 1, now() - interval '1 day');

insert into public.daily_drops (drop_date, sent_at)
  values (public.jakarta_today(), now() - interval '1 hour 45 minutes');

insert into storage.objects (bucket_id, name) values
  ('catch-photos', '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/animal.jpg'),
  ('catch-photos', '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/selfie.jpg');

-- === bob: anggota circle =====================================================
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);

select lives_ok(
  $$insert into public.reactions (catch_id, user_id, type)
    values ('aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'like'),
           ('aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'laugh')$$,
  'anggota circle bisa memberi reaksi suka & lucu'
);
select throws_ok(
  $$insert into public.reactions (catch_id, user_id, type)
    values ('aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'like')$$,
  '23505', null,
  'reaksi yang sama tidak bisa dobel'
);
select throws_ok(
  $$insert into public.reactions (catch_id, type) values ('aaaaaaaa-0000-0000-0000-000000000001', 'love')$$,
  '23514', null,
  'jenis reaksi hanya like/laugh'
);
select throws_ok(
  $$insert into public.reactions (catch_id, user_id, type)
    values ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'like')$$,
  '42501', null,
  'tidak bisa memberi reaksi atas nama orang lain'
);

select lives_ok(
  $$insert into public.comments (id, catch_id, body)
    values ('eeeeeeee-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'lucu banget!')$$,
  'anggota circle bisa berkomentar'
);
select throws_ok(
  $$insert into public.comments (catch_id, body) values ('aaaaaaaa-0000-0000-0000-000000000001', '   ')$$,
  '23514', null,
  'komentar kosong ditolak'
);
select throws_ok(
  $$insert into public.comments (catch_id, body) values ('aaaaaaaa-0000-0000-0000-000000000001', repeat('a', 301))$$,
  '23514', null,
  'komentar lebih dari 300 karakter ditolak'
);
select lives_ok(
  $$insert into public.comments (catch_id, body) values ('aaaaaaaa-0000-0000-0000-000000000001', repeat('a', 300))$$,
  'komentar tepat 300 karakter diterima'
);
select throws_ok(
  $$update public.comments set body = 'diubah'$$,
  '42501', null,
  'komentar tidak bisa diedit'
);

-- === carol: di luar circle ===================================================
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);

select is_empty('select id from public.catches', 'user di luar circle tidak bisa membaca catch');
select is_empty('select catch_id from public.reactions', 'user di luar circle tidak bisa membaca reaksi');
select is_empty('select id from public.comments', 'user di luar circle tidak bisa membaca komentar');
select is_empty(
  $$select id from storage.objects where bucket_id = 'catch-photos'$$,
  'user di luar circle tidak bisa membaca foto'
);
select is(
  public.can_read_catch_photo('11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/selfie.jpg'),
  false,
  'user di luar circle tidak bisa membuat signed URL foto selfie'
);
select throws_ok(
  $$insert into public.reactions (catch_id, type) values ('aaaaaaaa-0000-0000-0000-000000000001', 'like')$$,
  '42501', null,
  'user di luar circle tidak bisa memberi reaksi'
);
select throws_ok(
  $$insert into public.comments (catch_id, body) values ('aaaaaaaa-0000-0000-0000-000000000001', 'halo')$$,
  '42501', null,
  'user di luar circle tidak bisa berkomentar'
);
select is_empty(
  $$select * from public.catch_comments('aaaaaaaa-0000-0000-0000-000000000001')$$,
  'catch_comments kosong untuk user di luar circle'
);
select is_empty(
  $$select * from public.circle_feed('cccccccc-0000-0000-0000-000000000001')$$,
  'feed circle orang lain kosong'
);

-- === alice: pemilik catch ===================================================
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

delete from public.comments where id = 'eeeeeeee-0000-0000-0000-000000000001';
delete from public.reactions where user_id = '22222222-2222-2222-2222-222222222222';

select results_eq(
  $$select catch_id::text, display_name, animal_name, animal_type, encounter_count, personality,
           is_late, late_minutes
    from public.circle_feed('cccccccc-0000-0000-0000-000000000001')$$,
  $$values
    ('aaaaaaaa-0000-0000-0000-000000000002', 'Bob', 'Pak Kwek', 'bebek', 1, 'patroli selokan.', true, 40),
    ('aaaaaaaa-0000-0000-0000-000000000001', 'Alice', 'Milo', 'kucing', 3, 'bos parkiran.', false, null::int)$$,
  'feed: hanya catch hari ini, terbaru dulu, jenis & kepribadian final, telat berapa menit'
);

select results_eq(
  $$select like_count, laugh_count, comment_count, liked_by_me, laughed_by_me
    from public.circle_feed('cccccccc-0000-0000-0000-000000000001')
    where catch_id = 'aaaaaaaa-0000-0000-0000-000000000001'$$,
  $$values (1, 1, 2, false, false)$$,
  'feed: hitungan reaksi & komentar; pemilik tidak bisa menghapus komentar/reaksi orang lain'
);

select results_eq(
  $$select display_name, is_mine from public.catch_comments('aaaaaaaa-0000-0000-0000-000000000001')
    order by created_at limit 1$$,
  $$values ('Bob'::text, false)$$,
  'catch_comments: nama penulis terbaca, bukan milik saya'
);

select lives_ok(
  $$insert into public.reactions (catch_id, type) values ('aaaaaaaa-0000-0000-0000-000000000002', 'like')$$,
  'user_id reaksi otomatis = auth.uid()'
);
select results_eq(
  $$select liked_by_me, like_count from public.circle_feed('cccccccc-0000-0000-0000-000000000001')
    where catch_id = 'aaaaaaaa-0000-0000-0000-000000000002'$$,
  $$values (true, 1)$$,
  'feed: liked_by_me menandai reaksi sendiri'
);
select lives_ok(
  $$delete from public.reactions where catch_id = 'aaaaaaaa-0000-0000-0000-000000000002' and type = 'like'$$,
  'reaksi sendiri bisa dibatalkan'
);
select is(
  (select count(*)::int from public.reactions where catch_id = 'aaaaaaaa-0000-0000-0000-000000000002'),
  0,
  'reaksi benar-benar terhapus'
);
select lives_ok(
  $$insert into public.comments (id, catch_id, body)
    values ('eeeeeeee-0000-0000-0000-000000000009', 'aaaaaaaa-0000-0000-0000-000000000002', 'mantap')$$,
  'pemilik catch lain di circle bisa berkomentar'
);
select is(
  (select is_mine from public.catch_comments('aaaaaaaa-0000-0000-0000-000000000002')),
  true,
  'catch_comments: is_mine untuk komentar sendiri'
);

-- === bob: hapus komentar sendiri vs orang lain ===============================
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);

delete from public.comments where id = 'eeeeeeee-0000-0000-0000-000000000009';
reset role;
select is(
  (select count(*)::int from public.comments where id = 'eeeeeeee-0000-0000-0000-000000000009'),
  1,
  'user tidak bisa menghapus komentar orang lain'
);
select is(
  (select count(*)::int from public.comments where id = 'eeeeeeee-0000-0000-0000-000000000001'),
  1,
  'pemilik catch pun tidak bisa menghapus komentar orang lain'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select lives_ok(
  $$delete from public.comments where id = 'eeeeeeee-0000-0000-0000-000000000001'$$,
  'user bisa menghapus komentarnya sendiri'
);
reset role;
select is(
  (select count(*)::int from public.comments where id = 'eeeeeeee-0000-0000-0000-000000000001'),
  0,
  'komentar sendiri benar-benar terhapus'
);

-- === hapus catch ikut menghapus reaksi & komentarnya ========================
delete from public.catches where id = 'aaaaaaaa-0000-0000-0000-000000000001';
select is(
  (select count(*)::int from public.reactions where catch_id = 'aaaaaaaa-0000-0000-0000-000000000001')
  + (select count(*)::int from public.comments where catch_id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  0,
  'reaksi & komentar ikut terhapus bersama catch'
);

select * from finish();
rollback;
