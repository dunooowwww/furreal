# furreal — Checklist rilis (closed testing Google Play)

Urutan dari nol sampai tester bisa memasang app. Centang yang sudah.
Semua secret (keystore, password, service role key, service account) **tidak pernah** masuk repo.

## 1. Teks & halaman wajib
- [ ] Ganti `[EMAIL KONTAK]` di `app/lib/features/account/data/privacy_policy.dart` (`privacyContactEmail`) dan `docs/privacy-policy.html`.
- [ ] Host `docs/privacy-policy.html` di URL publik (GitHub Pages, Google Sites, Notion, dll). URL ini dipakai Play Console untuk:
  - **Privacy policy**: URL halaman.
  - **Delete account URL**: URL halaman + `#hapus-akun` (permintaan hapus lewat email).
- [ ] Permintaan hapus lewat email: jalankan `supabase/scripts/admin_delete_account.ts <email>` (cek), lalu tambah `--yes` (lihat komentar di skrip). Maksimal 30 hari sesuai kebijakan.

## 2. Supabase produksi
- [ ] Buat project di supabase.com (region Singapore), lalu `npx supabase link --project-ref <ref>`.
- [ ] `npx supabase db push` (semua migrasi; `pg_cron` & `pg_net` dibuat oleh migrasi M6).
- [ ] Deploy function: `npx supabase functions deploy identify-animal send-daily-drop delete-account`.
- [ ] Secrets: `npx supabase secrets set AI_PROVIDER=... AI_MODEL=... AI_API_KEY=... DAILY_DROP_SECRET=<acak-panjang> FCM_SERVICE_ACCOUNT_JSON='<json satu baris>'`.
- [ ] Vault (SQL editor), dengan nilai `DAILY_DROP_SECRET` yang sama:
  ```sql
  select vault.create_secret('https://<ref>.supabase.co/functions/v1/send-daily-drop', 'daily_drop_url');
  select vault.create_secret('<acak-panjang>', 'daily_drop_secret');
  ```
- [ ] Auth → Email templates (butuh SMTP sendiri dulu): pasang isi `supabase/templates/confirmation.html` (Confirm signup, subject "kode verifikasi furreal"), `recovery.html` (Reset password, subject "kode reset password furreal"), dan `magic_link.html` (Magic link). Semua menampilkan `{{ .Token }}`, bukan link.
- [ ] Auth → Sign In / Providers → Email: Confirm email nyala, Email OTP length 6, expiry 600 detik, minimum password length 8.
- [ ] Auth → Sign In / Providers → Google (M8): nyalakan, isi Client ID + Client Secret dari OAuth client "Web application", nyalakan "Skip nonce checks". Langkah Google Cloud ada di catatan M8 `docs/PLAN.md`.
- [ ] Auth → SMTP: pasang SMTP sendiri (mis. Resend/Brevo). SMTP bawaan Supabase dibatasi beberapa email per jam, tidak cukup untuk 15–30 tester.
- [ ] Cek besok paginya: `select * from daily_drops order by drop_date desc limit 3;` → drop terjadwal & terkirim.

## 3. Firebase
- [ ] Ikuti "Setup Firebase" di `docs/PLAN.md` (catatan M6): `google-services.json` di `app/android/app/`, Analytics + Crashlytics aktif, service account → `FCM_SERVICE_ACCOUNT_JSON`.

## 4. Kunci upload (sekali, simpan baik-baik)
```powershell
cd app/android
keytool -genkeypair -v -keystore upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
copy key.properties.example key.properties   # lalu isi password
```
- [ ] Backup `upload-keystore.jks` + password ke password manager. Hilang = harus minta reset upload key di Play Console.
- [ ] Aktifkan **Play App Signing** saat upload pertama (default).

## 5. Build
- [ ] `app/.env.prod` (di-.gitignore) berisi `SUPABASE_URL` & `SUPABASE_ANON_KEY` project produksi, plus `GOOGLE_WEB_CLIENT_ID` (M8).
- [ ] SHA-1 kunci upload **dan** kunci Play App Signing (Play Console → Setup → App signing) didaftarkan sebagai OAuth client Android di Google Cloud, kalau tidak masuk dengan Google gagal di versi Play Store.
- [ ] Naikkan `version` di `app/pubspec.yaml` setiap upload (`0.1.0+1` → `0.1.0+2`; angka setelah `+` = versionCode, wajib naik).
- [ ] `cd app && flutter build appbundle --release --dart-define-from-file=.env.prod`
- [ ] Hasil: `app/build/app/outputs/bundle/release/app-release.aab`.

## 6. Play Console
- [ ] Akun developer (biaya sekali $25). Akun **personal** baru wajib closed testing ≥12 tester selama ≥14 hari sebelum boleh rilis produksi.
- [ ] Buat app: nama "furreal", bahasa default Indonesia, app (bukan game), gratis.
- [ ] Testing → Closed testing → buat track, tambahkan tester (daftar email atau Google Group), upload AAB.
- [ ] App content:
  - Privacy policy: URL dari langkah 1.
  - App access: login wajib. Reviewer tidak bisa menerima OTP ke emailnya sendiri, jadi siapkan akun reviewer dengan inbox yang bisa kamu bagikan (atau jelaskan langkah login di kolom instruksi).
  - Ads: tidak ada iklan.
  - Content rating: isi kuesioner (konten buatan user dalam circle privat, tanpa fitur publik).
  - Target audience: 13+ (bukan untuk anak).
  - Data safety (sesuai kebijakan privasi):

    | Jenis data | Dikumpulkan | Tujuan | Opsional |
    |---|---|---|---|
    | Email address | ya | Account management | tidak |
    | User IDs (username) | ya | App functionality, Account management | tidak |
    | Photos | ya | App functionality | tidak |
    | Approximate location (label area) | ya | App functionality | ya (bisa disembunyikan) |
    | Other user-generated content (komentar, nama hewan) | ya | App functionality | ya |
    | App interactions (Analytics) | ya | Analytics | tidak |
    | Crash logs, Diagnostics | ya | App functionality / Analytics | tidak |
    | Device or other IDs (token FCM) | ya | App functionality (notifikasi) | tidak |

    Data dienkripsi saat dikirim: ya. User bisa minta data dihapus: ya (di app + URL hapus akun). Data tidak "dibagikan" (Supabase, Firebase, penyedia AI = pemroses atas nama kami).
- [ ] Store listing: ikon 512×512, feature graphic 1024×500, minimal 2 screenshot HP, deskripsi singkat & lengkap.

## 7. Belum ada (di luar M7)
- Ikon launcher app masih ikon default Flutter (`app/android/app/src/main/res/mipmap-*`). Ganti manual dengan PNG ikon furreal, atau pakai `flutter_launcher_icons` (paket di luar PRD §2, minta izin dulu).
