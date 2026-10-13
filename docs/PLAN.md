# furreal — Rencana Kerja

Satu milestone per sesi (lihat `docs/PRD.md` §7). Centang setelah test lulus + `flutter analyze` bersih.

## Status

- [ ] **M0 — Scaffold** — kode selesai; `flutter analyze` & `flutter test` lulus. Belum terverifikasi: app di emulator, `supabase start`, `supabase test db` (lihat catatan M0).
- [ ] **M1 — Auth & circle** — kode selesai; `flutter analyze` bersih, `flutter test` 12/12, pgTAP 26/26 (di Postgres 16 lokal dengan tiruan skema auth). Belum terverifikasi: `npx supabase test db` di stack Supabase asli, dan login OTP end-to-end lewat Mailpit (lihat catatan M1).
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
- **Belum terverifikasi di sesi cloud:** Android SDK (dl.google.com) dan image Docker Supabase (ghcr.io / public.ecr.aws) diblokir kebijakan jaringan, jadi `flutter run` di emulator, `supabase start`, dan `supabase test db` perlu dijalankan di mesin lokal. Centang M0 setelah ketiganya jalan.

### M1 (13 Okt 2026)
- **Login:** kode OTP 6 digit lewat email (`signInWithOtp` + `verifyOTP(type: email)`), bukan magic link, jadi tidak butuh deep link dan bisa dites lewat Mailpit. PRD diperbarui ke v0.3.
- **Google Sign-In ditunda.** Titik sambungnya: `AuthMethod.google` + `AuthRepository.signInWithGoogle()` (sekarang melempar `UnsupportedError`) + `enabledAuthMethodsProvider`. Untuk mengaktifkan: tambah paket `google_sign_in` (minta izin dulu, di luar PRD §2), implementasikan via `signInWithIdToken`, lalu tambahkan `AuthMethod.google` ke provider. Layar login sudah merender tombolnya kalau metodenya aktif.
- **Template email:** `supabase/templates/{magic_link,confirmation}.html` menampilkan `{{ .Token }}`; `otp_expiry` = 600 detik (10 menit). Untuk produksi, template yang sama perlu dipasang di dashboard Supabase.
- **Onboarding:** login → pilih username (+ nama tampilan) → buat/gabung circle → beranda. Diatur oleh `sessionStatusProvider` (`app/session.dart`) + `redirectFor` di router.
- **Username:** `profiles.username` null sampai dipilih; format `^[a-z0-9_.]{3,20}$` (sama di DB dan app). Nama tampilan 1–40 karakter.
- **Circle:** user boleh ikut beberapa circle; minimal satu untuk masuk beranda. Nama maks 40 karakter. Belum ada batas anggota dan fitur keluar circle.
- **Kode undangan:** 6 karakter dari `ABCDEFGHJKLMNPQRSTUVWXYZ2-9` (tanpa 0/O/1/I), acak dari `gen_random_uuid()`. `join_circle` tidak peka huruf besar/kecil dan idempoten.
- **RLS & hak akses:**
  - Tulis ke `circles`/`circle_members` hanya lewat RPC `create_circle(p_name)` dan `join_circle(invite_code)` (security definer).
  - `profiles` tidak bisa di-insert/delete dari API; profil dibuat trigger `on_auth_user_created`.
  - Hak baca `profiles` per kolom: `fcm_token` tidak bisa dibaca lewat API (supaya tidak bocor ke anggota circle). Konsekuensinya, query ke `profiles` wajib menyebut kolom, jangan `select('*')`.
  - Helper `shares_circle(a, b)` dan `is_circle_member(circle_id)` dipakai di policy.
- **Font:** file statis Bricolage Grotesque (700/800), Geist (400/500/600), Geist Mono (400/500) di-bundle di `app/assets/google_fonts/` (+ lisensi OFL, terdaftar di `LicenseRegistry`). `allowRuntimeFetching = false`. `google_fonts` dikunci ke ^8 karena v9 memakai paket `material_ui` yang `TextTheme`-nya tidak kompatibel dengan `flutter/material`.
- **Test:** widget test pakai fake repository (`test/helpers/fakes.dart`); unit test untuk `redirectFor`. Supabase client hanya disentuh lewat `supabaseClientProvider`.
- **Verifikasi di sesi cloud:** image Docker Supabase masih diblokir, jadi pgTAP dijalankan di Postgres 16 + pgTAP dari apt dengan tiruan minimal `auth.users`, `auth.uid()`, dan role `anon`/`authenticated`. Hasilnya lulus, tapi tetap perlu `npx supabase test db` di stack asli (Postgres 17 + skema auth lengkap).
