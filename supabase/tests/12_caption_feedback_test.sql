-- M12: caption manual (feed) dan saran / laporan bug.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(11);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.com');
update public.profiles set username = 'alice' where id = '11111111-1111-1111-1111-111111111111';
insert into public.circles (id, name, invite_code, created_by) values
  ('cccccccc-0000-0000-0000-000000000001', 'kos', 'KSE234', '11111111-1111-1111-1111-111111111111');
insert into public.circle_members (circle_id, user_id) values
  ('cccccccc-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111');
insert into storage.objects (bucket_id, name, owner)
select 'catch-photos', '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/' || f,
       '11111111-1111-1111-1111-111111111111'
from (values ('animal.jpg'), ('selfie.jpg')) as x(f);
delete from public.daily_drops;

-- === caption =================================================================
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select results_eq(
  $$select caption, personality from public.create_catch(
      'aaaaaaaa-0000-0000-0000-000000000001', 'Milo', 'pet', null, true,
      'kucing', 'bos kos. suka tidur.', null, '  milo lagi nunggu jatah  ')$$,
  $$values ('milo lagi nunggu jatah'::text, 'bos kos. suka tidur.'::text)$$,
  'caption disimpan (dirapikan) terpisah dari kepribadian'
);
select results_eq(
  $$select caption from public.circle_feed('cccccccc-0000-0000-0000-000000000001')$$,
  $$values ('milo lagi nunggu jatah'::text)$$,
  'feed menampilkan caption'
);
select hasnt_function('public', 'create_catch',
  array['uuid', 'text', 'text', 'text', 'boolean', 'text', 'text', 'uuid'],
  'create_catch v5 (tanpa caption) dihapus');
select throws_ok(
  $$update public.catches set caption = 'ubah'$$,
  '42501', null,
  'caption tidak bisa diubah langsung'
);

reset role;
select throws_ok(
  $$insert into public.catches (user_id, animal_photo_path, selfie_photo_path, catch_date, caption)
    values ('11111111-1111-1111-1111-111111111111', 'x', 'y', public.jakarta_today() - 1, repeat('a', 151))$$,
  '23514', null,
  'caption maksimal 150 karakter'
);

-- === saran & laporan bug ======================================================
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select lives_ok(
  $$insert into public.feedback (category, message, app_version)
    values ('feature', 'tambah mode gelap dong', '0.1.0+1')$$,
  'user mengirim saran fitur'
);
select lives_ok(
  $$insert into public.feedback (category, message) values ('bug', 'kamera kadang hitam')$$,
  'user mengirim laporan bug'
);
select throws_ok(
  $$select * from public.feedback$$,
  '42501', null,
  'saran tidak bisa dibaca lewat API (dibaca pengelola di dashboard)'
);
select throws_ok(
  $$insert into public.feedback (user_id, category, message)
    values ('22222222-2222-2222-2222-222222222222', 'bug', 'palsu')$$,
  '42501', null,
  'tidak bisa mengirim atas nama orang lain'
);
select throws_ok(
  $$insert into public.feedback (category, message) values ('lain', 'x')$$,
  '23514', null,
  'kategori hanya feature/bug'
);

reset role;
select results_eq(
  $$select user_id::text, category, message from public.feedback order by category$$,
  $$values ('11111111-1111-1111-1111-111111111111'::text, 'bug'::text, 'kamera kadang hitam'::text),
           ('11111111-1111-1111-1111-111111111111', 'feature', 'tambah mode gelap dong')$$,
  'saran tersimpan dengan user pengirim'
);

select * from finish();
rollback;
