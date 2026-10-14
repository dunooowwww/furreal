# furreal — PRD untuk Implementasi (Claude Code)

> Dokumen ini adalah spesifikasi teknis untuk membangun MVP furreal.
> Baca bagian yang relevan dengan milestone yang sedang dikerjakan saja.
> Versi produk: PRD v0.9 · Diperbarui: 14 Okt 2026

---

## 1. Ringkasan produk

furreal adalah aplikasi Android untuk mengoleksi hewan dan peliharaan dengan ritme harian ala BeReal:
setiap hari satu notifikasi, dua foto real-time (foto hewan + foto lo/selfie reaksi), dan satu kartu hewan
bernama yang dibagikan ke circle teman. Koleksi berpusat pada **individu hewan** ("Milo"), bukan spesies.

**Target MVP:** 2–3 circle kampus (15–30 orang), uji 14 hari lewat Google Play closed testing.

## 2. Stack

| Lapisan | Teknologi |
|---|---|
| Aplikasi | Flutter (Dart), Android saja untuk MVP |
| Auth | Supabase Auth: kode OTP 6 digit lewat email. Google Sign-In ditunda (lihat catatan di §4) |
| Database | Supabase Postgres + Row Level Security (RLS) |
| Storage | Supabase Storage, bucket private `catch-photos` |
| Server logic | Supabase Edge Functions (TypeScript/Deno) |
| AI | Lewat satu adapter di Edge Function (`supabase/functions/_shared/ai/`), provider dipilih dari env: `mock` (default dev), `anthropic` (Claude API, `claude-haiku-5-5`), atau `openai_compatible` (mis. Sumopod, model wajib mendukung gambar). Dipanggil HANYA dari Edge Function |
| Notifikasi | Firebase Cloud Messaging (FCM HTTP v1) |
| Jadwal | `pg_cron` di Supabase yang memanggil Edge Function |
| Metrik & crash | Firebase Analytics + Crashlytics |
| Migrasi DB | Supabase CLI (`supabase/migrations/*.sql`) |

**Paket Flutter:** `supabase_flutter`, `camera`, `firebase_core`, `firebase_messaging`,
`firebase_analytics`, `firebase_crashlytics`, `geolocator`, `geocoding`, `go_router`,
`flutter_riverpod`, `google_fonts`, `cached_network_image`, `flutter_image_compress` (kompres foto, ditambahkan v0.4).
Jangan tambah paket lain tanpa alasan yang jelas.

## 3. Struktur repo

```
furreal/
├── CLAUDE.md
├── docs/
│   ├── PRD.md          ← dokumen ini
│   └── PLAN.md         ← dibuat di M0
├── app/                ← proyek Flutter
│   └── lib/
│       ├── main.dart
│       ├── app/        ← router, theme, konfigurasi
│       ├── features/   ← auth, circles, camera, catch_result, feed, collection
│       └── shared/     ← widget & util bersama
└── supabase/
    ├── config.toml
    ├── migrations/
    ├── functions/
    │   ├── identify-animal/
    │   └── send-daily-drop/
    └── tests/          ← test RLS (pgTAP)
```

## 4. Layar

Mockup referensi: canvas "Catch UI" (nama lama, isinya prototype furreal) (5 layar). Layar 0 belum dimockup, buat sederhana.

> **Catatan auth (v0.3):** MVP memakai kode OTP 6 digit lewat email (bukan magic link) supaya bisa dites
> di lokal lewat Mailpit dan tidak butuh deep link. Google Sign-In ditunda; kode auth disusun per
> metode login sehingga Google bisa ditambahkan tanpa mengubah alur lain.

| # | Layar | Isi utama |
|---|---|---|
| 0a | Login | Isi email → isi kode OTP 6 digit yang dikirim ke email. Google Sign-In ditunda |
| 0a' | Username | Setelah login pertama: pilih username (unik) + nama tampilan |
| 0a'' | Pedoman | Sekali per akun, setelah username dan sebelum circle: pedoman kesejahteraan hewan (jangan kejar, pegang, pancing/ganggu; izin ke pemilik peliharaan), tombol "gue janji" → `profiles.guidelines_accepted_at` lewat RPC `accept_guidelines()` |
| 0b | Circle | Buat circle (dapat kode undangan 6 karakter) atau gabung via kode. User boleh ikut beberapa circle; minimal satu untuk masuk beranda |
| 1 | Beranda | Logo, streak, kartu izin notifikasi (penjelasan dulu, baru dialog sistem; muncul setelah onboarding kalau izin belum ada), kartu "daily drop": belum turun (kamera dikunci) / sisa waktu tepat-waktu (hitung mundur 1 jam) / telat, status circle hari ini ("x dari y udah catch"), tangkapan kemarin, tab bar. Tarik ke bawah untuk cek drop lagi |
| 2 | Kamera | Hanya bisa dibuka setelah daily drop hari ini turun. Gelap, full screen, sisa waktu tepat-waktu (atau "telat") di bawah header. 2 langkah berurutan: "1/2 · foto hewan" (default kamera belakang) lalu "2/2 · foto lo" (selfie/reaksi, default kamera depan). Tombol ganti kamera di tiap langkah, jadi kamera mana pun boleh untuk foto mana pun. Tanpa akses galeri. Izin kamera ditolak → layar penjelasan + tombol buka pengaturan |
| 3 | Hasil tangkapan | Kartu foto + jenis hewan + kartu kepribadian AI, input nama, pilihan "hewan baru / ketemu lagi", label area, tombol posting |
| 4 | Feed circle | Header "feed" + pilihan circle (kalau ikut >1 circle) + "hari ini · x dari y udah catch". Banner "lo belum catch hari ini" + tombol kamera (feed tetap terlihat); sebelum drop turun banner berganti "daily drop belum turun" tanpa tombol. Kartu catch anggota circle hari ini (Asia/Jakarta), terbaru dulu: avatar & nama, waktu relatif, label tepat waktu/telat, foto hewan + selfie kecil, nama, jenis, "first catch"/"ketemu ke-Nx", kartu kepribadian. Reaksi suka & lucu (toggle optimistis), komentar di bottom sheet (maks 300, hapus milik sendiri). Pull-to-refresh, tanpa realtime |
| 5 | Koleksi | Statistik (hewan, jenis, streak), filter semua/peliharaan/liar, grid 2 kolom kartu hewan (foto terakhir, nama, jenis, "ketemu Nx"), tap → detail (pertemuan, pertama ditemui, kartu kepribadian terakhir). Rarity/musim/kartu terkunci di luar MVP |
| 6 | Akun | Dari ikon di header beranda: nama & @username, kebijakan privasi, keluar, hapus akun (wajib ketik username, lalu kembali ke login). Kebijakan privasi juga bisa dibuka dari layar login |

### Design tokens (dari mockup)
- Warna: background `#FFFFFF`, ink `#111111`, aksen `#D4FF3A`, surface `#EEEEEE`, teks sekunder `#555555`
- Font: Bricolage Grotesque (display, 700–800), Geist (body), Geist Mono (meta/label kecil)
- Bentuk: kartu radius 28, tombol pill, border 1.5px `#111111`, tanpa bayangan dan gradien
- Copy: bahasa Indonesia santai, huruf kecil ("waktunya catch!", "galeri dikunci")
- Touch target minimal 44px, kontras teks minimal 4.5:1

## 5. Model data

Semua tabel di schema `public`, RLS **wajib aktif** di semua tabel.

```sql
profiles        (id uuid PK → auth.users, username text unique, display_name text,
                 avatar_url text, fcm_token text, created_at timestamptz)
circles         (id uuid PK, name text, invite_code text unique, created_by uuid → profiles,
                 created_at timestamptz)
circle_members  (circle_id uuid → circles, user_id uuid → profiles, joined_at timestamptz,
                 PK (circle_id, user_id))
animals         (id uuid PK, owner_id uuid → profiles, name text, kind text check in ('pet','wild'),
                 animal_type text, encounter_count int default 1, first_seen_at timestamptz,
                 last_seen_at timestamptz)
catches         (id uuid PK, user_id uuid → profiles, animal_id uuid → animals,
                 animal_photo_path text, selfie_photo_path text,
                 ai_type text, ai_confidence numeric, ai_candidates jsonb, ai_personality text,
                 personality text,                      -- kartu kepribadian final (bisa diedit user)
                 area_label text, location_hidden bool default false,
                 is_late bool, catch_date date, created_at timestamptz,
                 UNIQUE (user_id, catch_date))          -- satu catch per user per hari
reactions       (catch_id uuid → catches, user_id uuid → profiles,
                 type text check in ('like','laugh'), created_at timestamptz,
                 PK (catch_id, user_id, type))
comments        (id uuid PK, catch_id uuid → catches, user_id uuid → profiles,
                 body text check (length(body) <= 300), created_at timestamptz)
streaks         (user_id uuid PK → profiles, current int, longest int, last_catch_date date)
daily_drops     (drop_date date PK, scheduled_at timestamptz,   -- jam acak, rahasia dari user
                 sent_at timestamptz)                         -- null = belum turun
```

- **Tanggal catch** memakai zona waktu `Asia/Jakarta`.
- **Lokasi:** JANGAN simpan koordinat. App mengubah lokasi menjadi label area (contoh: "sekitar Depok, Sleman") di HP, lalu hanya `area_label` yang dikirim.
- **Streak** diperbarui oleh trigger Postgres saat insert `catches`: +1 kalau `last_catch_date` = kemarin, tetap kalau hari yang sama, reset ke 1 kalau terlewat; catch bertanggal lampau diabaikan; `longest` ikut naik. Saat ditampilkan (`my_streak()`), streak yang `last_catch_date`-nya lebih lama dari kemarin dianggap 0.
- **Kunci daily drop (v0.8):** catch hanya bisa dibuat setelah daily drop hari ini turun (`daily_drops.sent_at` terisi); sebelum itu `create_catch` menolak dengan error `FR005` dan app mengunci tombol kamera.
- **is_late** dihitung di server: `true` kalau `created_at` > `daily_drops.sent_at` + 1 jam.
- **Token FCM:** satu token per profil, disimpan lewat RPC `set_fcm_token(token)` (null saat keluar). Token yang sama dilepas dari akun lain (satu HP = satu akun). `fcm_token` tetap tidak bisa dibaca atau diubah langsung lewat API.
- **Ketemu lagi:** user memilih `animal_id` yang sudah ada miliknya (`create_catch(..., p_animal_id)`) → `encounter_count` (= jumlah catch hewan itu) dan `last_seen_at` dihitung trigger, bukan dari app. Catch hanya boleh terhubung ke hewan milik pemilik catch (trigger, error `FR004`). Nama & peliharaan/liar mengikuti hewan lama.

### Aturan RLS (wajib dites)
- `profiles`: user membaca profil sendiri dan profil anggota circle yang sama; hanya bisa mengubah milik sendiri (`fcm_token` hanya lewat `set_fcm_token`).
- `daily_drops`: user hanya membaca drop yang sudah turun, kolom `drop_date` & `sent_at` saja (jam jadwal tidak bocor); tidak bisa menulis.
- `circles` / `circle_members`: hanya anggota yang bisa membaca. Gabung lewat fungsi RPC `join_circle(invite_code)`.
- `animals`, `catches`: pemilik bisa CRUD miliknya (catch + hewan baru dibuat atomik lewat RPC `create_catch`; kolom hasil server seperti `catch_date`, `is_late`, `user_id` tidak bisa diubah user); anggota circle yang sama hanya bisa membaca.
- `reactions`, `comments`: bisa dibuat dan dibaca jika user berbagi circle dengan pemilik catch; hanya bisa menghapus milik sendiri.
- Storage `catch-photos`: path `{user_id}/{catch_id}/animal.jpg` dan `selfie.jpg`. Upload hanya ke folder sendiri; baca hanya jika berbagi circle. Akses lewat signed URL.
- Buat helper SQL `shares_circle(a uuid, b uuid) returns boolean` untuk dipakai di semua policy.
- Feed lewat RPC `circle_feed(circle_id)` (security invoker, RLS tetap berlaku) dan komentar lewat `catch_comments(catch_id)`. Helper `can_see_catch(catch_id)` dipakai policy reaksi & komentar.
- **Data development:** `supabase/scripts/seed_dev_feed.ts` membuat user contoh, satu circle, dan catch hari ini (dengan foto, reaksi, komentar) di Supabase lokal saja.

## 6. Edge Functions

### 6.1 `identify-animal`
- **Input:** `POST { "catch_id": uuid }` dengan JWT user. Foto hewan `{user_id}/{catch_id}/animal.jpg` sudah di-upload; baris `catches` belum dibuat (dibuat saat posting). Hanya foto hewan yang dikirim ke AI, tidak pernah selfie.
- **Proses:** cek JWT & path milik user → cek batas harian → unduh foto hewan dengan service role → kirim ke provider AI lewat adapter → validasi JSON → simpan di tabel server `ai_identifications` → kembalikan hasil. Saat posting, RPC `create_catch` menyalin hasil AI terakhir untuk catch itu ke kolom `catches.ai_*` (jadi `ai_*` selalu hasil asli AI, tidak bisa diisi dari app).
- **Output:**
  ```json
  {
    "animal_type": "kucing" | null,
    "confidence": 0.94,
    "candidates": ["kucing", "musang"],
    "personality": "si penjaga parkiran. hobi: tidur di jok motor orang."
  }
  ```
- **Aturan prompt ke model:**
  - Jawab HANYA JSON valid sesuai skema di atas.
  - `animal_type` berupa jenis umum dalam bahasa Indonesia (kucing, anjing, ayam, burung, cicak, dll.). Jika tidak ada hewan → `null`.
  - `personality` maksimal 2 kalimat, lucu, ramah, bahasa Indonesia santai, huruf kecil.
  - Jangan menyebut, menebak, atau mendeskripsikan identitas manusia di foto.
  - Jangan memberi saran medis atau kesehatan hewan.
- **Batasan:** timeout 15 detik, maksimal 5 panggilan per user per hari (zona Asia/Jakarta, hanya untuk provider asli; mode `mock` tanpa batas), `AI_API_KEY` hanya dari secrets Supabase.
- **Adapter & env:** `AI_PROVIDER` (`mock` | `anthropic` | `openai_compatible`, default `mock`), `AI_BASE_URL`, `AI_MODEL`, `AI_API_KEY`. Ganti provider cukup lewat env, tanpa ubah kode.
  - `mock`: tanpa API; hasil tiruan bergiliran (kucing, ayam, burung) lengkap dengan kartu kepribadian, delay ~1,5 detik.
  - `anthropic`: Claude Messages API, default model `claude-haiku-5-5`, base URL default `https://api.anthropic.com`; JSON dipaksa lewat structured outputs.
  - `openai_compatible`: endpoint `{AI_BASE_URL}/chat/completions` format OpenAI (mis. Sumopod); `AI_BASE_URL` (biasanya diakhiri `/v1`) dan `AI_MODEL` wajib; model harus menerima input gambar.
- **Error:** `{ "error": { "code", "message" } }` dengan kode `unauthorized`, `bad_request`, `rate_limited`, `photo_not_found`, `timeout`, `invalid_ai_response`, `ai_unavailable`, `ai_not_configured`.
- Kalau gagal: kembalikan error yang jelas; app tetap bisa lanjut dengan input jenis manual.
- **Hasil akhir user:** jenis yang dipilih/dikoreksi user disimpan di `animals.animal_type`; kartu kepribadian yang bisa diedit user disimpan di `catches.personality` (yang tampil di feed). `catches.ai_*` tetap hasil asli AI.

### 6.2 `send-daily-drop`
Edge Function tidak bisa menunggu berjam-jam, jadi jadwal dipegang database (v0.8):
- **09:55 WIB** — `pg_cron` menjalankan `schedule_daily_drop()`: pilih jam acak 10:00–20:00 WIB (sama untuk semua user) ke `daily_drops.scheduled_at`. Kalau terlewat, jam dipilih dari sisa jendela (lewat 20:00 → sekarang).
- **Tiap menit** — `pg_cron` menjalankan `dispatch_daily_drop()`: kalau jadwal hari ini sudah lewat dan `sent_at` masih kosong, panggil `send-daily-drop` lewat `pg_net` dengan `Authorization: Bearer <secret>`. URL dan secret dibaca dari Supabase Vault (`daily_drop_url`, `daily_drop_secret`). Kalau gagal, menit berikutnya dicoba lagi.
- **`send-daily-drop`** (`verify_jwt = false`, dicek dengan `DAILY_DROP_SECRET`): `claim_daily_drop()` mengisi `sent_at` secara atomik (drop turun, catch terbuka; panggilan ganda → `skipped`), lalu kirim FCM HTTP v1 "waktunya catch!" ke semua token lewat channel Android `daily_drop` (prioritas tinggi, TTL 12 jam, data `type=daily_drop`). Token OAuth dibuat dari service account dengan WebCrypto (tanpa SDK).
- Token tidak valid (`UNREGISTERED`, `SENDER_ID_MISMATCH`, 404, atau 400 soal registration token) dihapus lewat `clear_fcm_tokens`; error lain dibiarkan.
- Kalau `FCM_SERVICE_ACCOUNT_JSON` kosong, drop tetap turun tanpa notifikasi.
- **App:** notifikasi saat app terbuka → snackbar + muat ulang drop; ketuk notifikasi / app dibuka lagi → muat ulang drop.

## 7. Milestone & kriteria selesai

Kerjakan **satu milestone per sesi**. Setiap milestone selesai = test lulus + `flutter analyze` bersih.

| # | Milestone | Selesai jika |
|---|---|---|
| M0 | Scaffold | Struktur repo sesuai §3, `docs/PLAN.md`, app Flutter kosong jalan di emulator, Supabase lokal jalan |
| M1 | Auth & circle | Login kode OTP email (bisa dites lokal lewat Mailpit), profil dibuat otomatis + pilih username, buat & gabung circle via kode, RLS test lulus |
| M2 | Kamera & catch | Foto hewan lalu foto lo (bisa ganti kamera), tanpa galeri, upload ke storage, baris `catches` tersimpan, satu catch per hari ditegakkan |
| M3 | AI | `identify-animal` jalan dengan respons di-mock di test; layar Hasil tangkapan menampilkan jenis, kandidat, dan kartu kepribadian |
| M4 | Feed | Feed circle hari ini, label tepat waktu/telat, reaksi & komentar, hanya anggota circle yang bisa melihat |
| M5 | Koleksi & streak | Grid koleksi + filter, "ketemu lagi" menambah `encounter_count`, streak terupdate via trigger |
| M6 | Notifikasi & metrik | `send-daily-drop` terjadwal, notifikasi sampai di HP, catch dikunci sampai drop turun, event Analytics: `catch_created`, `reaction_added`, `circle_joined` + Crashlytics |
| M7 | Siap rilis | Halaman kebijakan privasi, hapus akun + data dari app, onboarding pedoman kesejahteraan hewan, build AAB untuk closed testing |

## 8. Kebutuhan non-fungsional

- **Keaslian:** catch hanya dari kamera dalam app; tidak ada akses galeri untuk catch.
- **Privasi:** tanpa koordinat; foto lo (selfie) hanya terlihat anggota circle; tidak ada mode publik.
- **Kesejahteraan hewan:** layar onboarding berisi pedoman: jangan kejar, pegang, atau ganggu hewan demi foto.
- **Performa:** kompres foto ke lebar maksimal 1280px, JPEG kualitas ~80 sebelum upload.
- **Keamanan:** tidak ada secret di kode app; anon key Supabase boleh di app, service role key TIDAK pernah.
- **Hapus akun:** menghapus profil, catches, animals, komentar, reaksi, dan file storage milik user. Lewat Edge Function `delete-account` (JWT user): foto dihapus dulu via Storage API (`account_photo_paths`), lalu `auth.admin.deleteUser` → semua tabel ikut terhapus lewat FK cascade; circle tanpa anggota ikut dihapus. Permintaan lewat email (tanpa app): `supabase/scripts/admin_delete_account.ts`.

## 9. Di luar cakupan MVP

Rarity spesies, pengenalan otomatis individu hewan, leaderboard, peta, event musiman, mode publik, iOS, monetisasi.

## 10. Environment & secrets

| Nama | Di mana | Keterangan |
|---|---|---|
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | `app/` via `--dart-define` | Boleh di app |
| `SUPABASE_SERVICE_ROLE_KEY` | Secrets Edge Function | Jangan pernah di app atau repo |
| `AI_PROVIDER`, `AI_BASE_URL`, `AI_MODEL` | Secrets/env Edge Function | Pilih provider AI; default `mock` |
| `AI_API_KEY` | Secrets Edge Function | Key provider AI (Anthropic/Sumopod/dll.). Jangan pernah di app atau repo |
| `FCM_SERVICE_ACCOUNT_JSON` | Secrets Edge Function | Jangan pernah di app atau repo |
| `DAILY_DROP_SECRET` | Secrets Edge Function + Vault `daily_drop_secret` | Bearer pg_cron → `send-daily-drop`; nilai acak panjang di produksi |
| Vault `daily_drop_url` | Database (Vault) | `https://<project>.supabase.co/functions/v1/send-daily-drop`; lokal diisi `supabase/seed.sql` |
| `google-services.json` | `app/android/app/` | Masuk `.gitignore` |

Sediakan `.env.example` tanpa nilai asli.

## 11. Testing

- **RLS:** pgTAP di `supabase/tests/`, jalankan `supabase test db`. Wajib ada test "user di luar circle tidak bisa membaca catch".
- **Edge Functions:** test Deno dengan respons AI (provider `mock` atau `fetch` palsu) dan FCM di-mock; jangan pernah memanggil API asli di test.
- **Data development daily drop:** `supabase/scripts/seed_dev_drop.ts` menurunkan drop hari ini sekarang (lewat jalur asli dispatch → function), menguncinya lagi (`--lock`), atau menampilkan status (`--status`).
- **Flutter:** widget test untuk alur kamera → hasil tangkapan → posting, dan untuk koleksi.
