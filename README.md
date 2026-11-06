# furreal

**Koleksi hewan & peliharaan dengan ritme harian ala BeReal.**

Setiap hari ada satu "daily drop" di jam acak. Kamu foto hewan yang kamu temui
(kucing kos, ayam tetangga, burung di kabel listrik, atau peliharaan sendiri)
bersama foto reaksi kamu, kasih nama, lalu bagikan ke circle temanmu. Hewan yang
kamu temui jadi koleksi berbentuk kartu bernama: bukan "kucing", tapi **Milo**.

Aplikasi Android (Flutter) dengan backend Supabase. Antarmuka berbahasa Indonesia
santai, huruf kecil.

> Status: MVP untuk uji tertutup (Google Play closed testing) di 2–3 circle
> kampus, 15–30 orang. Spesifikasi lengkap ada di [`docs/PRD.md`](docs/PRD.md),
> catatan keputusan per milestone di [`docs/PLAN.md`](docs/PLAN.md).

---

## Untuk apa aplikasi ini?

Orang sering lewat di depan hewan lucu tanpa memperhatikannya. furreal membuat
kebiasaan kecil: **perhatikan satu hewan setiap hari, lalu ceritakan ke teman.**

- **Koleksi berpusat pada individu hewan.** Kucing oren di parkiran jadi "Milo".
  Ketemu lagi besok? Pilih "ketemu lagi", maka hitungan pertemuannya naik.
- **Ritme harian.** Satu catch per hari. Notifikasi daily drop datang di jam acak
  (10.00–20.00 WIB), dan catch dalam 1 jam pertama ditandai "tepat waktu".
- **Asli, bukan galeri.** Catch hanya dari kamera dalam app. Tidak ada akses galeri
  untuk catch (galeri hanya untuk foto profil), jadi isinya benar-benar hari itu.
- **Privat di circle.** Tidak ada mode publik. Foto hanya terlihat anggota circle
  yang kamu ikuti lewat kode undangan.
- **Hewan dihormati.** Ada pedoman kesejahteraan hewan yang wajib disetujui:
  jangan dikejar, dipegang, atau dipancing demi foto.

---

## Fitur

### Catch harian
- **Kamera dua foto dengan satu ketukan:** foto hewan dan foto kamu (selfie/reaksi).
  Urutannya bisa dipilih: hewan dulu atau kamu dulu.
- **AI mengenali jenis hewan** dan menulis **kartu kepribadian** yang lucu
  (maksimal 2 kalimat). Hasilnya bisa dikoreksi atau ditulis ulang sendiri.
  Hanya foto hewan yang dikirim ke AI, tidak pernah selfie.
- **Nama hewan, peliharaan/liar, "hewan baru" atau "ketemu lagi".**
- **Label area** (misalnya "sekitar Depok, Sleman"). Koordinat tidak pernah
  disimpan, dan label bisa disembunyikan.
- **Caption** singkat (maks 150 karakter) untuk feed.
- **Label waktu dari server:** sebelum drop, tepat waktu, atau telat. Kamera tetap
  bisa dibuka kapan saja.

### Feed circle
- Catch teman hari ini, terbaru dulu, dengan foto hewan, selfie kecil, nama,
  jenis, "first catch" atau "ketemu ke-Nx", dan caption.
- **Feed terkunci ala BeReal:** sebelum kamu sendiri catch, kartu teman hari ini
  tampil terkunci (isinya tidak dikirim server, bukan sekadar diburamkan).
- Reaksi suka dan lucu, komentar (maks 300 karakter), tarik untuk menyegarkan.
- Catch sendiri bisa diedit (nama, caption), dihapus, dan disimpan atau
  dibagikan sebagai gambar (foto hewan + selfie + watermark furreal + tanggal).

### Koleksi
- **Kartu koleksi holo** per hewan, dengan potongan hewan tanpa latar (dipotong
  di HP memakai ML Kit), warna pastel per jenis, dan efek kilau yang bergerak
  mengikuti geseran jari.
- Statistik (jumlah hewan, jenis, streak), filter semua/peliharaan/liar,
  detail hewan, edit kartu (nama, jenis, kepribadian), dan hapus dari koleksi.
- **Riwayat:** semua catch lama milik sendiri, bisa dibagikan atau dihapus.
- **Streak** harian: bertambah kalau catch tiap hari, putus kalau terlewat sehari.

### Circle & akun
- Buat circle (dapat **kode undangan 6 karakter**) atau gabung lewat kode, boleh
  ikut beberapa circle. Tombol "ajak teman" membagikan kode lewat share sheet.
- Daftar dengan email + password (diverifikasi sekali lewat kode 6 digit),
  masuk dengan username atau email, lupa password lewat kode, atau Google Sign-In.
- Pengaturan: foto profil dari galeri, nama tampilan, username, kelola circle,
  kebijakan privasi, kirim saran/laporan bug, keluar, hapus akun (beserta semua
  data dan foto).

### Notifikasi
- "Waktunya catch!" saat daily drop turun (dilewati untuk yang sudah catch).
- "{teman} udah catch!" saat anggota circle posting (maksimal sekali per orang per hari).
- Reaksi dan komentar di catch kamu, serta pengingat streak jam 20.00 WIB
  bagi yang streak-nya masih hidup dan belum catch hari itu.

---

## Cara kerjanya

```
┌────────────┐   foto, RPC, login    ┌──────────────────────────────┐
│ app Flutter│ ────────────────────▶ │ Supabase                     │
│ (Android)  │ ◀──────────────────── │  Postgres + RLS · Storage    │
└─────┬──────┘      feed, kartu      │  Auth · Edge Functions       │
      │                              └──────┬───────────────┬───────┘
      │ notifikasi                          │ pg_cron       │ panggil AI
      ▼                                     ▼               ▼
┌────────────┐   FCM HTTP v1   ┌─────────────────┐   ┌──────────────┐
│ Firebase   │ ◀────────────── │ send-daily-drop │   │ identify-    │
│ Messaging  │                 │ notify-catch    │   │ animal (AI)  │
└────────────┘                 │ send-activity   │   └──────────────┘
                               └─────────────────┘
```

- **Daily drop dijadwalkan database.** `pg_cron` memilih jam acak 10.00–20.00 WIB
  pada 09.55 WIB, lalu tiap menit mengecek dan memanggil Edge Function
  `send-daily-drop` lewat `pg_net`. Jam jadwal tidak bisa dibaca user sebelum drop turun.
- **Keamanan di server, bukan di app.** Semua tabel memakai Row Level Security.
  Kunci feed, satu catch per hari, dan label waktu ditegakkan di Postgres.
- **AI hanya dari Edge Function.** Key AI tidak pernah ada di app. Provider bisa
  diganti lewat env: `mock` (default, tanpa API), `anthropic` (Claude Haiku), atau
  `openai_compatible`. Ada batas 5 panggilan per user per hari untuk provider asli.
- **Foto dikompres di HP** (lebar maks 1280px, JPEG ~80) sebelum di-upload ke bucket
  private, dan diakses lewat signed URL.

### Stack

| Lapisan | Teknologi |
|---|---|
| Aplikasi | Flutter (Dart), Android saja · Riverpod · go_router |
| Auth | Supabase Auth (email + password, kode verifikasi, Google Sign-In) |
| Database | Supabase Postgres + RLS |
| Storage | Supabase Storage (bucket private `catch-photos`, `avatars`) |
| Server logic | Supabase Edge Functions (TypeScript/Deno) |
| AI | Claude API (`claude-haiku-5-5`) lewat adapter di Edge Function |
| Notifikasi | Firebase Cloud Messaging |
| Metrik & crash | Firebase Analytics + Crashlytics (opsional) |
| Potong gambar hewan | ML Kit subject segmentation (di HP) |

### Struktur repo

```
furreal/
├── app/                      Flutter (Android)
│   └── lib/
│       ├── app/              router, tema, konfigurasi, splash
│       ├── features/         auth, circles, camera, catch_result, feed,
│       │                     collection, daily_drop, home, notifications, account
│       └── shared/           widget & util bersama
├── supabase/
│   ├── migrations/           skema + RLS (satu file per perubahan)
│   ├── tests/                test RLS (pgTAP)
│   ├── functions/            identify-animal, send-daily-drop, notify-catch,
│   │                         send-activity, delete-account, _shared
│   └── scripts/              skrip development (data contoh, tes drop, hapus akun)
└── docs/                     PRD, PLAN, RELEASE, kebijakan privasi
```

---

## Menjalankan di lokal

### Kebutuhan
- [Flutter](https://docs.flutter.dev/get-started/install) (Dart ^3.13) dan Android SDK
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (untuk Supabase lokal)
- Node.js (untuk `npx supabase`) dan [Deno](https://deno.com) (untuk skrip dan test fungsi)

### Langkah

```bash
# 1. Supabase lokal (Docker harus nyala)
npx supabase start
npx supabase db reset            # terapkan migrasi + seed
npx supabase status              # catat API URL dan anon key

# 2. Edge Functions lokal (AI_PROVIDER=mock secara default)
cp supabase/.env.example supabase/.env
npx supabase functions serve --env-file supabase/.env

# 3. App
cd app
cp .env.example .env.local       # isi SUPABASE_ANON_KEY
flutter pub get
flutter run --dart-define-from-file=.env.local
```

Catatan `.env.local`:
- Emulator Android mengakses komputer lewat `10.0.2.2`, jadi
  `SUPABASE_URL=http://10.0.2.2:54321`.
- HP asli lewat USB: jalankan `adb reverse tcp:54321 tcp:54321`, lalu pakai
  `SUPABASE_URL=http://127.0.0.1:54321`.
- Kode verifikasi email tertangkap di Mailpit (`http://127.0.0.1:54324`).
- `GOOGLE_WEB_CLIENT_ID` dan `INVITE_LINK` opsional. Kosong = tombol Google
  disembunyikan dan pesan ajakan tanpa tautan unduh.

### Data contoh untuk development (lokal saja)

```bash
# SUPABASE_SERVICE_ROLE_KEY ada di `npx supabase status -o env`
SUPABASE_SERVICE_ROLE_KEY=... deno run -A supabase/scripts/seed_dev_feed.ts emailkamu@contoh.com
SUPABASE_SERVICE_ROLE_KEY=... deno run -A supabase/scripts/seed_dev_streak.ts emailkamu@contoh.com --days 3
SUPABASE_SERVICE_ROLE_KEY=... deno run -A supabase/scripts/seed_dev_drop.ts            # turunkan drop sekarang
SUPABASE_SERVICE_ROLE_KEY=... deno run -A supabase/scripts/seed_dev_drop.ts --lock     # kunci lagi
```

Skrip ini menolak berjalan kalau `SUPABASE_URL` bukan localhost. Di Windows dengan
`package.json` di folder home, tambahkan `--node-modules-dir=none` setelah `deno run -A`.

### Firebase (opsional)

Tanpa `app/android/app/google-services.json`, app tetap jalan tanpa notifikasi dan
metrik. Untuk mengaktifkannya, ikuti "Setup Firebase" di catatan M6 di
[`docs/PLAN.md`](docs/PLAN.md).

---

## Test

```bash
npx supabase test db                      # RLS dan fungsi database (pgTAP)
cd app && flutter analyze && flutter test # aplikasi
cd supabase/functions && deno test        # Edge Functions (AI dan FCM di-mock)
```

Test tidak pernah memanggil API AI atau FCM yang asli.

---

## Rilis

Checklist lengkap (Supabase produksi, Vault, SMTP, Firebase, keystore, Play Console,
Data safety) ada di [`docs/RELEASE.md`](docs/RELEASE.md). Build rilis:

```bash
cd app && flutter build appbundle --release --dart-define-from-file=.env.prod
```

Setelah `git pull`, jalankan `npx supabase db push` untuk menerapkan migrasi baru ke
project produksi, dan deploy ulang Edge Function yang berubah
(`npx supabase functions deploy <nama>`).

---

## Privasi & keamanan

- Tidak menyimpan koordinat, hanya label area yang kasar. Label bisa disembunyikan.
- Foto dan selfie hanya terlihat anggota circle. Tidak ada mode publik.
- Tidak ada secret di kode app atau repo. Hanya anon key Supabase yang boleh ada di
  app. Service role key, key AI, dan service account Firebase hanya di secrets server.
- Hapus akun lewat app menghapus profil, catch, hewan, komentar, reaksi, dan semua
  file foto. Kebijakan privasi ada di [`docs/privacy-policy.html`](docs/privacy-policy.html).

## Di luar cakupan MVP

Rarity spesies, pengenalan otomatis individu hewan, leaderboard, peta, event musiman,
mode publik, iOS, dan monetisasi.

## Berkontribusi

- Satu milestone per sesi, lalu berhenti dan laporkan (lihat [`CLAUDE.md`](CLAUDE.md)).
- Setiap perubahan skema = file migrasi baru di `supabase/migrations/`. Jangan edit migrasi lama.
- RLS wajib aktif di setiap tabel baru, dan wajib ada test-nya.
- Jangan menambah paket di luar daftar PRD §2 tanpa bertanya dulu.
- Commit kecil per langkah, pesan dalam bahasa Inggris.
