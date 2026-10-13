import 'package:supabase_flutter/supabase_flutter.dart';

/// Ubah error dari Supabase menjadi copy yang ramah untuk user.
String friendlyError(Object error) {
  if (error is AuthRetryableFetchException) {
    return 'koneksi bermasalah. coba lagi ya.';
  }
  if (error is AuthException) {
    if (error.statusCode == '429' ||
        error.code == 'over_email_send_rate_limit') {
      return 'terlalu sering minta kode. tunggu sebentar ya.';
    }
    if (error.code == 'otp_expired' || error.statusCode == '403') {
      return 'kodenya salah atau sudah kedaluwarsa.';
    }
    return 'gagal masuk. coba lagi ya.';
  }
  if (error is StorageException) {
    return 'upload foto gagal. cek koneksi lalu coba lagi.';
  }
  if (error is PostgrestException) {
    switch (error.code) {
      case 'FR001':
        return 'kamu udah catch hari ini. besok lagi ya!';
      case 'FR002':
        return 'foto belum ke-upload. coba posting lagi.';
      case '23505':
        return 'username sudah dipakai. coba yang lain.';
      case 'P0002':
        return 'kode undangan tidak ditemukan.';
      case '23514':
        return 'isiannya belum sesuai format.';
    }
  }
  return 'ada yang salah. coba lagi ya.';
}
