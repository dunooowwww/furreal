---
description: Kerjakan satu milestone furreal dari docs/PRD.md (contoh: /milestone M1)
argument-hint: <M0-M7>
---

Kerjakan milestone **$ARGUMENTS** dari `docs/PRD.md`.

Langkah:
1. Baca `docs/PRD.md` §7 untuk definisi "selesai" milestone $ARGUMENTS, lalu baca HANYA bagian lain yang relevan dengannya (§4 layar, §5 model data, §6 Edge Functions, §8 non-fungsional, §10 secrets, §11 testing).
2. Baca `docs/PLAN.md` jika ada, dan cek `git status` serta `git log -5` untuk tahu progres terakhir.
3. Sebelum menulis kode, tulis rencana singkat (maksimal 8 poin) dan tunggu persetujuan saya.
4. Implementasikan HANYA milestone $ARGUMENTS. Jangan mengerjakan milestone lain.
5. Tulis atau perbarui test, jalankan (`supabase test db`, `flutter analyze`, `flutter test`, sesuai yang relevan), dan perbaiki sampai lulus.
6. Perbarui `docs/PLAN.md`: tandai $ARGUMENTS selesai dan catat keputusan penting.
7. Berhenti dan laporkan:
   - apa yang selesai,
   - file yang berubah,
   - hasil test,
   - perintah atau langkah manual yang perlu saya lakukan (misalnya mengisi secret atau setup Firebase/Supabase),
   - usulan pesan commit.

Aturan:
- Jika ada keputusan produk yang ambigu, tanya dulu.
- Jangan tambah paket di luar PRD §2 tanpa izin.
- Jangan pernah menulis secret asli ke file mana pun.
