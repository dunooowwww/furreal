-- Hanya untuk Supabase lokal (dijalankan `npx supabase db reset`).
-- Produksi: isi Vault lewat SQL editor dengan URL project & secret acak (lihat docs/PLAN.md, M6).

-- Dibaca dispatch_daily_drop() untuk memanggil Edge Function send-daily-drop.
-- Dari container database, API lokal bisa dicapai lewat container kong.
select vault.create_secret(
  'http://supabase_kong_furreal:8000/functions/v1/send-daily-drop',
  'daily_drop_url',
  'URL Edge Function send-daily-drop'
);
-- Nilai dev saja, bukan secret asli. Harus sama dengan DAILY_DROP_SECRET di supabase/.env.
select vault.create_secret(
  'local-dev-daily-drop-secret',
  'daily_drop_secret',
  'Bearer untuk send-daily-drop (sama dengan env DAILY_DROP_SECRET)'
);
