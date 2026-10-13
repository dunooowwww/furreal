# furreal — Rencana Kerja

Satu milestone per sesi (lihat `docs/PRD.md` §7). Centang setelah test lulus + `flutter analyze` bersih.

## Status

- [x] **M0 — Scaffold**
- [ ] M1 — Auth & circle
- [ ] M2 — Kamera & catch
- [ ] M3 — AI
- [ ] M4 — Feed
- [ ] M5 — Koleksi & streak
- [ ] M6 — Notifikasi & metrik
- [ ] M7 — Siap rilis

## Catatan keputusan

### M0 (13 Okt 2026)
- **applicationId / namespace Android:** `com.dun.furreal` (`flutter create --org com.dun --project-name furreal --platforms android`).
- **Toolchain saat scaffold:** Flutter 3.47.7 (Dart 3.13.5), Supabase CLI 2.120.0, Postgres 17.
- **Paket M0:** hanya `flutter_riverpod` + `go_router` (dari daftar PRD §2). Paket lain ditambahkan di milestone yang membutuhkannya.
- **Struktur `lib/`:** `app/` (app, router, theme, config), `features/<fitur>/` (auth, circles, camera, catch_result, feed, collection, home), `shared/`.
- **Theme:** warna, radius kartu 28, border 1.5px, tombol pill, tanpa bayangan sudah di `app/theme.dart`. Font (Bricolage Grotesque, Geist, Geist Mono) belum dipasang; akan memakai `google_fonts` saat layar pertama dibangun (M1).
- **Config app:** `SUPABASE_URL` & `SUPABASE_ANON_KEY` dibaca lewat `String.fromEnvironment` (`app/lib/app/config.dart`). Contoh di `app/.env.example`; emulator memakai `10.0.2.2` untuk host.
- **Secrets Edge Function:** contoh di `supabase/.env.example`; nilai asli lewat `supabase secrets set`.
- **Test DB:** `supabase/tests/00_rls_enabled_test.sql` gagal jika ada tabel di schema `public` tanpa RLS. Penjaga untuk semua migrasi berikutnya.
- **Folder Edge Functions** `identify-animal/` dan `send-daily-drop/` masih kosong (`.gitkeep`); diisi di M3 dan M6.
- **Slash command** `/milestone` dipindah ke `.claude/commands/milestone.md`.
