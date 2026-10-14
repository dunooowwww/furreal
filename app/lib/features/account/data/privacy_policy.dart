// Kebijakan privasi furreal. Teks yang sama ada di `docs/privacy-policy.html`
// (untuk URL Play Console): ubah keduanya bersamaan.

/// GANTI sebelum rilis: email kontak privasi (juga di Play Console).
const privacyContactEmail = '[EMAIL KONTAK]';

const privacyPolicyUpdated = '14 oktober 2026';

class PolicySection {
  const PolicySection(this.title, this.paragraphs);

  final String title;
  final List<String> paragraphs;
}

const privacyPolicy = <PolicySection>[
  PolicySection('ringkasan', [
    'furreal itu app buat koleksi hewan yang lo temuin tiap hari, dibagi ke '
        'circle teman. kami cuma ngumpulin data yang perlu buat app ini jalan, '
        'tidak menjual data, dan tidak punya mode publik.',
  ]),
  PolicySection('data yang kami kumpulkan', [
    '• email: buat login dengan kode OTP.',
    '• username & nama tampilan: yang dilihat teman circle-mu.',
    '• foto hewan & foto lo (selfie): diambil langsung dari kamera app, tanpa '
        'akses galeri.',
    '• isi catch: nama, jenis, dan kartu kepribadian hewan, peliharaan/liar, '
        'komentar, dan reaksi.',
    '• label area perkiraan (mis. "sekitar Depok, Sleman"). lokasi GPS diubah '
        'jadi label di HP-mu; koordinat tidak pernah dikirim atau disimpan. '
        'label ini bisa disembunyikan per catch.',
    '• token notifikasi: buat ngirim notifikasi daily drop ke HP-mu.',
    '• data pemakaian & crash: event seperti "catch dibuat", "reaksi", '
        '"gabung circle" (Firebase Analytics) dan laporan crash (Firebase '
        'Crashlytics), tanpa email atau username.',
  ]),
  PolicySection('siapa yang bisa melihat', [
    'catch, foto (termasuk selfie), komentar, dan reaksimu hanya bisa dilihat '
        'anggota circle yang sama denganmu. tidak ada profil atau feed publik.',
  ]),
  PolicySection('AI', [
    'foto hewan (bukan selfie) dikirim ke penyedia AI pihak ketiga untuk '
        'menebak jenis hewan dan menulis kartu kepribadian. AI diminta tidak '
        'mengenali atau mendeskripsikan manusia di foto. jenis dan kepribadian '
        'bisa lo ubah sebelum posting.',
  ]),
  PolicySection('pihak ketiga yang memproses data', [
    '• Supabase: database, login, dan penyimpanan foto.',
    '• Google Firebase: notifikasi (Cloud Messaging), Analytics, Crashlytics.',
    '• penyedia AI: identifikasi jenis hewan dari foto hewan.',
  ]),
  PolicySection('penyimpanan & hapus akun', [
    'data disimpan selama akunmu aktif. lewat menu akun → "hapus akun", '
        'profil, catch, hewan, komentar, reaksi, streak, dan semua fotomu '
        'dihapus permanen dan tidak bisa dikembalikan. data pemakaian anonim '
        'di Firebase mengikuti masa simpan Firebase.',
    'nggak bisa buka app-nya lagi? kirim email ke $privacyContactEmail dari '
        'email akunmu dengan judul "hapus akun furreal". akunmu kami hapus '
        'dengan cara yang sama dalam 30 hari.',
  ]),
  PolicySection('anak-anak', [
    'furreal tidak ditujukan untuk anak di bawah 13 tahun.',
  ]),
  PolicySection('perubahan & kontak', [
    'kalau kebijakan ini berubah, versi terbaru ada di app dan halaman ini. '
        'pertanyaan atau permintaan soal datamu: $privacyContactEmail.',
  ]),
];
