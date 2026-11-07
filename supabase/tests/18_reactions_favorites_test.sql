-- M17: reaksi baru di feed + kartu favorit (maks 3).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(12);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.com');
insert into public.circles (id, name, invite_code, created_by) values
  ('cccccccc-0000-0000-0000-000000000001', 'kos', 'KSE234', '11111111-1111-1111-1111-111111111111');
insert into public.circle_members (circle_id, user_id) values
  ('cccccccc-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111'),
  ('cccccccc-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222');
insert into public.animals (id, owner_id, name, kind) values
  ('dddddddd-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'A', 'pet'),
  ('dddddddd-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'B', 'pet'),
  ('dddddddd-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'C', 'pet'),
  ('dddddddd-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'D', 'pet'),
  ('dddddddd-0000-0000-0000-000000000005', '22222222-2222-2222-2222-222222222222', 'E', 'pet');
insert into public.catches (id, user_id, animal_id, animal_photo_path, selfie_photo_path, catch_date) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'dddddddd-0000-0000-0000-000000000001', 'x', 'y', public.jakarta_today()),
  ('bbbbbbbb-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222',
   'dddddddd-0000-0000-0000-000000000005', 'x', 'y', public.jakarta_today());

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
$$;

-- === reaksi baru =============================================================
set local role authenticated;
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select lives_ok(
  $$insert into public.reactions (catch_id, type) values
      ('aaaaaaaa-0000-0000-0000-000000000001', 'cute'),
      ('aaaaaaaa-0000-0000-0000-000000000001', 'fire'),
      ('aaaaaaaa-0000-0000-0000-000000000001', 'like')$$,
  'reaksi cute & fire boleh'
);
select throws_ok(
  $$insert into public.reactions (catch_id, type) values ('aaaaaaaa-0000-0000-0000-000000000001', 'angry')$$,
  '23514', null,
  'jenis reaksi tak dikenal ditolak'
);
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
insert into public.reactions (catch_id, type) values ('aaaaaaaa-0000-0000-0000-000000000001', 'aww');

select results_eq(
  $$select like_count, reaction_counts, my_reactions from public.circle_feed('cccccccc-0000-0000-0000-000000000001')
    where catch_id = 'aaaaaaaa-0000-0000-0000-000000000001'$$,
  $$values (1, '{"aww": 1, "cute": 1, "fire": 1, "like": 1}'::jsonb, array['aww']::text[])$$,
  'feed v5: hitungan per jenis + reaksi saya; kolom lama tetap'
);
select results_eq(
  $$select reaction_counts, my_reactions from public.circle_feed('cccccccc-0000-0000-0000-000000000001')
    where catch_id = 'bbbbbbbb-0000-0000-0000-000000000001'$$,
  $$values ('{}'::jsonb, '{}'::text[])$$,
  'tanpa reaksi → objek & array kosong'
);

-- === kartu favorit ===========================================================
select lives_ok($$select public.set_animal_pinned('dddddddd-0000-0000-0000-000000000001', true)$$, 'pin kartu 1');
select lives_ok($$select public.set_animal_pinned('dddddddd-0000-0000-0000-000000000002', true)$$, 'pin kartu 2');
select lives_ok($$select public.set_animal_pinned('dddddddd-0000-0000-0000-000000000003', true)$$, 'pin kartu 3');
select throws_ok(
  $$select public.set_animal_pinned('dddddddd-0000-0000-0000-000000000004', true)$$,
  'FR007', null, 'maksimal 3 kartu favorit'
);
select lives_ok(
  $$select public.set_animal_pinned('dddddddd-0000-0000-0000-000000000001', true)$$,
  'pin ulang kartu yang sudah dipin tidak dihitung dua kali'
);
select throws_ok(
  $$select public.set_animal_pinned('dddddddd-0000-0000-0000-000000000005', true)$$,
  'P0002', null, 'tidak bisa pin hewan orang lain'
);

-- hapus dari koleksi → lepas dari pajangan, slot kosong lagi
select public.remove_animal('dddddddd-0000-0000-0000-000000000002');
select lives_ok($$select public.set_animal_pinned('dddddddd-0000-0000-0000-000000000004', true)$$,
  'hapus dari koleksi membebaskan slot pajangan');
select results_eq(
  $$select name from public.my_collection() where pinned_at is not null order by name$$,
  $$values ('A'::text), ('C'), ('D')$$,
  'my_collection v4 menandai kartu favorit'
);

select * from finish();
rollback;
