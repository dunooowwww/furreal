-- M14: antrean notifikasi reaksi/komentar + pengingat streak 20:00 WIB.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(15);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.com'),
  ('33333333-3333-3333-3333-333333333333', 'carol@example.com');
update public.profiles set username = 'alice', display_name = 'Alice', fcm_token = 'tok-alice' where id = '11111111-1111-1111-1111-111111111111';
update public.profiles set username = 'bob', display_name = null, fcm_token = 'tok-bob' where id = '22222222-2222-2222-2222-222222222222';
update public.profiles set username = 'carol', display_name = 'Carol', fcm_token = null where id = '33333333-3333-3333-3333-333333333333';

insert into public.circles (id, name, invite_code, created_by) values
  ('cccccccc-0000-0000-0000-000000000001', 'kos', 'KSE234', '11111111-1111-1111-1111-111111111111');
insert into public.circle_members (circle_id, user_id) values
  ('cccccccc-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111'),
  ('cccccccc-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222'),
  ('cccccccc-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333');

insert into public.animals (id, owner_id, name, kind) values
  ('dddddddd-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Milo', 'pet');
-- alice catch hari ini; carol catch hari ini (tanpa token).
insert into public.catches (id, user_id, animal_id, animal_photo_path, selfie_photo_path, catch_date) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'dddddddd-0000-0000-0000-000000000001', 'x', 'y', public.jakarta_today()),
  ('eeeeeeee-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333',
   null, 'x', 'y', public.jakarta_today());

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
$$;

-- seed.sql (supabase db reset) mengisi Vault; test ini butuh Vault kosong.
delete from vault.secrets where name in ('daily_drop_url', 'daily_drop_secret');

select is(public.dispatch_activity_notifications(), null, 'tanpa antrean, dispatch tidak memanggil apa pun');

-- === carol bereaksi & komentar di catch alice (lewat API) =====================
set local role authenticated;
select pg_temp.as_user('33333333-3333-3333-3333-333333333333');
insert into public.reactions (catch_id, type) values ('aaaaaaaa-0000-0000-0000-000000000001', 'like');
delete from public.reactions where catch_id = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into public.reactions (catch_id, type) values ('aaaaaaaa-0000-0000-0000-000000000001', 'like');
insert into public.reactions (catch_id, type) values ('aaaaaaaa-0000-0000-0000-000000000001', 'laugh');
insert into public.comments (catch_id, body) values ('aaaaaaaa-0000-0000-0000-000000000001', 'lucu bgt');

select throws_ok(
  $$select * from public.activity_notifications$$,
  '42501', null,
  'antrean tidak bisa dibaca lewat API'
);

-- alice bereaksi ke catch sendiri → tidak dikabarkan.
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
insert into public.reactions (catch_id, type) values ('aaaaaaaa-0000-0000-0000-000000000001', 'like');
-- alice komentar di catch carol (carol tanpa token).
insert into public.comments (catch_id, body) values ('eeeeeeee-0000-0000-0000-000000000001', 'mantap');
reset role;

select results_eq(
  $$select recipient_id::text, kind, count(*)::int from public.activity_notifications
    group by 1, 2 order by 1, 2$$,
  $$values
    ('11111111-1111-1111-1111-111111111111'::text, 'comment'::text, 1),
    ('11111111-1111-1111-1111-111111111111', 'reaction', 1),
    ('33333333-3333-3333-3333-333333333333', 'comment', 1)$$,
  'reaksi berulang dari orang yang sama sekali saja; reaksi ke catch sendiri tidak diantre'
);

select is(public.dispatch_activity_notifications(), null, 'tanpa Vault, dispatch tidak memanggil apa pun');
select vault.create_secret('http://kong:8000/functions/v1/send-daily-drop', 'daily_drop_url');
select vault.create_secret('rahasia-test', 'daily_drop_secret');
select isnt(public.dispatch_activity_notifications(), null, 'ada antrean → request pg_net');
select results_eq(
  $$select url, headers->>'Authorization', convert_from(body, 'utf8')::jsonb->>'job'
    from net.http_request_queue order by id desc limit 1$$,
  $$values ('http://kong:8000/functions/v1/send-activity'::text, 'Bearer rahasia-test'::text, 'activity'::text)$$,
  'request ke send-activity membawa Bearer dari Vault'
);

-- === klaim ===================================================================
set local role authenticated;
select throws_ok(
  $$select * from public.claim_activity_notifications()$$,
  '42501', null,
  'user biasa tidak bisa mengklaim antrean'
);
set local role service_role;
select results_eq(
  $$select token, catch_id::text, animal_name, actor_names, reactions, comments, last_comment
    from public.claim_activity_notifications()$$,
  $$values ('tok-alice'::text, 'aaaaaaaa-0000-0000-0000-000000000001'::text, 'Milo'::text,
            array['Carol']::text[], 1, 1, 'Carol: lucu bgt'::text)$$,
  'dikelompokkan per penerima & catch; penerima tanpa token tidak dikirim'
);
select is_empty($$select * from public.claim_activity_notifications()$$, 'antrean hanya diklaim sekali');
reset role;
select is(
  (select count(*)::int from public.activity_notifications where sent_at is null), 0,
  'semua antrean (termasuk tanpa token) ditandai terkirim'
);

-- carol toggle reaksi lagi (sudah pernah dikabarkan) → tidak diantre ulang.
delete from public.reactions where user_id = '33333333-3333-3333-3333-333333333333';
insert into public.reactions (catch_id, user_id, type)
values ('aaaaaaaa-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'like');
select is(public.dispatch_activity_notifications(), null, 'toggle reaksi lagi tidak memicu kabar baru');

-- === pengingat streak ========================================================
-- bob: catch terakhir kemarin, belum hari ini → diingatkan.
-- alice: sudah catch hari ini → tidak.
insert into public.catches (user_id, animal_photo_path, selfie_photo_path, catch_date)
values ('22222222-2222-2222-2222-222222222222', 'x', 'y', public.jakarta_today() - 2),
       ('22222222-2222-2222-2222-222222222222', 'x', 'y', public.jakarta_today() - 1);

select isnt(public.dispatch_streak_reminders(), null, 'pengingat streak memanggil send-activity');
select is(
  (select convert_from(body, 'utf8')::jsonb->>'job' from net.http_request_queue order by id desc limit 1),
  'streak',
  'job streak'
);
set local role service_role;
select results_eq(
  $$select token, streak from public.claim_streak_reminders()$$,
  $$values ('tok-bob'::text, 2)$$,
  'hanya yang streak-nya masih hidup & belum catch hari ini'
);
select is_empty($$select * from public.claim_streak_reminders()$$, 'pengingat sekali per hari');
reset role;

select * from finish();
rollback;
