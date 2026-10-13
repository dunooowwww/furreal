import 'package:supabase_flutter/supabase_flutter.dart';

/// Metode login yang didukung. Tambah metode baru di sini, implementasikan di
/// [AuthRepository], lalu aktifkan lewat `enabledAuthMethodsProvider`.
enum AuthMethod { emailOtp, google }

abstract interface class AuthRepository {
  /// Id user yang sedang login, atau null. Langsung memancarkan status awal.
  Stream<String?> userIdChanges();

  /// Kirim kode OTP 6 digit ke [email]. User baru otomatis dibuat.
  Future<void> sendEmailOtp(String email);

  Future<void> verifyEmailOtp({required String email, required String code});

  /// Ditunda (PRD §4). Untuk mengaktifkan: tambah paket `google_sign_in`,
  /// ambil idToken, lalu panggil `signInWithIdToken(provider: OAuthProvider.google)`.
  Future<void> signInWithGoogle();

  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth);

  final GoTrueClient _auth;

  @override
  Stream<String?> userIdChanges() =>
      _auth.onAuthStateChange.map((state) => state.session?.user.id).distinct();

  @override
  Future<void> sendEmailOtp(String email) =>
      _auth.signInWithOtp(email: normalizeEmail(email), shouldCreateUser: true);

  @override
  Future<void> verifyEmailOtp({
    required String email,
    required String code,
  }) async {
    await _auth.verifyOTP(
      email: normalizeEmail(email),
      token: code.trim(),
      type: OtpType.email,
    );
  }

  @override
  Future<void> signInWithGoogle() =>
      throw UnsupportedError('google sign-in belum diaktifkan');

  @override
  Future<void> signOut() => _auth.signOut();
}

String normalizeEmail(String email) => email.trim().toLowerCase();
