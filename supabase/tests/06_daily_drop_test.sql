-- M6: jadwal daily drop, dispatch lewat pg_net, token FCM. (Kunci catch dilepas di M10.)
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(33);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.com'),
  ('33333333-3333-3333-3333-333333333333', 'dave@example.com');

-- Cron lokal mungkin sudah menjadwalkan hari ini; mulai dari kosong.
delete from public.daily_drops;
delete from vault.secrets where name in ('daily_drop_url', 'daily_drop_secret');

-- === jadwal ==================================================================
create temp table drop_window as
select date_trunc('minute', greatest(now(), (public.jakarta_today() + time '10:00') at time zone 'Asia/Jakarta')) as earliest,
       greatest(now(), (public.jakarta_today() + time '20:00') at time zone 'Asia/Jakarta') as latest;

select ok(
  (select public.schedule_daily_drop() between earliest and latest from drop_window),
  'jam drop acak di sisa jendela 10:00–20:00 WIB'
);
select is(
  public.schedule_daily_drop(),
  (select scheduled_at from public.daily_drops where drop_date = public.jakarta_today()),
  'menjadwalkan ulang tidak mengubah jam drop hari ini'
);
select is((select count(*)::int from public.daily_drops), 1, 'satu baris per hari');

select results_eq(
  $$select jobname, schedule from cron.job
    where jobname in ('daily-drop-schedule', 'daily-drop-dispatch') order by jobname$$,
  $$values ('daily-drop-dispatch'::text, '* * * * *'::text), ('daily-drop-schedule', '55 2 * * *')$$,
  'pg_cron: jadwal 09:55 WIB + dispatch tiap menit'
);

-- Belum waktunya: jadwal dimundurkan ke 1 jam lagi.
update public.daily_drops set scheduled_at = now() + interval '1 hour';
select is(public.dispatch_daily_drop(), null, 'dispatch tidak memanggil function sebelum waktunya');
select is(public.claim_daily_drop(), null, 'drop tidak bisa diklaim sebelum waktunya');

-- === user: drop belum turun ==================================================
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select is((select count(*)::int from public.daily_drops), 0, 'drop yang belum turun tidak terlihat user');
select throws_ok(
  'select scheduled_at from public.daily_drops',
  '42501', null,
  'jam drop (scheduled_at) tidak bisa dibaca user'
);
select throws_ok('select public.schedule_daily_drop()', '42501', null, 'user tidak bisa menjadwalkan drop');
select throws_ok('select public.dispatch_daily_drop()', '42501', null, 'user tidak bisa memicu dispatch');
select throws_ok('select public.claim_daily_drop()', '42501', null, 'user tidak bisa mengklaim drop');
select throws_ok(
  $$update public.daily_drops set sent_at = now()$$,
  '42501', null,
  'user tidak bisa menurunkan drop sendiri'
);

insert into storage.objects (bucket_id, name) values
  ('catch-photos', '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/animal.jpg'),
  ('catch-photos', '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/selfie.jpg');

-- M10: kamera tidak dikunci lagi; catch sebelum drop ditandai 'early'
-- (detail di 10_bereal_drop_test). Pakai dave supaya alice bisa catch nanti.
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
insert into storage.objects (bucket_id, name) values
  ('catch-photos', '33333333-3333-3333-3333-333333333333/dddddddd-0000-0000-0000-000000000001/animal.jpg'),
  ('catch-photos', '33333333-3333-3333-3333-333333333333/dddddddd-0000-0000-0000-000000000001/selfie.jpg');
select results_eq(
  $$select timing, is_late from public.create_catch('dddddddd-0000-0000-0000-000000000001', 'Kiko', 'pet', null, true)$$,
  $$values ('early'::text, false)$$,
  'catch sebelum daily drop turun boleh, ditandai early'
);
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

-- === waktunya drop ===========================================================
reset role;
update public.daily_drops set scheduled_at = now() - interval '1 minute';

select is(public.dispatch_daily_drop(), null, 'tanpa Vault, dispatch tidak memanggil apa pun');

select vault.create_secret('http://kong:8000/functions/v1/send-daily-drop', 'daily_drop_url');
select vault.create_secret('rahasia-test', 'daily_drop_secret');

select isnt(public.dispatch_daily_drop(), null, 'dispatch mengantre request pg_net saat waktunya');
select results_eq(
  $$select url, method::text, headers->>'Authorization', convert_from(body, 'utf8')::jsonb->>'drop_date'
    from net.http_request_queue order by id desc limit 1$$,
  $$select 'http://kong:8000/functions/v1/send-daily-drop'::text, 'POST'::text,
           'Bearer rahasia-test'::text, public.jakarta_today()::text$$,
  'request ke send-daily-drop membawa Bearer dari Vault'
);

set local role service_role;
select is(public.claim_daily_drop(), now(), 'service role mengklaim drop hari ini');
select is(public.claim_daily_drop(), null, 'drop hanya bisa diklaim sekali');
reset role;

select is(public.dispatch_daily_drop(), null, 'drop yang sudah terkirim tidak di-dispatch lagi');

-- === user: drop sudah turun ==================================================
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select results_eq(
  'select drop_date, sent_at from public.daily_drops',
  $$select public.jakarta_today(), now()$$,
  'drop yang sudah turun terlihat user'
);
select is(
  (select is_late from public.create_catch('aaaaaaaa-0000-0000-0000-000000000001', 'Milo', 'pet', null, true)),
  false,
  'setelah drop turun, catch bisa diposting tepat waktu'
);

-- === token FCM ===============================================================
select lives_ok($$select public.set_fcm_token('  tok-hp-1 ')$$, 'user menyimpan token FCM lewat RPC');
select throws_ok(
  $$update public.profiles set fcm_token = 'palsu' where id = auth.uid()$$,
  '42501', null,
  'fcm_token tidak bisa diubah langsung'
);
select throws_ok(
  'select fcm_token from public.profiles',
  '42501', null,
  'fcm_token tetap tidak bisa dibaca lewat API'
);
select throws_ok('select public.fcm_tokens()', '42501', null, 'user tidak bisa membaca daftar token');
select throws_ok(
  $$select public.clear_fcm_tokens(array['tok-hp-1'])$$,
  '42501', null,
  'user tidak bisa menghapus token orang lain'
);

-- bob login di HP yang sama tanpa alice keluar dulu.
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select lives_ok($$select public.set_fcm_token('tok-hp-1')$$, 'akun lain di HP yang sama menyimpan token');

reset role;
select results_eq(
  $$select id::text, fcm_token from public.profiles
    where id in ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222') order by id$$,
  $$values ('11111111-1111-1111-1111-111111111111'::text, null::text),
           ('22222222-2222-2222-2222-222222222222', 'tok-hp-1')$$,
  'satu token hanya untuk satu akun (token dilepas dari alice)'
);

set local role anon;
select throws_ok($$select public.set_fcm_token('x')$$, '42501', null, 'anon tidak bisa menyimpan token');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
select lives_ok($$select public.set_fcm_token('tok-hp-2')$$, 'alice menyimpan token HP-nya');
select lives_ok($$select public.set_fcm_token(null)$$, 'keluar → token dihapus');

set local role service_role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
select results_eq($$select t from public.fcm_tokens() t where t like 'tok-%'$$, $$values ('tok-hp-1'::text)$$, 'service role membaca token yang masih ada');
select is(public.clear_fcm_tokens(array['tok-hp-1', 'tidak-ada']), 1, 'token tidak valid dihapus service role');
reset role;

select * from finish();
rollback;
