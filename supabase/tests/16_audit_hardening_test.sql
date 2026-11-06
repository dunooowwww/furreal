-- Perbaikan audit (setelah digabung dengan M13): foto catch yang sudah
-- terposting tidak bisa ditimpa, create_catch idempoten untuk p_catch_id yang
-- sama, dan hapus lalu catch ulang tidak mengirim notifikasi teman dua kali.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(19);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.com');
insert into public.circles (id, name, invite_code, created_by) values
  ('cccccccc-0000-0000-0000-000000000001', 'kos', 'KSE234', '11111111-1111-1111-1111-111111111111');
update public.profiles set username = 'alice', display_name = 'Alice' where id = '11111111-1111-1111-1111-111111111111';
update public.profiles set username = 'bob', fcm_token = 'tok-bob' where id = '22222222-2222-2222-2222-222222222222';
insert into public.circle_members (circle_id, user_id) values
  ('cccccccc-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111'),
  ('cccccccc-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222');

-- Foto catch aaaa..01 (akan diposting) dan aaaa..02 (batal, belum diposting).
insert into storage.objects (bucket_id, name, owner)
select 'catch-photos', '11111111-1111-1111-1111-111111111111/' || c || '/' || f,
       '11111111-1111-1111-1111-111111111111'
from (values ('aaaaaaaa-0000-0000-0000-000000000001'), ('aaaaaaaa-0000-0000-0000-000000000002')) as x(c),
     (values ('animal.jpg'), ('selfie.jpg'), ('cutout.png')) as y(f);

delete from public.daily_drops;

create function pg_temp.as_user(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
$$;

-- Jumlah baris foto yang berhasil diubah pemanggil (RLS update storage.objects).
create function pg_temp.touch_photo(p_name text) returns int language plpgsql as $$
declare
  v_count int;
begin
  update storage.objects set metadata = '{"x": 1}'
   where bucket_id = 'catch-photos' and name = p_name;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- === alice posting, lalu posting ulang (balasan pertama hilang) =============
set local role authenticated;
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');

select lives_ok(
  $$select public.create_catch('aaaaaaaa-0000-0000-0000-000000000001', 'Milo', 'pet', null, true)$$,
  'alice posting catch'
);
select results_eq(
  $$select id, timing from public.create_catch('aaaaaaaa-0000-0000-0000-000000000001', 'Milo', 'pet', null, true)$$,
  $$values ('aaaaaaaa-0000-0000-0000-000000000001'::uuid, 'early'::text)$$,
  'posting ulang dengan catch id yang sama mengembalikan catch yang sudah ada'
);
select is(
  (select count(*)::int from public.catches where user_id = auth.uid()),
  1,
  'posting ulang tidak membuat catch kedua'
);
select is(
  (select count(*)::int from public.animals where owner_id = auth.uid()),
  1,
  'posting ulang tidak membuat hewan kedua'
);
select throws_ok(
  $$select public.create_catch('aaaaaaaa-0000-0000-0000-000000000002', 'Kiko', 'wild', null, true)$$,
  'FR001', null,
  'catch dengan id lain di hari yang sama tetap ditolak'
);

-- === foto yang sudah terposting dikunci, foto batal tetap bisa dibuang ======
select ok(
  public.is_posted_catch_photo('11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/animal.jpg'),
  'foto catch yang sudah diposting dikenali'
);
select ok(
  not public.is_posted_catch_photo('11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000002/animal.jpg'),
  'foto catch yang batal diposting tidak terkunci'
);
select is(
  pg_temp.touch_photo('11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/animal.jpg'),
  0,
  'pemilik tidak bisa menimpa foto catch yang sudah diposting'
);
select is(
  pg_temp.touch_photo('11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000002/animal.jpg'),
  1,
  'pemilik masih bisa menimpa foto yang belum diposting'
);

-- potongan hewan (M11) diunggah setelah posting dan boleh diunggah ulang
select ok(
  not public.is_posted_catch_photo('11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/cutout.png'),
  'cutout.png tidak ikut terkunci setelah posting'
);
select is(
  pg_temp.touch_photo('11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/cutout.png'),
  1,
  'pemilik masih bisa menimpa cutout.png catch yang sudah diposting'
);

reset role;

-- DELETE langsung ke storage.objects ditolak Supabase (wajib lewat Storage API),
-- jadi aturan hapus dicek lewat policy-nya.
select ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects' and cmd = 'DELETE'
      and qual like '%is_own_catch_photo_path(name)%'
      and qual not like '%is_posted_catch_photo%'
  ),
  'hapus foto catch sendiri tetap boleh (app menghapus foto saat catch dihapus)'
);
select ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects' and cmd = 'UPDATE'
      and qual like '%NOT is_posted_catch_photo(name)%'
  ),
  'timpa foto catch yang sudah diposting dilarang'
);

-- === notifikasi teman: sekali per user per hari, walau hapus lalu catch ulang
set local role service_role;
select is(
  (select count(*)::int from public.claim_catch_notification(
     'aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111')),
  1,
  'catch pertama alice hari ini mengabari bob'
);
select is(
  (select count(*)::int from public.claim_catch_notification(
     'aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111')),
  0,
  'catch yang sama tidak dikabarkan dua kali'
);
reset role;

set local role authenticated;
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select lives_ok(
  $$delete from public.catches where id = 'aaaaaaaa-0000-0000-0000-000000000001'$$,
  'pemilik bisa menghapus catch-nya'
);
select lives_ok(
  $$select public.create_catch('aaaaaaaa-0000-0000-0000-000000000002', 'Kiko', 'wild', null, true)$$,
  'setelah dihapus, pemilik bisa catch ulang'
);
reset role;

set local role service_role;
select is(
  (select count(*)::int from public.claim_catch_notification(
     'aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111')),
  0,
  'hapus lalu catch ulang tidak mengabari teman lagi hari itu'
);
reset role;
select is(
  (select count(*)::int from public.catch_notification_log
    where user_id = '11111111-1111-1111-1111-111111111111'),
  1,
  'catatan notifikasi tetap ada walau catch-nya dihapus'
);

select * from finish();
rollback;
