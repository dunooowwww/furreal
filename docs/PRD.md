# furreal — PRD untuk Implementasi (Claude Code)

> Dokumen ini adalah spesifikasi teknis untuk membangun MVP furreal.
> Baca bagian yang relevan dengan milestone yang sedang dikerjakan saja.
> Versi produk: PRD v0.3 · Diperbarui: 13 Okt 2026

---

## 1. Ringkasan produk

furreal adalah aplikasi Android untuk mengoleksi hewan dan peliharaan dengan ritme harian ala BeReal:
setiap hari satu notifikasi, satu foto real-time (kamera belakang + depan), dan satu kartu hewan
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
| AI | Claude API, model `claude-haiku-5-5`, dipanggil HANYA dari Edge Function |
| Notifikasi | Firebase Cloud Messaging (FCM HTTP v1) |
| Jadwal | `pg_cron` di Supabase yang memanggil Edge Function |
| Metrik & crash | Firebase Analytics + Crashlytics |
| Migrasi DB | Supabase CLI (`supabase/migrations/*.sql`) |

**Paket Flutter:** `supabase_flutter`, `camera`, `firebase_core`, `firebase_messaging`,
`firebase_analytics`, `firebase_crashlytics`, `geolocator`, `geocoding`, `go_router`,
`flutter_riverpod`, `google_fonts`, `cached_network_image`.
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
| 0b | Circle | Buat circle (dapat kode undangan 6 karakter) atau gabung via kode. User boleh ikut beberapa circle; minimal satu untuk masuk beranda |
| 1 | Beranda | Logo, streak, kartu "daily drop" + sisa waktu tepat-waktu, status circle hari ini, tangkapan kemarin, tab bar |
| 2 | Kamera | Viewfinder kamera belakang, ambil foto belakang lalu depan berurutan, tanpa akses galeri |
| 3 | Hasil tangkapan | Kartu foto + jenis hewan + kartu kepribadian AI, input nama, pilihan "hewan baru / ketemu lagi", label area, tombol posting |
| 4 | Feed circle | Kartu catch anggota circle hari ini, label tepat waktu/telat, reaksi suka & lucu, komentar |
| 5 | Koleksi | Statistik (hewan, jenis, streak), filter semua/peliharaan/liar, grid kartu hewan dengan jumlah pertemuan |

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
                 back_photo_path text, front_photo_path text,
                 ai_type text, ai_confidence numeric, ai_candidates jsonb, ai_personality text,
                 area_label text, location_hidden bool default false,
                 is_late bool, catch_date date, created_at timestamptz,
                 UNIQUE (user_id, catch_date))          -- satu catch per user per hari
reactions       (catch_id uuid → catches, user_id uuid → profiles,
                 type text check in ('like','laugh'), created_at timestamptz,
                 PK (catch_id, user_id, type))
comments        (id uuid PK, catch_id uuid → catches, user_id uuid → profiles,
                 body text check (length(body) <= 300), created_at timestamptz)
streaks         (user_id uuid PK → profiles, current int, longest int, last_catch_date date)
daily_drops     (drop_date date PK, sent_at timestamptz)
```

- **Tanggal catch** memakai zona waktu `Asia/Jakarta`.
- **Lokasi:** JANGAN simpan koordinat. App mengubah lokasi menjadi label area (contoh: "sekitar Depok, Sleman") di HP, lalu hanya `area_label` yang dikirim.
- **Streak** diperbarui oleh trigger Postgres saat insert `catches`: +1 kalau `last_catch_date` = kemarin, reset ke 1 kalau terlewat.
- **is_late** dihitung di server: `true` kalau `created_at` > `daily_drops.sent_at` + 1 jam.
- **Ketemu lagi:** user memilih `animal_id` yang sudah ada miliknya → `encounter_count` +1, `last_seen_at` diperbarui (trigger).

### Aturan RLS (wajib dites)
- `profiles`: user membaca profil sendiri dan profil anggota circle yang sama; hanya bisa mengubah milik sendiri.
- `circles` / `circle_members`: hanya anggota yang bisa membaca. Gabung lewat fungsi RPC `join_circle(invite_code)`.
- `animals`, `catches`: pemilik bisa CRUD miliknya; anggota circle yang sama hanya bisa membaca.
- `reactions`, `comments`: bisa dibuat dan dibaca jika user berbagi circle dengan pemilik catch; hanya bisa menghapus milik sendiri.
- Storage `catch-photos`: path `{user_id}/{catch_id}/back.jpg` dan `front.jpg`. Upload hanya ke folder sendiri; baca hanya jika berbagi circle. Akses lewat signed URL.
- Buat helper SQL `shares_circle(a uuid, b uuid) returns boolean` untuk dipakai di semua policy.

## 6. Edge Functions

### 6.1 `identify-animal`
- **Input:** `POST { "catch_id": uuid }` dengan JWT user. Foto belakang sudah ada di storage.
- **Proses:** cek pemilik catch → unduh foto dengan service role → kirim ke Claude (`claude-haiku-5-5`) → validasi JSON → simpan ke kolom `ai_*` → kembalikan hasil.
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
- **Batasan:** timeout 15 detik, maksimal 5 panggilan per user per hari, `ANTHROPIC_API_KEY` hanya dari secrets Supabase.
- Kalau gagal: kembalikan error yang jelas; app tetap bisa lanjut dengan input jenis manual.

### 6.2 `send-daily-drop`
- Dipanggil `pg_cron` setiap hari pukul 09:55 WIB; memilih waktu acak antara 10:00–20:00 WIB yang sama untuk semua user, lalu mengirim notifikasi FCM "waktunya catch!" pada waktu itu dan mengisi `daily_drops`.
- Kredensial FCM (service account JSON) hanya dari secrets Supabase.
- Kirim hanya ke user yang punya `fcm_token`; token tidak valid dihapus.

## 7. Milestone & kriteria selesai

Kerjakan **satu milestone per sesi**. Setiap milestone selesai = test lulus + `flutter analyze` bersih.

| # | Milestone | Selesai jika |
|---|---|---|
| M0 | Scaffold | Struktur repo sesuai §3, `docs/PLAN.md`, app Flutter kosong jalan di emulator, Supabase lokal jalan |
| M1 | Auth & circle | Login kode OTP email (bisa dites lokal lewat Mailpit), profil dibuat otomatis + pilih username, buat & gabung circle via kode, RLS test lulus |
| M2 | Kamera & catch | Foto belakang lalu depan, tanpa galeri, upload ke storage, baris `catches` tersimpan, satu catch per hari ditegakkan |
| M3 | AI | `identify-animal` jalan dengan respons di-mock di test; layar Hasil tangkapan menampilkan jenis, kandidat, dan kartu kepribadian |
| M4 | Feed | Feed circle hari ini, label tepat waktu/telat, reaksi & komentar, hanya anggota circle yang bisa melihat |
| M5 | Koleksi & streak | Grid koleksi + filter, "ketemu lagi" menambah `encounter_count`, streak terupdate via trigger |
| M6 | Notifikasi & metrik | `send-daily-drop` terjadwal, notifikasi sampai di HP, event Analytics: `catch_created`, `reaction_added`, `circle_joined` |
| M7 | Siap rilis | Halaman kebijakan privasi, hapus akun + data dari app, onboarding pedoman kesejahteraan hewan, build AAB untuk closed testing |

## 8. Kebutuhan non-fungsional

- **Keaslian:** catch hanya dari kamera dalam app; tidak ada akses galeri untuk catch.
- **Privasi:** tanpa koordinat; foto depan hanya terlihat anggota circle; tidak ada mode publik.
- **Kesejahteraan hewan:** layar onboarding berisi pedoman: jangan kejar, pegang, atau ganggu hewan demi foto.
- **Performa:** kompres foto ke lebar maksimal 1280px, JPEG kualitas ~80 sebelum upload.
- **Keamanan:** tidak ada secret di kode app; anon key Supabase boleh di app, service role key TIDAK pernah.
- **Hapus akun:** menghapus profil, catches, animals, komentar, reaksi, dan file storage milik user.

## 9. Di luar cakupan MVP

Rarity spesies, pengenalan otomatis individu hewan, leaderboard, peta, event musiman, mode publik, iOS, monetisasi.

## 10. Environment & secrets

| Nama | Di mana | Keterangan |
|---|---|---|
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | `app/` via `--dart-define` | Boleh di app |
| `SUPABASE_SERVICE_ROLE_KEY` | Secrets Edge Function | Jangan pernah di app atau repo |
| `ANTHROPIC_API_KEY` | Secrets Edge Function | Jangan pernah di app atau repo |
| `FCM_SERVICE_ACCOUNT_JSON` | Secrets Edge Function | Jangan pernah di app atau repo |
| `google-services.json` | `app/android/app/` | Masuk `.gitignore` |

Sediakan `.env.example` tanpa nilai asli.

## 11. Testing

- **RLS:** pgTAP di `supabase/tests/`, jalankan `supabase test db`. Wajib ada test "user di luar circle tidak bisa membaca catch".
- **Edge Functions:** test Deno dengan respons Claude dan FCM di-mock.
- **Flutter:** widget test untuk alur kamera → hasil tangkapan → posting, dan untuk koleksi.
