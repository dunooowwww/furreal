# furreal — Rencana Kerja

Satu milestone per sesi (lihat `docs/PRD.md` §7). Centang setelah test lulus + `flutter analyze` bersih.

## Status

- [ ] **M0 — Scaffold** — kode selesai; `flutter analyze` & `flutter test` lulus. Belum terverifikasi: app di emulator, `supabase start`, `supabase test db` (lihat catatan M0).
- [ ] **M1 — Auth & circle** — kode selesai; `flutter analyze` bersih, `flutter test` 12/12, pgTAP 26/26 (di Postgres 16 lokal dengan tiruan skema auth). Belum terverifikasi: `npx supabase test db` di stack Supabase asli, dan login OTP end-to-end lewat Mailpit (lihat catatan M1).
- [ ] **M2 — Kamera & catch** — kode selesai; `flutter analyze` bersih, `flutter test` 27/27, pgTAP 57/57 (Postgres 16 lokal dengan tiruan skema auth + storage). Belum terverifikasi: `npx supabase test db` di stack asli, dan alur kamera/upload/lokasi di HP atau emulator (lihat catatan M2).
- [ ] **M3 — AI** — kode selesai; `flutter analyze` bersih, `flutter test` 39/39, `deno test` 28/28, pgTAP 74/74 (Postgres 16 lokal dengan tiruan skema auth + storage). Belum terverifikasi: `npx supabase test db` & `functions serve` di stack asli, dan alur AI di HP/emulator (lihat catatan M3).
- [ ] **M4 — Feed** — kode selesai; `flutter analyze` bersih, `flutter test` 52/52, `deno test` 28/28, pgTAP 106/106 (Postgres 16 lokal dengan tiruan skema auth + storage, termasuk `protect_delete`). Belum terverifikasi: `npx supabase test db`, skrip seed, dan feed di HP/emulator (lihat catatan M4).
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
- **Terverifikasi di stack Supabase asli (14 Okt):** `create_catch` berhasil membaca `storage.objects` sebagai pemilik fungsi (test `npx supabase test db` user sampai catch tersimpan), jadi risiko selalu `FR002` tidak terjadi.

### M3 (14 Okt 2026)
- **Alur baru:** foto di-upload begitu layar hasil terbuka, lalu `identify-animal` dipanggil dengan `catch_id` (baris `catches` belum ada).
  - Function membaca `{uid}/{catch_id}/animal.jpg` saja, tidak pernah selfie, dan menyimpan hasil di tabel server `ai_identifications`.
  - Saat posting, `create_catch` menyalin hasil AI sukses terbaru (milik user itu) ke `catches.ai_*`. Jadi `ai_*` selalu hasil asli AI, tidak bisa dipalsukan app.
  - Kalau user batal (foto ulang/tutup/back), foto yang sudah ter-upload dihapus di `dispose`.
- **Hasil akhir user (opsi 1a):** `catches.ai_*` = hasil asli AI. Jenis final (chip/koreksi/manual) → `animals.animal_type` (huruf kecil). Kartu kepribadian final yang bisa diedit → kolom baru `catches.personality` (yang nanti tampil di feed, M4).
- **Adapter AI** (`supabase/functions/_shared/ai/`):
  - Satu interface `identify(image)`, provider dipilih dari env `AI_PROVIDER` (`mock` default | `anthropic` | `openai_compatible`), plus `AI_BASE_URL`, `AI_MODEL`, `AI_API_KEY`. Provider di-cache selama env sama.
  - `mock`: bergiliran kucing → ayam → burung, delay 1,5 detik, tanpa API.
  - `anthropic`: `POST {base}/v1/messages`, default `claude-haiku-5-5`, gambar base64, JSON dipaksa lewat `output_config.format` (json_schema), `effort: low`, refusal → `ai_unavailable`.
  - `openai_compatible` (mis. Sumopod): `POST {AI_BASE_URL}/chat/completions` dengan `image_url` data URL. `AI_BASE_URL` (biasanya diakhiri `/v1`) dan `AI_MODEL` wajib; model harus mendukung gambar. Tanpa `response_format` (tidak semua gateway mendukung); JSON diambil dari teks, termasuk dari blok ```json.
  - Pemanggilan pakai `fetch` biasa, tanpa SDK atau paket tambahan. Satu-satunya dependensi function: `npm:@supabase/supabase-js@2.117.2` di `index.ts`.
  - Prompt bersama (`prompt.ts`): jenis umum bahasa Indonesia, kepribadian maks 2 kalimat huruf kecil, larangan menebak manusia & saran medis, abaikan teks di foto.
  - Validator (`validate.ts`): skema PRD §6.1, huruf kecil, confidence persen → 0..1, kandidat ≤5 dengan jawaban utama di depan, kepribadian dipotong ke 2 kalimat / 280 karakter, `animal_type` null → semua kosong. Tidak valid → `invalid_ai_response`.
- **Edge function `identify-animal`:**
  - Handler murni dengan dependensi diinjeksi (`handler.ts`); `index.ts` hanya wiring supabase-js.
  - Alur: JWT → `catch_id` uuid → `claim_ai_call` → unduh foto hewan (service role, maks 5 MB) → AI dengan timeout 15 detik → validasi → simpan.
  - Error `{error: {code, message}}`: `unauthorized` 401, `bad_request` 400, `rate_limited` 429, `photo_not_found` 404, `timeout` 504, `invalid_ai_response`/`ai_unavailable` 502, `ai_not_configured` 500.
- **Batas harian (opsi 2a):** 5 panggilan/user/hari (Asia/Jakarta) untuk provider asli; mode `mock` tanpa batas. Dijaga atomik di `claim_ai_call` (advisory lock per user, error `FR003`). Panggilan yang gagal tetap dihitung.
- **App:**
  - Layar loading gelap "nyimpen fotonya dulu…" lalu "AI lagi ngenalin hewannya…" / "kartu kepribadian lagi ditulis" (prototype).
  - Kartu hasil: jenis + "yakin 94%", "bukan ini?" + chip kandidat + "lainnya" (jenis manual), kartu "kartu kepribadian · ditulis AI" yang bisa diedit (label "· diedit").
  - AI gagal/timeout/jatah habis/tidak ada hewan → pesan ramah + input jenis manual; jenis & kepribadian opsional, posting tetap jalan. Upload gagal → layar "coba lagi"/"foto ulang".
  - Timeout klien 20 detik.
- **Test:** Deno (validator, giliran mock, format request tiap provider dengan `fetch` palsu, handler dengan dependensi palsu) tanpa API asli; widget test alur AI dengan repository palsu; pgTAP untuk akses, batas harian, dan penyalinan hasil AI.

### Perbaikan test storage (14 Okt 2026)
- Supabase Storage asli memasang trigger `storage.protect_delete`: semua `DELETE` langsung ke `storage.objects` lewat SQL ditolak ("Use the Storage API instead"). Test `02`/`03` sempat memakai `DELETE` SQL sehingga gagal di `npx supabase test db`.
- Test sekarang tidak menghapus file storage lewat SQL. Aturan hapus/timpa foto dicek lewat helper `is_own_catch_photo_path` (yang dipakai policy-nya) + cek bahwa policy DELETE memakai helper itu.
- Tiruan lokal (Postgres 16) ikut diberi trigger serupa supaya kasus ini tertangkap di sesi cloud.
- App sudah benar: hapus foto (batal posting, tombol debug) lewat Storage API (`storage.from(...).remove`). Hapus akun di M7 juga harus lewat Storage API, bukan SQL.

### M4 (14 Okt 2026)
- **Skema** (`20261014120000_feed.sql`):
  - `reactions` (PK catch+user+type, `like`/`laugh`) dan `comments` (1–300 karakter setelah trim, tidak bisa diedit). `user_id` default `auth.uid()`.
  - Policy: baca & buat hanya kalau `can_see_catch(catch_id)` (catch sendiri, atau satu circle dengan pemiliknya), dan buat hanya atas nama sendiri; hapus hanya milik sendiri. Pemilik catch pun tidak bisa menghapus komentar orang lain. Reaksi & komentar ikut terhapus bersama catch.
  - `circle_feed(circle_id)`: catch hari ini (Asia/Jakarta) anggota circle, terbaru dulu, dalam satu panggilan (profil, hewan, `encounter_count`, jenis & kepribadian final dengan fallback ke `ai_*`, jumlah reaksi/komentar, reaksi saya, telat berapa menit). Security invoker, jadi RLS tetap berlaku; user non-anggota mendapat hasil kosong.
  - `catch_comments(catch_id)`: komentar + nama penulis. Security definer supaya nama penulis dari circle lain tetap terbaca oleh orang yang memang bisa melihat komentarnya.
- **Multi-circle:** feed per circle dengan pilihan circle di header (dropdown hanya kalau >1 circle; default circle pertama). Satu catch tampil di semua circle pemiliknya. "x dari y" = anggota yang sudah catch hari ini / jumlah anggota circle.
- **Belum catch:** feed tetap terlihat, hanya muncul banner aksen + tombol kamera (tidak dikunci ala BeReal). Catch sendiri ikut tampil.
- **Foto:** signed URL diminta sekali per load (`createSignedUrlsResult`, 1 jam). `cached_network_image` dengan `cacheKey` = path storage, jadi cache tetap kena walau URL berganti. Placeholder saat loading/gagal. Pembangun foto bisa di-override (`feedPhotoBuilderProvider`) untuk test tanpa jaringan.
- **Reaksi:** toggle optimistis di `FeedController` (family per circle), rollback + snackbar "gagal nyimpen reaksi. coba lagi ya." kalau gagal. Insert duplikat (23505) dianggap sukses.
- **Komentar:** bottom sheet; setelah kirim/hapus, daftar dimuat ulang dan hitungan di kartu disamakan. Tombol hapus hanya di komentar sendiri (`is_mine`), dan tetap dijaga RLS.
- **Navigasi:** `ShellRoute` dengan tab bar bawah "beranda" / "feed". Tab "koleksi" menyusul di M5.
- **Seed development:** `supabase/scripts/seed_dev_feed.ts` (Deno + service role, hanya mau jalan ke Supabase lokal).
  - Membuat 4 user contoh (`*@furreal.test`) dan circle "anak kos merpati" (kode `KSM234`), lalu memasukkan akunmu ke circle itu.
  - Meng-upload foto contoh (`supabase/scripts/seed_photos/`, JPEG buatan sendiri), membuat catch hari ini untuk 3 user (1 telat), plus reaksi & komentar. User ke-4 belum catch.
  - Aman dijalankan ulang tiap hari: catch hari ini milik user contoh diganti (foto lama dihapus lewat Storage API).
