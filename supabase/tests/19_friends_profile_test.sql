-- M18/M19: teman (minta + terima), akses teman, feed teman, profil.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(24);

-- alice & bob beda circle; carol orang asing; dave satu circle dengan alice.
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.com'),
  ('33333333-3333-3333-3333-333333333333', 'carol@example.com'),
  ('44444444-4444-4444-4444-444444444444', 'dave@example.com');
update public.profiles set username = 'alice', display_name = 'Alice', fcm_token = 'tok-alice' where id = '11111111-1111-1111-1111-111111111111';
update public.profiles set username = 'bob', display_name = 'Bob', fcm_token = 'tok-bob' where id = '22222222-2222-2222-2222-222222222222';
update public.profiles set username = 'carol' where id = '33333333-3333-3333-3333-333333333333';
update public.profiles set username = 'dave' where id = '44444444-4444-4444-4444-444444444444';
insert into public.circles (id, name, invite_code, created_by) values
  ('cccccccc-0000-0000-0000-000000000001', 'kos', 'KSE234', '11111111-1111-1111-1111-111111111111');
insert into public.circle_members (circle_id, user_id) values
  ('cccccccc-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111'),
  ('cccccccc-0000-0000-0000-000000000001', '44444444-4444-4444-4444-444444444444');

insert into public.animals (id, owner_id, name, kind, pinned_at) values
  ('dddddddd-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'Bobcat', 'wild', now());
insert into public.catches (id, user_id, animal_id, animal_photo_path, selfie_photo_path, catch_date) values
  ('bbbbbbbb-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222',
   'dddddddd-0000-0000-0000-000000000002',
   '22222222-2222-2222-2222-222222222222/bbbbbbbb-0000-0000-0000-000000000001/animal.jpg', 'y',
   public.jakarta_today() - 1);
insert into storage.objects (bucket_id, name, owner) values
  ('catch-photos', '22222222-2222-2222-2222-222222222222/bbbbbbbb-0000-0000-0000-000000000001/animal.jpg',
   '22222222-2222-2222-2222-222222222222');

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
$$;

set local role authenticated;
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');

-- === sebelum berteman ==========================================================
select is_empty($$select 1 from public.profiles where username = 'bob'$$, 'belum teman: profil bob tidak terbaca');
select is_empty($$select 1 from public.catches where user_id = '22222222-2222-2222-2222-222222222222'$$, 'belum teman: catch bob tidak terbaca');
select is_empty($$select * from public.user_profile('22222222-2222-2222-2222-222222222222')$$, 'belum teman: profil lewat RPC kosong');
select results_eq(
  $$select username, relation from public.find_user('  BOB ')$$,
  $$values ('bob'::text, 'none'::text)$$,
  'cari username persis (huruf besar & spasi dirapikan)'
);
select is_empty($$select * from public.find_user('bo')$$, 'tidak bisa cari pakai awalan');

-- === minta & terima ============================================================
select is(public.send_friend_request('22222222-2222-2222-2222-222222222222'), 'outgoing', 'alice minta berteman');
select is(public.send_friend_request('22222222-2222-2222-2222-222222222222'), 'outgoing', 'minta ulang tidak dobel');
select throws_ok($$select public.send_friend_request('11111111-1111-1111-1111-111111111111')$$, 'FR008', null, 'tidak bisa berteman dengan diri sendiri');
select is_empty($$select 1 from public.catches where user_id = '22222222-2222-2222-2222-222222222222'$$, 'masih menunggu: catch bob belum terbaca');

select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select results_eq(
  $$select username, relation from public.my_friends()$$,
  $$values ('alice'::text, 'incoming'::text)$$,
  'bob melihat permintaan masuk'
);
select throws_ok($$insert into public.friendships (requester_id, addressee_id) values ('22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333')$$,
  '42501', null, 'tabel tidak bisa ditulis langsung');
select is(public.respond_friend_request('11111111-1111-1111-1111-111111111111', true), 'friend', 'bob menerima');

select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select isnt_empty($$select 1 from public.profiles where username = 'bob'$$, 'teman: profil bob terbaca');
select isnt_empty($$select 1 from public.catches where user_id = '22222222-2222-2222-2222-222222222222'$$, 'teman: catch lama bob terbaca');
select ok(public.can_read_catch_photo('22222222-2222-2222-2222-222222222222/bbbbbbbb-0000-0000-0000-000000000001/animal.jpg'), 'teman: foto catch lama bob boleh diunduh');
select is_empty($$select 1 from public.profiles where username = 'carol'$$, 'orang asing tetap tidak terbaca');
select is_empty($$select 1 from public.circle_members where circle_id = 'cccccccc-0000-0000-0000-000000000001' and user_id = '22222222-2222-2222-2222-222222222222'$$, 'berteman tidak memasukkan ke circle');

select results_eq(
  $$select username, streak, animal_count, catch_count, friend_count, relation
    from public.user_profile('22222222-2222-2222-2222-222222222222')$$,
  $$values ('bob'::text, 1, 1, 1, 1, 'friend'::text)$$,
  'profil teman: streak (catch kemarin = masih hidup), hitungan & relasi'
);
select results_eq(
  $$select name, pinned_at is not null from public.user_collection('22222222-2222-2222-2222-222222222222')$$,
  $$values ('Bobcat'::text, true)$$,
  'koleksi teman (termasuk kartu yang dipajang)'
);
select is(
  (select relation from public.user_profile('44444444-4444-4444-4444-444444444444')),
  'none', 'satu circle (bukan teman) tetap bisa dibuka profilnya'
);

-- === feed teman (terkunci sebelum catch) =========================================
reset role;
insert into public.catches (id, user_id, animal_photo_path, selfie_photo_path, catch_date) values
  ('bbbbbbbb-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'a', 'b', public.jakarta_today());
set local role authenticated;
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select results_eq(
  $$select user_id::text, locked from public.friends_feed()$$,
  $$values ('22222222-2222-2222-2222-222222222222'::text, true)$$,
  'feed teman: catch bob hari ini terkunci sebelum alice catch'
);

-- === notifikasi teman ==========================================================
reset role;
set local role service_role;
select results_eq(
  $$select token, actor_name, kind from public.claim_friend_notifications() order by kind desc$$,
  $$values ('tok-bob'::text, 'Alice'::text, 'request'::text), ('tok-alice', 'Bob', 'accepted')$$,
  'notifikasi permintaan & diterima'
);
reset role;

-- === putus ====================================================================
set local role authenticated;
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select lives_ok($$select public.remove_friend('11111111-1111-1111-1111-111111111111')$$, 'bob menghapus pertemanan');
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select is_empty($$select 1 from public.profiles where username = 'bob'$$, 'setelah putus: profil bob tidak terbaca lagi');

select * from finish();
rollback;
