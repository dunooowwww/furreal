import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/data/auth_repository.dart';

/// Ubah error dari Supabase menjadi copy yang ramah untuk user.
String friendlyError(Object error) {
  if (error is InvalidLogin) {
    return 'username/email atau password salah.';
  }
  if (error is GoogleSignInException) {
    return 'gagal masuk dengan google. coba lagi ya.';
  }
  if (error is AuthRetryableFetchException) {
    return 'koneksi bermasalah. coba lagi ya.';
  }
  if (error is AuthException) {
    if (error.statusCode == '429' ||
        error.code == 'over_email_send_rate_limit') {
      return 'terlalu sering minta kode. tunggu sebentar ya.';
    }
    switch (error.code) {
      case 'invalid_credentials':
        return 'username/email atau password salah.';
      case 'weak_password':
        return 'password terlalu lemah. minimal 8 karakter, campur huruf & angka.';
      case 'same_password':
        return 'password baru harus beda dari yang lama.';
      case 'user_already_exists' || 'email_exists':
        return 'email ini udah terdaftar. masuk aja, atau pakai lupa password.';
      case 'email_address_invalid':
        return 'emailnya belum benar.';
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
      case 'FR006':
        return 'terlalu banyak percobaan masuk pakai username ini. tunggu 15 menit, '
            'atau masuk pakai email.';
      case 'FR005':
        return 'daily drop belum turun. tunggu notifikasinya ya.';
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
