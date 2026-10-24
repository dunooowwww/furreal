-- M10: catch tanpa kunci drop (timing early/on_time/late), token drop tanpa
-- yang sudah catch, dan klaim notifikasi "teman udah catch".
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(16);

-- alice, bob, carol satu circle (kos); dave di circle lain.
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.com'),
  ('33333333-3333-3333-3333-333333333333', 'carol@example.com'),
  ('44444444-4444-4444-4444-444444444444', 'dave@example.com');
update public.profiles set username = 'alice', display_name = 'Alice', fcm_token = 'tok-alice' where id = '11111111-1111-1111-1111-111111111111';
update public.profiles set username = 'bob', display_name = null, fcm_token = 'tok-bob' where id = '22222222-2222-2222-2222-222222222222';
update public.profiles set username = 'carol', fcm_token = 'tok-carol' where id = '33333333-3333-3333-3333-333333333333';
update public.profiles set username = 'dave', fcm_token = 'tok-dave' where id = '44444444-4444-4444-4444-444444444444';

insert into public.circles (id, name, invite_code, created_by) values
  ('cccccccc-0000-0000-0000-000000000001', 'kos', 'KSE234', '11111111-1111-1111-1111-111111111111'),
  ('cccccccc-0000-0000-0000-000000000002', 'lain', 'LNA234', '44444444-4444-4444-4444-444444444444');
insert into public.circle_members (circle_id, user_id) values
  ('cccccccc-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111'),
  ('cccccccc-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222'),
  ('cccccccc-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333'),
  ('cccccccc-0000-0000-0000-000000000002', '44444444-4444-4444-4444-444444444444');

insert into storage.objects (bucket_id, name, owner)
select 'catch-photos', u || '/' || c || '/' || f, u::uuid
from (values
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-0000-0000-0000-000000000001'),
  ('22222222-2222-2222-2222-222222222222', 'bbbbbbbb-0000-0000-0000-000000000001'),
  ('33333333-3333-3333-3333-333333333333', 'eeeeeeee-0000-0000-0000-000000000001')
) as x(u, c), (values ('animal.jpg'), ('selfie.jpg')) as y(f);

delete from public.daily_drops;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
$$;

-- === sebelum drop: alice catch duluan ========================================
set local role authenticated;
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select results_eq(
  $$select timing, is_late from public.create_catch('aaaaaaaa-0000-0000-0000-000000000001', 'Milo', 'pet', null, true)$$,
  $$values ('early'::text, false)$$,
  'drop belum dijadwalkan: catch boleh, ditandai early'
);

-- === drop terjadwal tapi belum turun → token drop tanpa alice ================
reset role;
insert into public.daily_drops (drop_date, scheduled_at) values (public.jakarta_today(), now() + interval '1 hour');
set local role service_role;
select results_eq(
  $$select t from public.fcm_tokens() t order by t$$,
  $$values ('tok-bob'::text), ('tok-carol'), ('tok-dave')$$,
  'notifikasi drop tidak dikirim ke yang sudah catch hari ini'
);
reset role;

-- === drop turun 10 menit lalu: bob tepat waktu ==============================
update public.daily_drops set sent_at = now() - interval '10 minutes';
set local role authenticated;
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select results_eq(
  $$select timing, is_late from public.create_catch('bbbbbbbb-0000-0000-0000-000000000001', 'Pak Kwek', 'wild', null, true)$$,
  $$values ('on_time'::text, false)$$,
  'dalam 1 jam setelah drop → on_time'
);

-- === drop turun 2 jam lalu: carol telat =====================================
reset role;
update public.daily_drops set sent_at = now() - interval '2 hours';
set local role authenticated;
select pg_temp.as_user('33333333-3333-3333-3333-333333333333');
select results_eq(
  $$select timing, is_late from public.create_catch('eeeeeeee-0000-0000-0000-000000000001', 'Cici', 'wild', null, true)$$,
  $$values ('late'::text, true)$$,
  'lewat 1 jam → late (is_late ikut true)'
);
select results_eq(
  $$select username, timing from public.circle_feed('cccccccc-0000-0000-0000-000000000001') order by username$$,
  $$values ('alice'::text, 'early'::text), ('bob', 'on_time'), ('carol', 'late')$$,
  'feed menyertakan label waktu'
);
select throws_ok(
  $$update public.catches set timing = 'on_time' where user_id = auth.uid()$$,
  '42501', null,
  'timing tidak bisa diubah user'
);
select throws_ok(
  $$update public.catches set notified_at = null where user_id = auth.uid()$$,
  '42501', null,
  'notified_at tidak bisa diubah user'
);
select throws_ok(
  $$select * from public.claim_catch_notification('eeeeeeee-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333')$$,
  '42501', null,
  'claim_catch_notification hanya untuk service role'
);

-- === notifikasi "teman udah catch" ===========================================
reset role;
-- dave belum catch tapi beda circle; bob & carol sudah catch.
update public.profiles set fcm_token = null where id = '33333333-3333-3333-3333-333333333333';
set local role service_role;
select results_eq(
  $$select sender_name, token, recipient_caught
    from public.claim_catch_notification('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111')
    order by token$$,
  $$values ('Alice'::text, 'tok-bob'::text, true)$$,
  'penerima = anggota circle lain yang punya token (bukan pemilik, bukan circle lain)'
);
select is(
  (select count(*)::int from public.claim_catch_notification('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111')),
  0,
  'satu catch hanya bisa dikabarkan sekali'
);
select is(
  (select count(*)::int from public.claim_catch_notification('bbbbbbbb-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111')),
  0,
  'tidak bisa mengklaim catch milik orang lain'
);
select is(
  (select notified_at from public.catches where id = 'bbbbbbbb-0000-0000-0000-000000000001'),
  null,
  'klaim yang ditolak tidak menandai catch'
);
reset role;
update public.profiles set fcm_token = 'tok-carol' where id = '33333333-3333-3333-3333-333333333333';
-- carol belum catch → recipient_caught false; nama pakai username kalau display_name kosong.
delete from public.catches where id = 'eeeeeeee-0000-0000-0000-000000000001';
set local role service_role;
select results_eq(
  $$select sender_name, token, recipient_caught
    from public.claim_catch_notification('bbbbbbbb-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222')
    order by token$$,
  $$values ('bob'::text, 'tok-alice'::text, true), ('bob', 'tok-carol', false)$$,
  'penerima yang belum catch ditandai (copy notif beda)'
);
reset role;

-- catch kemarin tidak bisa dikabarkan lagi.
insert into public.catches (id, user_id, animal_photo_path, selfie_photo_path, catch_date)
values ('ffffffff-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'x', 'y', public.jakarta_today() - 1);
set local role service_role;
select is(
  (select count(*)::int from public.claim_catch_notification('ffffffff-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333')),
  0,
  'catch hari lain tidak dikabarkan'
);
reset role;

-- data lama: timing diisi dari is_late oleh migrasi (kolom default on_time).
select is(
  (select timing from public.catches where id = 'ffffffff-0000-0000-0000-000000000001'),
  'on_time',
  'default timing on_time'
);
select hasnt_function('public', 'create_catch', array['uuid', 'text', 'text', 'text', 'boolean'],
  'versi create_catch lama tidak tersisa');

select * from finish();
rollback;
