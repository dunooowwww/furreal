-- M3: ai_identifications, claim_ai_call, create_catch menyalin hasil AI.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(17);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.com');

-- === akses dari API =========================================================
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select throws_ok(
  'select id from public.ai_identifications',
  '42501', null,
  'user tidak bisa membaca ai_identifications'
);
select throws_ok(
  $$insert into public.ai_identifications (user_id, catch_id, provider, status, animal_type)
    values ('11111111-1111-1111-1111-111111111111', gen_random_uuid(), 'anthropic', 'ok', 'naga')$$,
  '42501', null,
  'user tidak bisa memalsukan hasil AI'
);
select throws_ok(
  $$select public.claim_ai_call('11111111-1111-1111-1111-111111111111', gen_random_uuid(), 'anthropic', 'm', 5)$$,
  '42501', null,
  'user tidak bisa memanggil claim_ai_call (khusus service role)'
);
reset role;

-- === batas harian (dipanggil Edge Function sebagai service role) ============
set local role service_role;

select lives_ok(
  $$select public.claim_ai_call('11111111-1111-1111-1111-111111111111', gen_random_uuid(), 'anthropic', 'claude-haiku-5-5', 5)
    from generate_series(1, 5)$$,
  '5 panggilan per hari diizinkan'
);
select throws_ok(
  $$select public.claim_ai_call('11111111-1111-1111-1111-111111111111', gen_random_uuid(), 'anthropic', 'claude-haiku-5-5', 5)$$,
  'FR003', 'jatah AI hari ini habis',
  'panggilan ke-6 di hari yang sama ditolak'
);
select lives_ok(
  $$select public.claim_ai_call('22222222-2222-2222-2222-222222222222', gen_random_uuid(), 'anthropic', 'claude-haiku-5-5', 5)$$,
  'batas dihitung per user'
);
select lives_ok(
  $$select public.claim_ai_call('11111111-1111-1111-1111-111111111111', gen_random_uuid(), 'mock', 'mock', null)
    from generate_series(1, 10)$$,
  'mode mock tanpa batas'
);
reset role;

update public.ai_identifications set call_date = public.jakarta_today() - 1
  where user_id = '11111111-1111-1111-1111-111111111111' and provider = 'anthropic';
set local role service_role;
select lives_ok(
  $$select public.claim_ai_call('11111111-1111-1111-1111-111111111111', gen_random_uuid(), 'anthropic', 'claude-haiku-5-5', 5)$$,
  'jatah kemarin tidak dihitung hari ini (mock juga tidak dihitung)'
);
reset role;

-- Hasil AI untuk catch alice: satu gagal, dua sukses (yang terbaru dipakai).
insert into public.ai_identifications
  (user_id, catch_id, provider, model, status, animal_type, confidence, candidates, personality, created_at)
values
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-0000-0000-0000-000000000001', 'mock', 'mock', 'ok',
   'ayam', 0.5, '["ayam"]', 'lama.', now() - interval '2 minutes'),
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-0000-0000-0000-000000000001', 'mock', 'mock', 'ok',
   'kucing', 0.94, '["kucing", "musang"]', 'si penjaga parkiran.', now() - interval '1 minute'),
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-0000-0000-0000-000000000001', 'mock', 'mock', 'error',
   null, null, null, null, now()),
  -- bob mencoba "menitipkan" hasil AI ke catch id alice
  ('22222222-2222-2222-2222-222222222222', 'aaaaaaaa-0000-0000-0000-000000000002', 'mock', 'mock', 'ok',
   'naga', 1, '["naga"]', 'palsu.', now());

-- === create_catch menyalin hasil AI =========================================
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

insert into storage.objects (bucket_id, name) values
  ('catch-photos', '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/animal.jpg'),
  ('catch-photos', '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000001/selfie.jpg');

select lives_ok(
  $$select public.create_catch('aaaaaaaa-0000-0000-0000-000000000001', 'Milo', 'wild', null, true,
    '  Kucing Oren ', '  si penjaga parkiran, versi gue. ')$$,
  'create_catch v2 menerima jenis & kepribadian final'
);

select results_eq(
  $$select ai_type, ai_confidence, ai_candidates, ai_personality, personality from public.catches$$,
  $$values ('kucing'::text, 0.94::numeric, '["kucing", "musang"]'::jsonb,
    'si penjaga parkiran.'::text, 'si penjaga parkiran, versi gue.'::text)$$,
  'ai_* disalin dari hasil AI sukses terbaru; personality = versi user'
);

select is(
  (select animal_type from public.animals),
  'kucing oren',
  'jenis final user disimpan di animals.animal_type (huruf kecil, di-trim)'
);

select throws_ok(
  $$update public.catches set ai_type = 'naga'$$,
  '42501', null,
  'ai_type tidak bisa diubah user'
);
select lives_ok(
  $$update public.catches set personality = 'diedit lagi.'$$,
  'pemilik bisa mengedit kartu kepribadian final'
);

-- tanpa hasil AI (atau hasil AI milik user lain) → ai_* kosong
delete from public.catches;
insert into storage.objects (bucket_id, name) values
  ('catch-photos', '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000002/animal.jpg'),
  ('catch-photos', '11111111-1111-1111-1111-111111111111/aaaaaaaa-0000-0000-0000-000000000002/selfie.jpg');

select lives_ok(
  $$select public.create_catch('aaaaaaaa-0000-0000-0000-000000000002', 'Kiko', 'pet', null, true)$$,
  'panggilan 5 argumen (versi M2) tetap jalan'
);
select results_eq(
  $$select ai_type, personality from public.catches$$,
  $$values (null::text, null::text)$$,
  'hasil AI milik user lain tidak ikut tersalin'
);
select is(
  (select animal_type from public.animals where name = 'Kiko'),
  null,
  'jenis kosong kalau user tidak mengisi'
);

reset role;
select is(
  (select count(*)::int from public.ai_identifications
    where user_id = '11111111-1111-1111-1111-111111111111' and provider = 'anthropic'
      and call_date = public.jakarta_today()),
  1,
  'hanya panggilan provider asli hari ini yang dihitung untuk batas'
);

select * from finish();
rollback;
