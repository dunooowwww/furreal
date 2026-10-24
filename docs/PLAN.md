# furreal — Rencana Kerja

Satu milestone per sesi (lihat `docs/PRD.md` §7). Centang setelah test lulus + `flutter analyze` bersih.

## Status

- [ ] **M0 — Scaffold** — kode selesai; `flutter analyze` & `flutter test` lulus; `supabase start` & `supabase test db` jalan di Docker lokal (14 Okt). Belum terverifikasi: app di emulator (lihat catatan M0).
- [ ] **M1 — Auth & circle** — kode selesai; `flutter analyze` bersih, `flutter test` 12/12, pgTAP 26/26 (di Postgres 16 lokal dengan tiruan skema auth). pgTAP lulus di stack asli (14 Okt). Belum terverifikasi: login OTP end-to-end lewat Mailpit (lihat catatan M1).
- [ ] **M2 — Kamera & catch** — kode selesai; `flutter analyze` bersih, `flutter test` 27/27, pgTAP 57/57 (Postgres 16 lokal dengan tiruan skema auth + storage). pgTAP lulus di stack asli (14 Okt). Belum terverifikasi: alur kamera/upload/lokasi di HP atau emulator (lihat catatan M2).
- [ ] **M3 — AI** — kode selesai; `flutter analyze` bersih, `flutter test` 39/39, `deno test` 28/28, pgTAP 74/74 (Postgres 16 lokal dengan tiruan skema auth + storage). pgTAP, `deno test` & `functions serve` jalan di stack asli (14 Okt). Belum terverifikasi: alur AI di HP/emulator (lihat catatan M3).
- [ ] **M4 — Feed** — kode selesai; `flutter analyze` bersih, `flutter test` 52/52, `deno test` 28/28, pgTAP 106/106 (Postgres 16 lokal dengan tiruan skema auth + storage, termasuk `protect_delete`). pgTAP lulus di stack asli (14 Okt). Belum terverifikasi: skrip seed dan feed di HP/emulator (lihat catatan M4).
- [ ] **M5 — Koleksi & streak** — kode selesai; `flutter analyze` bersih, `flutter test` 63/63, `deno test` 28/28, pgTAP 134/134 (Postgres 16 lokal dengan tiruan skema auth + storage). pgTAP lulus di stack asli (14 Okt). Belum terverifikasi: skrip `seed_dev_streak.ts` dan alur di HP/emulator (lihat catatan M5).
- [ ] **M6 — Notifikasi & metrik** — kode selesai; `flutter analyze` bersih, `flutter test` 82/82, `deno test` 45/45, pgTAP 167/167 di stack Supabase asli (Docker lokal). Cron → `pg_net` → `send-daily-drop` → drop turun sudah terbukti di lokal. Belum terverifikasi: notifikasi sampai di HP, Analytics DebugView & Crashlytics (butuh proyek Firebase + HP; lihat catatan M6).
- [ ] **M7 — Siap rilis** — kode selesai; `flutter analyze` bersih, `flutter test` 92/92, `deno test` 53/53, pgTAP 185/185 di stack asli, hapus akun terbukti end-to-end di lokal, AAB rilis ter-build dengan keystore uji. Belum: keystore asli, email kontak, hosting kebijakan privasi, setup Play Console (lihat `docs/RELEASE.md`).
- [ ] **M8 — Login baru & splash** — kode selesai; `flutter analyze` bersih, `flutter test` 124/124, `deno test` 56/56, pgTAP 233/233 (Postgres 16 lokal dengan tiruan auth + storage + Vault). Belum terverifikasi: daftar/masuk/lupa password di Supabase produksi, masuk dengan Google (butuh setup Google Cloud), build Android dengan ikon & splash baru (lihat catatan M8).
- [ ] **M9 — Pengaturan & feed ala BeReal** — kode selesai; `flutter analyze` bersih, `flutter test` 108/108, `deno test` 56/56, pgTAP 220/220 (Postgres 16 lokal dengan tiruan auth + storage + Vault, `pg_cron` asli, `pg_net` tiruan). Belum terverifikasi: migrasi di Supabase produksi, upload foto profil & kunci feed di HP (lihat catatan M9).
- [ ] **M10 — Daily drop ala BeReal** — kode selesai; `flutter analyze` bersih, `flutter test` 132/132, `deno test` 66/66, pgTAP 249/249 (Postgres 16 lokal dengan tiruan auth + storage + Vault). Belum terverifikasi: notifikasi "teman udah catch" sampai di HP, catch sebelum drop di produksi (lihat catatan M10).

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

### M5 (14 Okt 2026)
- **Streak** (`20261014150000_collection_streaks.sql`):
  - Tabel `streaks` (RLS: baca milik sendiri, tidak bisa ditulis user), diisi trigger `after insert on catches`: kemarin → +1, hari yang sama → tetap, terlewat → 1, `longest` ikut naik.
  - Catch bertanggal lebih lama dari `last_catch_date` (backfill) diabaikan trigger. Untuk itu ada `recompute_streak(user)` (service role saja) yang menghitung ulang dari riwayat, dipakai skrip debug.
  - Menghapus catch tidak menurunkan streak.
  - `my_streak()` mengembalikan `current` 0 kalau `last_catch_date` < kemarin, jadi angka streak yang sudah putus tidak ditampilkan.
  - Migrasi mem-backfill streak & `encounter_count` untuk catch lama.
- **Ketemu lagi:**
  - `create_catch` v3 menerima `p_animal_id`. Nama & peliharaan/liar mengikuti hewan lama; jenis hewan lama hanya diisi kalau masih kosong.
  - Trigger `before insert/update` memastikan `catches.animal_id` milik pemilik catch (`FR004`). Larangan yang sama juga ada di RPC.
  - `encounter_count` = jumlah catch hewan itu, `last_seen_at` = catch terbaru, dihitung ulang oleh trigger saat catch dibuat atau dihapus langsung. Penghapusan berantai (hapus akun) dilewati lewat `pg_trigger_depth()` supaya aman.
  - `encounter_count` tidak bisa diubah dari app (hak update `animals` hanya `name`, `kind`).
  - Konsekuensi: `encounter_count` yang dulu diisi manual (seed M4) sekarang mengikuti jumlah catch; ekspektasi test feed disesuaikan.
- **Hapus catch debug:** hewannya ikut dihapus hanya kalau tidak punya catch lain, jadi hewan "ketemu lagi" tetap dan hitungannya turun lewat trigger.
- **Koleksi:** `my_collection()` (security invoker) mengembalikan hewan milik sendiri + foto & kepribadian dari catch terakhir. Tab "koleksi" berisi statistik (hewan / jenis / hari streak), filter, grid 2 kolom, detail di bottom sheet, dan empty state. "musim 1" & kartu terkunci "???" dari prototype dilewati (rarity di luar MVP, PRD §9).
- **Layar hasil:** pill "hewan baru" / "ketemu lagi". Daftar hewan sendiri diurutkan: jenis sama dengan jenis pilihan/hasil AI dulu, lalu yang terakhir ditemui. Badge foto ikut berubah. Kalau koleksi kosong, muncul pesan.
- **Beranda:** chip streak asli di header; kartu "catch hari ini · beres" dengan nama hewan; kartu "tangkapan kemarin" (foto kecil, nama, jenis, "first catch"/"ketemu ke-Nx", tombol ke koleksi), disembunyikan kalau tidak ada catch kemarin.
- **Foto:** widget foto remote dipindah ke `shared/widgets/remote_photo.dart` (`remotePhotoBuilderProvider`), dipakai feed, koleksi, "ketemu lagi", dan beranda.
- **Layout:** test menangkap dua overflow nyata di lebar 360dp (baris filter → `Wrap`, tinggi kartu grid 230 → 248).
- **Skrip debug** `supabase/scripts/seed_dev_streak.ts` (lokal saja): catch untuk akunmu N hari ke belakang (`--days`, default 3), hewan "Debu" + "ketemu lagi" + satu hewan baru "Kiko", opsi `--gap` untuk streak putus, lalu `recompute_streak`. Helper bersama skrip dev ada di `supabase/scripts/_dev.ts`.

### M6 (14 Okt 2026)
- **Stack asli pertama kali:** Docker lokal sudah jalan, jadi `npx supabase db reset` + `npx supabase test db` dijalankan di Postgres 17 + skema auth/storage asli. Sebelum M6 hasilnya 134/134 lulus, tanpa perubahan.
- **Kunci daily drop (keputusan produk):** catch dikunci sampai daily drop hari ini turun (ala BeReal), bukan bebas kapan saja.
  - Server: `create_catch` v4 menolak dengan `FR005` kalau `sent_at` hari ini kosong. `is_late` = `now() > sent_at + 1 jam`.
  - App: tombol kamera di beranda diganti "kamera dikunci", banner feed jadi "daily drop belum turun".
  - Konsekuensi: kalau dispatch/function mati seharian, tidak ada yang bisa catch. Cron mencoba lagi tiap menit.
  - Test pgTAP lama (02–05) sekarang membuat drop sendiri dan mengosongkan `daily_drops` dulu, karena cron lokal bisa sudah membuat baris hari ini.
- **Jadwal** (`20261014180000_daily_drop.sql`, `pg_cron` + `pg_net`):
  - `schedule_daily_drop()` jam 09:55 WIB (cron `55 2 * * *` UTC) memilih jam acak 10:00–20:00 WIB ke `daily_drops.scheduled_at`. Idempoten. Kalau terlambat, jam diambil dari sisa jendela; lewat 20:00 → sekarang.
  - `dispatch_daily_drop()` tiap menit: menjadwalkan kalau belum ada (jaga-jaga), lalu kalau sudah waktunya dan `sent_at` kosong, `net.http_post` ke URL Vault `daily_drop_url` dengan `Bearer` Vault `daily_drop_secret`.
  - Beda dari PRD lama: jam acak dipilih di database, bukan di function. Function tidak bisa menunggu sampai jamnya, dan memilih di SQL bisa dites pgTAP.
  - `scheduled_at` tidak bisa dibaca user (hak baca per kolom), dan baris yang belum turun tidak terlihat (RLS `sent_at is not null`). Jadi jam drop tidak bocor duluan.
  - Fungsi jadwal/dispatch/klaim hanya untuk service role.
- **Edge Function `send-daily-drop`** (`verify_jwt = false`):
  - Cek `Authorization` dengan `DAILY_DROP_SECRET` (perbandingan waktu-konstan).
  - `claim_daily_drop()` (atomik; panggilan ganda → `skipped`), lalu `fcm_tokens()`, kirim 20 sekaligus, lalu `clear_fcm_tokens()` untuk token mati.
  - FCM HTTP v1 tanpa SDK (`_shared/fcm.ts`): JWT RS256 dari service account lewat WebCrypto. Token OAuth di-cache dan diambil ulang sekali kalau 401.
  - Token dihapus hanya untuk `UNREGISTERED`, `SENDER_ID_MISMATCH`, 404, atau 400 yang menyebut registration token. Bug payload tidak menghapus semua token.
  - Pesan: "waktunya catch!" / "daily drop udah turun. lo punya 1 jam buat catch tepat waktu.", channel `daily_drop`, TTL 12 jam, data `type=daily_drop`.
  - `FCM_SERVICE_ACCOUNT_JSON` kosong/rusak → drop tetap turun, notifikasi dilewati.
- **Token FCM:**
  - Disimpan lewat RPC `set_fcm_token` (update langsung kolom `fcm_token` dicabut) saat login dan saat token diperbarui. Token yang sama dilepas dari akun lain.
  - Dihapus (`null`) saat "keluar", sebelum sign out (`signOutProvider`). Gagal hapus tidak menghalangi keluar.
- **Firebase opsional:**
  - Plugin Gradle `com.google.gms.google-services` 4.5.0 & `com.google.firebase.crashlytics` 3.0.8 hanya dipasang kalau `app/android/app/google-services.json` ada.
  - `initFirebase()` (`app/firebase.dart`) menangkap kegagalan `Firebase.initializeApp()`. Tanpa Firebase, provider push/analytics memakai versi nonaktif, dan app tetap jalan tanpa notifikasi/metrik.
  - Paket: `firebase_core` ^4.15.0, `firebase_messaging` ^16.7.0, `firebase_analytics` ^12.6.0, `firebase_crashlytics` ^5.4.0 (semua dari PRD §2).
- **Android:**
  - Channel `daily_drop` prioritas tinggi dibuat di `MainActivity` (Kotlin, tanpa paket tambahan).
  - Meta-data channel & ikon default FCM; ikon status bar `drawable/ic_notification.xml` (tapak, satu warna).
  - `POST_NOTIFICATIONS` di manifest.
- **Izin notifikasi:**
  - Kartu penjelasan di beranda setelah onboarding (bukan dialog langsung), lalu dialog sistem. Kalau tetap ditolak → tombol "buka pengaturan".
  - "nanti aja" hanya menyembunyikan kartu sampai app dibuka lagi (tanpa `shared_preferences`, di luar PRD §2).
- **App:**
  - Kartu daily drop 3 fase: `DAILY DROP · BELUM TURUN` / `SISA mm:ss` / `TELAT`. Kamera menampilkan sisa waktu atau "telat".
  - Jam berdetak per detik (`clockProvider`) hanya selama fase tepat-waktu; di test di-override tanpa detak.
  - Drop dimuat ulang saat notifikasi masuk (foreground → snackbar), saat notifikasi diketuk, saat app kembali dari background, dan saat beranda ditarik ke bawah.
  - Beranda menampilkan status circle "hari ini · x dari y udah catch" (memakai `feedControllerProvider`).
- **Analytics:**
  - `catch_created` (`encounter` new/again, `timing` on_time/late menurut jam HP), `reaction_added` (`type`, hanya saat reaksi ditambah & tersimpan), `circle_joined` (`method` invite_code/create).
  - Tanpa user id/PII. Collection Analytics tetap aktif di debug (untuk DebugView).
- **Crashlytics:** `FlutterError.onError` + `PlatformDispatcher.onError`. Pengiriman dimatikan di build debug.
- **Skrip dev** `supabase/scripts/seed_dev_drop.ts` (lokal saja):
  - Default: drop turun sekarang lewat jalur asli (dispatch → pg_net → function).
  - `--lock`: kunci sampai 23:59 WIB. `--status`: tampilkan jadwal & waktu turun.
  - Vault lokal diisi `supabase/seed.sql` (`daily_drop_url` lewat container kong, secret dev `local-dev-daily-drop-secret` = `DAILY_DROP_SECRET` di `supabase/.env.example`).
- **Mesin lokal (Windows):**
  - Deno 2.9.7 dipasang via winget.
  - Ada `package.json` di folder home user, jadi Deno mencari `node_modules`. Skrip yang meng-import `npm:` dijalankan dengan `--node-modules-dir=none`.
- **Setup Firebase (manual, belum dilakukan):**
  1. Buat proyek di console.firebase.google.com, tambah app Android `com.dun.furreal`, unduh `google-services.json` ke `app/android/app/` (di-gitignore).
  2. Aktifkan Analytics & Crashlytics di proyek itu.
  3. Project settings → Service accounts → Generate new private key. Isi file JSON-nya (satu baris) ke `FCM_SERVICE_ACCOUNT_JSON` di `supabase/.env` (lokal) atau `npx supabase secrets set` (produksi). Jangan commit.
  4. Uji: `flutter run`, izinkan notifikasi, kunci (`--lock`) lalu turunkan drop (`seed_dev_drop.ts`), lalu notifikasi muncul.
  5. Event Analytics bisa dicek di DebugView: `adb shell setprop debug.firebase.analytics.app com.dun.furreal`.
- **Produksi (M7):**
  - Isi Vault `daily_drop_url` (`https://<ref>.supabase.co/functions/v1/send-daily-drop`) & `daily_drop_secret` (acak panjang).
  - `secrets set DAILY_DROP_SECRET` dengan nilai yang sama.
  - Aktifkan ekstensi `pg_cron` & `pg_net` (migrasi sudah `create extension if not exists`).

### M7 (14 Okt 2026)
- **Branch:** `m7-siap-rilis` dibuat dari `m6-notifikasi` (PR M6 belum di-merge).
- **Pedoman kesejahteraan hewan (keputusan: setelah username, sebelum circle):**
  - Kolom `profiles.guidelines_accepted_at` (bisa dibaca, tidak bisa diubah langsung) + RPC `accept_guidelines()` (waktu server, idempoten).
  - Status sesi baru `needsGuidelines` → `/guidelines`. User lama juga melihatnya sekali.
  - 4 aturan: jangan dikejar, jangan dipegang/digendong, jangan dipancing/diganggu, hormati pemilik peliharaan. Tombol "gue janji".
- **Hapus akun** (`20261015090000_release.sql` + Edge Function `delete-account`, `verify_jwt = true`):
  - Hanya akun pemilik JWT; tidak ada parameter user id.
  - `account_photo_paths(user)` (service role) → foto dihapus per 100 lewat Storage API. Path di luar `{uid}/` → berhenti.
  - Lalu `auth.admin.deleteUser`; semua tabel ikut terhapus lewat FK cascade (sudah ada sejak M1–M6). Trigger `circle_members_delete_empty_circle` menghapus circle yang tidak punya anggota lagi.
  - `storage.objects` tidak punya FK ke `auth.users`: tanpa langkah foto, file akan yatim. Itulah alasan foto dihapus dulu (dan ketahuan saat test lokal).
  - Foto gagal dihapus → akun belum dihapus (bisa dicoba lagi).
  - App: layar akun (ikon di header beranda) → "hapus akun" → bottom sheet, wajib ketik username → function → sesi lokal dibuang → login + snackbar. Tombol "keluar" pindah dari beranda ke layar akun.
  - Terverifikasi end-to-end di lokal: user nyata + 2 foto + circle → 200, foto/user/profil/circle hilang.
  - Permintaan lewat email (Play Console mewajibkan URL hapus akun di luar app): `supabase/scripts/admin_delete_account.ts <email> [--yes]` (lokal/produksi, service role dari env).
- **Kebijakan privasi** (keputusan: teks di app + HTML di repo, hosting nanti):
  - `app/lib/features/account/data/privacy_policy.dart` dan `docs/privacy-policy.html`, isi sama (ubah keduanya bersamaan).
  - Kontak masih `[EMAIL KONTAK]` (keputusan: diisi sendiri sebelum rilis).
  - Bisa dibuka dari layar login (sebelum daftar) dan layar akun. `/privacy` boleh dibuka di tahap sesi mana pun.
  - Teks ini templat buatan AI, bukan nasihat hukum. Baca ulang sebelum dipublikasikan.
- **Signing rilis:**
  - `android/key.properties` + keystore (di-.gitignore), contoh `android/key.properties.example`.
  - Tanpa `key.properties`, build rilis memakai kunci debug + warning (cukup untuk `flutter run --release`, tidak bisa diupload).
  - AAB rilis dites dengan keystore uji sementara di scratchpad (bukan di repo; `key.properties` uji dihapus setelah build).
- **Checklist rilis:** `docs/RELEASE.md` (Supabase produksi, Vault, SMTP sendiri, Firebase, keystore, versionCode, Play Console closed testing, Data safety).
- **Belum:** ikon launcher masih default Flutter (perlu PNG manual, atau paket `flutter_launcher_icons` yang di luar PRD §2).

### M9 (23 Okt 2026)
- **Asal:** feedback tes pertama (pengaturan, kelola circle, daily drop ala BeReal, login & splash). Dibagi dua: M9 dulu (tanpa setup Google Cloud), M8 (login baru + splash) menyusul.
- **Kunci feed ala BeReal (keputusan: bagian BeReal yang ditiru cuma ini):** jam drop acak, kamera terkunci sebelum drop, dan jendela tepat waktu 1 jam tidak berubah.
  - Ditegakkan di server (`20261023090000_settings_feed_lock.sql`), bukan cuma blur di app: catch teman bertanggal hari ini baru terbaca setelah user catch hari ini. Berlaku untuk baris `catches`, foto storage, reaksi, dan komentar (`can_view_catch_content`, `has_caught_today`; `can_see_catch` & `can_read_catch_photo` ikut diganti).
  - `circle_feed` jadi security definer (cek `is_circle_member` sendiri) supaya baris terkunci tetap muncul: nama, foto profil, jam, tepat waktu/telat, kolom `locked`; isi (hewan, foto, kepribadian, hitungan reaksi/komentar) dikosongkan.
  - Catch hari-hari lalu tidak terkunci. Pemilik selalu melihat miliknya (termasuk foto sebelum baris catch dibuat).
  - Sisa kebocoran yang diterima: tabel `animals` teman tetap terbaca (nama hewan + `last_seen_at`), jadi orang yang sengaja query API bisa menebak hewan hari ini. Tidak terlihat di app.
  - Test lama `02_catches_test` diubah: anggota circle yang belum catch sekarang membaca 0 catch/foto hari ini.
- **Foto profil (keputusan: dari galeri):**
  - Paket `image_picker` ^1.2.4 (disetujui user; di luar daftar PRD §2 lama). Android 13+ memakai photo picker sistem, tanpa izin penyimpanan.
  - Dikompres di HP: sisi pendek maks 512px, JPEG 80, EXIF dibuang (`flutter_image_compress`).
  - Bucket private `avatars`, path `{uid}/{uuid}.jpg` (nama baru tiap ganti supaya cache gambar teman tidak basi), maks 1 MB. Kolom baru `profiles.avatar_path` dengan check constraint folder sendiri. Kolom lama `avatar_url` tidak dipakai.
  - Baca: diri sendiri atau satu circle. Komentator dari circle lain tampil inisial (foto tidak terbaca).
  - Foto lama dihapus setelah ganti (gagal hapus tidak menggagalkan; sisanya terhapus saat hapus akun).
  - Hapus akun (`delete-account` dan `admin_delete_account.ts`) ikut menghapus foto profil (`account_avatar_paths`).
  - Ditampilkan lewat widget `UserAvatar` (beranda, pengaturan, feed, komentar, anggota circle); signed URL di-cache ±50 menit (`avatarUrlProvider`).
- **Pengaturan** menggantikan layar akun (`/settings`, dibuka dari foto profil di header beranda): edit profil (`/settings/profile`: foto, nama tampilan, username; validasi sama dengan onboarding), circle lo, kebijakan privasi, keluar, hapus akun.
- **Kelola circle** (`/settings/circles`): per circle kode undangan + salin, anggota (foto, nama, @username; dari `circle_members` + relasi `profiles`), keluar circle (dialog konfirmasi). Keluar dari circle terakhir → status sesi `needsCircle` → layar buat/gabung. Anggota terakhir keluar → circle terhapus (trigger M7). RPC `leave_circle` (error `P0002` kalau bukan anggota).
- **Kebijakan privasi** ditambah poin foto profil (app & `docs/privacy-policy.html`).
- **Lingkungan test (sesi cloud):** pgTAP butuh `pg_cron` (paket `postgresql-16-cron`), tiruan `pg_net` (ekstensi stub) dan tiruan Vault, karena migrasi M6.
- **Manual setelah merge:** `npx supabase db push` (migrasi M9 + bucket `avatars`), lalu `npx supabase functions deploy delete-account`.

### M8 (24 Okt 2026)
- **Dikerjakan setelah M9** (M9 tidak butuh setup Google Cloud).
- **Login (keputusan user: username + password, dan Google):**
  - Daftar = email + password (min 8), diverifikasi sekali lewat kode 6 angka (`verifyOTP` tipe `signup`). Username tetap dipilih di layar "kenalan dulu" setelahnya, supaya username tidak dipesan oleh akun yang belum diverifikasi.
  - Email yang sudah terdaftar: Supabase membalas user tanpa identitas dan tidak mengirim kode → app menyarankan masuk/lupa password.
  - Masuk = "username atau email" + password. Ada `@` → langsung `signInWithPassword`. Tanpa `@` → RPC `resolve_login(username, password)` (`20261024090000_password_login.sql`) memeriksa password dengan `crypt()` dan mengembalikan email **hanya kalau password benar**, lalu app memanggil `signInWithPassword` biasa (rate limit Supabase Auth tetap per IP HP).
  - `resolve_login`: maks 10 gagal per username per 15 menit (`FR006`), tabel `login_attempts` (RLS tanpa grant; dibersihkan > 1 hari). Username tak dikenal / akun Google tanpa password tetap menghitung bcrypt dengan hash palsu supaya waktu jawab tidak membocorkan username.
  - Risiko yang diterima: `resolve_login` bisa dipanggil tanpa login, dan tiap panggilan menghitung bcrypt, jadi spam username acak membebani CPU database. Kalau jadi masalah: pindahkan ke Edge Function dengan rate limit per IP.
  - Email belum diverifikasi saat masuk → kode dikirim ulang, pindah ke langkah kode di layar daftar.
  - Lupa password: `resetPasswordForEmail` → kode 6 angka (template Reset password) → `verifyOTP` tipe `recovery` + `updateUser(password)` dalam satu langkah; user langsung masuk. Jalur ini juga untuk akun lama yang dulu masuk pakai kode (belum punya password).
  - Masuk pakai kode email (OTP) dihapus dari app.
- **Google:** paket `google_sign_in` ^7.2.0 (disetujui user). `GoogleSignIn.instance.initialize(serverClientId: GOOGLE_WEB_CLIENT_ID)` → `authenticate()` → `idToken` → `signInWithIdToken(provider: google)`. Batal pilih akun = diam saja. Tombol muncul hanya kalau `GOOGLE_WEB_CLIENT_ID` diisi di `.env.local/.env.prod`. Akun Google baru masuk alur username → pedoman → circle seperti biasa. Keluar juga memanggil `GoogleSignIn.signOut()` supaya bisa ganti akun.
- **Splash & ikon (tanpa paket baru):** latar aksen `#D4FF3A` + tapak kaki (path sama dengan ikon notifikasi).
  - Native: `launch_background.xml` (PNG `splash_paw` per density), `values-v31` / `values-night-v31` untuk splash screen Android 12+.
  - Flutter: `SplashScreen` ikut latar aksen + tapak + logo.
  - Ikon: adaptif (`mipmap-anydpi-v26`, foreground vektor + monokrom untuk ikon bertema Android 13+) dan PNG `ic_launcher` 48–192px untuk Android lama. PNG dirender dari SVG di sesi cloud.
  - Android SDK tidak tersedia di sesi cloud, jadi resource Android hanya dicek sebagai XML valid; build APK pertama di laptop jadi verifikasinya.
- **Supabase lokal (`config.toml`):** `enable_confirmations = true`, `minimum_password_length = 8`, template `recovery.html`, provider Google (mati secara default, isi `SUPABASE_AUTH_EXTERNAL_GOOGLE_*` di `supabase/.env`).
- **Manual (produksi):**
  1. `npx supabase db push` (migrasi M8).
  2. Dashboard → Authentication → Emails: template **Reset password** pakai `supabase/templates/recovery.html`, subject "kode reset password furreal". Subject **Confirm signup** jadi "kode verifikasi furreal".
  3. Authentication → Sign In / Providers → Email: minimum password length 8, Confirm email nyala.
  4. Google Cloud Console (proyek Firebase yang sama) → APIs & Services:
     - OAuth consent screen: External, nama app furreal, email kontak.
     - Credentials → Create OAuth client ID → **Web application** → catat Client ID + Client Secret.
     - Credentials → Create OAuth client ID → **Android**: package `com.dun.furreal`, SHA-1 dari `cd app/android && ./gradlew signingReport` (varian release/debug yang dipakai build APK). Tambah lagi untuk kunci upload & Play App Signing saat rilis.
  5. Supabase → Authentication → Sign In / Providers → Google: nyalakan, isi Client ID + Secret (Web), nyalakan "Skip nonce checks".
  6. `app/.env.prod`: `GOOGLE_WEB_CLIENT_ID=<client id Web>`, lalu build APK ulang.

### M10 (25 Okt 2026)
- **Asal:** feedback "daily drop dibikin kayak BeReal". Pilihan user: **kamera tidak dikunci** + **notifikasi teman udah catch**. Jendela tepat waktu tetap 1 jam (opsi 2 menit tidak dipilih); jam drop tetap acak 10:00–20:00 WIB.
- **Kamera tidak dikunci** (`20261025090000_bereal_drop.sql`):
  - `create_catch` v5 tidak menolak sebelum drop (`FR005` pensiun, kodenya masih dikenali app untuk versi lama). Kolom baru `catches.timing` (`early` = drop belum turun atau `sent_at` di masa depan, `on_time`, `late`), dihitung server; `is_late` tetap diisi supaya data & test lama konsisten. Data lama di-backfill dari `is_late`.
  - Tidak ada constraint `is_late` ↔ `timing`: insert langsung (seed/test) yang hanya mengisi `is_late` tetap jalan; `seed_dev_feed.ts` sekarang mengisi `timing`.
  - `circle_feed` v3 menyertakan `timing`. App: chip "sebelum drop" (abu-abu), "tepat waktu" (aksen), "telat …"; data tanpa `timing` ikut `is_late`.
  - Analytics `catch_created.timing` sekarang dari server (`early`/`on_time`/`late`), bukan jam HP.
  - Beranda sebelum drop: "catch duluan?" + tombol kamera aktif; feed: banner "daily drop belum turun, tapi lo boleh catch duluan"; kamera: "drop belum turun · catch ditandai sebelum drop".
  - `fcm_tokens()` melewati user yang hari itu sudah catch → yang catch duluan tidak dapat "waktunya catch!".
  - Streak dan kunci feed (M9) tidak berubah: catch sebelum drop tetap menambah streak dan membuka feed.
- **Notifikasi "teman udah catch":**
  - Edge Function baru `notify-catch` (`verify_jwt = true`), dipanggil app setelah posting tanpa ditunggu; gagal tidak membatalkan catch.
  - `claim_catch_notification(catch, user)` (service role) menandai `catches.notified_at` atomik: sekali per catch, hanya catch hari ini milik pemanggil → tidak bisa dipakai spam. Penerima = anggota circle mana pun yang sama dengan pemilik (selain pemilik) yang punya token.
  - Copy per penerima: belum catch → "catch dulu buat lihat hewan temuannya." (feed masih terkunci); sudah → "lihat hewan temuannya di feed.".
  - Channel Android baru `friend_catch` (prioritas default, bisa dimatikan terpisah dari daily drop) di `MainActivity`.
  - App: `PushMessaging.friendCatches`; saat app terbuka → snackbar + "lihat"; diketuk → buka feed; feed dimuat ulang.
  - Belum ada pengaturan untuk mematikan notif ini selain lewat pengaturan channel Android.
- **Manual setelah merge:** `npx supabase db push`, lalu `npx supabase functions deploy notify-catch send-daily-drop` (send-daily-drop tidak berubah kodenya, tapi `fcm_tokens` baru ikut terpakai otomatis; deploy ulang aman), build APK baru.

