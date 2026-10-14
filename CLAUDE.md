# furreal

Aplikasi Android koleksi hewan & peliharaan dengan ritme harian ala BeReal.
Spesifikasi lengkap: `docs/PRD.md`. Rencana kerja: `docs/PLAN.md`.

## Stack
- `app/`: Flutter (Dart), Android saja
- `supabase/`: Postgres + RLS, Storage, Edge Functions (TypeScript/Deno)
- AI: Claude API (`claude-haiku-5-5`), hanya dipanggil dari Edge Function
- Notifikasi: Firebase Cloud Messaging

## Menjalankan
```bash
npx supabase start                  # Supabase lokal (butuh Docker)
npx supabase db reset               # terapkan migrasi
npx supabase functions serve --env-file supabase/.env   # Edge Functions lokal (AI_PROVIDER=mock default)
cd app && flutter run --dart-define-from-file=.env.local
# data feed contoh (lokal saja): SUPABASE_SERVICE_ROLE_KEY dari `npx supabase status -o env`
SUPABASE_SERVICE_ROLE_KEY=... deno run -A supabase/scripts/seed_dev_feed.ts emailkamu@contoh.com
# catch hari-hari lalu untuk tes streak (lokal saja): --days N, --gap untuk streak putus
SUPABASE_SERVICE_ROLE_KEY=... deno run -A supabase/scripts/seed_dev_streak.ts emailkamu@contoh.com --days 3
# daily drop (lokal saja): turun sekarang (butuh functions serve), --lock untuk mengunci kamera, --status
SUPABASE_SERVICE_ROLE_KEY=... deno run -A supabase/scripts/seed_dev_drop.ts
# Windows dengan package.json di folder home: tambahkan --node-modules-dir=none setelah `deno run -A`
# build rilis: android/key.properties + keystore (lihat docs/RELEASE.md)
cd app && flutter build appbundle --release --dart-define-from-file=.env.prod
```

Daily drop dijadwalkan `pg_cron` (09:55 WIB + dispatch tiap menit) lewat `pg_net` ke `send-daily-drop`.
Catch dikunci sampai drop hari ini turun. Firebase opsional: tanpa `app/android/app/google-services.json`
app jalan tanpa notifikasi/metrik (setup: `docs/PLAN.md` catatan M6).

## Test
```bash
npx supabase test db                # test RLS (pgTAP)
cd app && flutter analyze && flutter test
cd supabase/functions && deno test  # Edge Functions (AI di-mock, tanpa API asli)
```

## Aturan kerja
- Kerjakan SATU milestone dari `docs/PRD.md` §7 per sesi, lalu berhenti dan laporkan.
- Baca hanya bagian PRD yang relevan dengan milestone saat ini.
- Setiap perubahan skema = file migrasi baru di `supabase/migrations/`. Jangan edit migrasi lama.
- RLS wajib aktif di setiap tabel baru, dan wajib ada test-nya.
- Tidak boleh ada secret di kode app atau di repo. Pakai `.env.example` untuk contoh.
- Jangan tambah paket di luar daftar PRD §2 tanpa bertanya dulu.
- Jangan membaca folder `build/`, `.dart_tool/`, `node_modules/`, atau file hasil generate.
- Tanya dulu jika ada keputusan produk yang ambigu.

## Konvensi
- Struktur Flutter per fitur: `lib/features/<fitur>/` (data, state, ui).
- State management: Riverpod. Navigasi: go_router.
- Copy UI dalam bahasa Indonesia santai, huruf kecil.
- Design tokens: lihat `docs/PRD.md` §4.
- Commit kecil per langkah, pesan dalam bahasa Inggris.

## Compact instructions
Saat compact, simpan: milestone yang sedang dikerjakan, file yang diubah, hasil test terakhir.
