-- Tindak lanjut audit (7 Nov 2026).
--
-- 1. Migrasi audit 20261027090000 bertanggal lebih tua dari M12–M15. Di
--    database yang sudah menerima M12 (create_catch 9 argumen), migrasi itu
--    baru terpasang belakangan (`db push --include-all`) dan membuat ulang
--    create_catch versi 8 argumen (tanpa caption) sebagai overload kedua,
--    dengan hak EXECUTE default ke PUBLIC. Buang overload itu. Di database
--    yang dipasang berurutan, overload ini sudah tidak ada (no-op).
-- 2. Fungsi trigger tidak perlu bisa dipanggil siapa pun (trigger tetap
--    jalan; hak EXECUTE hanya dicek saat CREATE TRIGGER).

drop function if exists public.create_catch(uuid, text, text, text, boolean, text, text, uuid);

revoke execute on function public.delete_empty_circle() from public, anon, authenticated;
revoke execute on function public.ensure_catch_animal_owner() from public, anon, authenticated;
revoke execute on function public.refresh_animal_encounters() from public, anon, authenticated;
revoke execute on function public.update_streak_on_catch() from public, anon, authenticated;
