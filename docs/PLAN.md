# furreal — Rencana Kerja

Satu milestone per sesi (lihat `docs/PRD.md` §7). Centang setelah test lulus + `flutter analyze` bersih.

## Status

- [ ] **M0 — Scaffold** — kode selesai; `flutter analyze` & `flutter test` lulus. Belum terverifikasi: app di emulator, `supabase start`, `supabase test db` (lihat catatan M0).
- [ ] **M1 — Auth & circle** — kode selesai; `flutter analyze` bersih, `flutter test` 12/12, pgTAP 26/26 (di Postgres 16 lokal dengan tiruan skema auth). Belum terverifikasi: `npx supabase test db` di stack Supabase asli, dan login OTP end-to-end lewat Mailpit (lihat catatan M1).
- [ ] **M2 — Kamera & catch** — kode selesai; `flutter analyze` bersih, `flutter test` 27/27, pgTAP 57/57 (Postgres 16 lokal dengan tiruan skema auth + storage). Belum terverifikasi: `npx supabase test db` di stack asli, dan alur kamera/upload/lokasi di HP atau emulator (lihat catatan M2).
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

### M2 (13 Okt 2026)
- **Kamera 2 langkah:** "1/2 · foto hewan" (default kamera belakang), lalu "2/2 · foto lo" (default kamera depan). Tombol ganti kamera ada di kedua langkah. Layar gelap mengikuti prototype "Kamera"; label langkah menggantikan timer, yang baru ada di M6. Tanpa akses galeri. Kalau izin ditolak: layar penjelasan + "buka pengaturan" (`Geolocator.openAppSettings`, tanpa paket baru) + "coba lagi". Kamera dibuka ulang saat app kembali dari background.
- **Skema:** kolom langsung bernama `animal_photo_path` / `selfie_photo_path`, karena tabel `catches` baru dibuat di migrasi M2 (`20261013150000_catches.sql`), jadi tidak perlu rename. File storage: `{user_id}/{catch_id}/animal.jpg` & `selfie.jpg`. PRD naik ke v0.4.
- **Simpan catch:** id catch dibuat di HP (`shared/uuid.dart`), foto dikompres, diupload (upsert), lalu RPC `create_catch` membuat hewan baru + catch secara atomik. Kalau RPC gagal, foto yang sudah terupload dihapus lagi.
  - `catch_date` = `jakarta_today()` di server.
  - Satu catch per hari dijaga oleh `unique (user_id, catch_date)` + error `FR001` → "kamu udah catch hari ini. besok lagi ya!".
  - `FR002` muncul kalau kedua foto belum ada di storage.
  - `is_late` = false kalau `daily_drops` hari ini belum ada. Tabel `daily_drops` sudah dibuat (kosong, read-only untuk user); M6 yang mengisinya.
- **Kompres:** `flutter_image_compress` (disetujui; native Android). Sisi pendek diskalakan ke maks 1280 dan JPEG kualitas 80. Rotasi mengikuti EXIF, lalu EXIF dibuang. Kamera dikunci potret (`lockCaptureOrientation`, manifest, `SystemChrome`), jadi sisi pendek = lebar. Resolusi kamera `veryHigh` (~1080p). Kompres tidak bisa jalan di `flutter test`, jadi di test di-mock lewat repository.
- **Hak akses (PRD: pemilik CRUD):**
  - Insert catch/hewan hanya lewat RPC.
  - Pemilik boleh menghapus catch & hewannya, mengubah `area_label`/`location_hidden` catch, dan `name`/`kind` hewan.
  - Kolom hasil server (`catch_date`, `is_late`, `user_id`, path foto, `ai_*`) tidak bisa diubah user.
  - Konsekuensi yang disadari: user bisa hapus lalu catch ulang di hari yang sama.
- **Storage `catch-photos`:** bucket private, JPEG saja, maks 5 MB.
  - Upload/timpa/hapus hanya `{uid}/{uuid}/(animal|selfie).jpg` di folder sendiri.
  - Baca untuk pemilik atau anggota satu circle.
  - Helper: `is_own_catch_photo_path`, `can_read_catch_photo`.
- **Hapus catch hari ini (debug):** tombol di beranda hanya kalau `kDebugMode`. Memakai jalur hapus biasa (foto → catch → hewan), jadi tidak perlu fungsi khusus di database.
- **Lokasi:** izin `ACCESS_COARSE_LOCATION` saja, `LocationAccuracy.low`, timeout 10 detik.
  - Placemark diubah jadi "sekitar {kecamatan}, {kabupaten}" (awalan Kecamatan/Kabupaten/Kota dibuang). Koordinat tidak pernah keluar dari `GeoAreaLocator`.
  - Izin ditolak / GPS mati / geocoder gagal / toggle "sembunyikan" → `area_label` null, `location_hidden` true.
- **Manifest:** tambah `CAMERA`, `ACCESS_COARSE_LOCATION`, `INTERNET` (manifest utama; sebelumnya hanya ada di debug/profile, padahal rilis butuh). `RECORD_AUDIO` & `WRITE_EXTERNAL_STORAGE` bawaan plugin kamera dibuang. Activity dikunci potret.
- **Layar hasil versi M2:** foto hewan + thumbnail selfie, chip "hewan baru", "kasih nama", pilihan peliharaan/liar (menggantikan "hewan baru / ketemu lagi" di prototype; "ketemu lagi" di M5), baris area + toggle sembunyikan, tombol "posting ke circle". Jenis hewan & kartu kepribadian AI di M3.
- **Perlu dicek di stack Supabase asli:** `create_catch` membaca `storage.objects` sebagai pemilik fungsi (`postgres`). Di tiruan lokal `postgres` adalah superuser. Kalau di Supabase asli RLS storage menghalangi `postgres`, `create_catch` akan selalu `FR002`. Test `npx supabase test db` akan menunjukkannya.
