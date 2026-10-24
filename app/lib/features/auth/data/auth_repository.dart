import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Metode login yang tampil di layar masuk/daftar (M8).
enum AuthMethod { password, google }

enum SignUpResult {
  /// Akun dibuat; kode verifikasi 6 angka dikirim ke email.
  codeSent,

  /// Email sudah terdaftar (Supabase tidak mengirim email apa pun).
  alreadyRegistered,
}

/// Username/email atau password salah (tanpa membedakan keduanya).
class InvalidLogin implements Exception {
  const InvalidLogin();
}

/// Password benar tapi email belum diverifikasi. Kode baru sudah dikirim.
class EmailNotConfirmed implements Exception {
  const EmailNotConfirmed(this.email);

  final String email;
}

abstract interface class AuthRepository {
  /// Id user yang sedang login, atau null. Langsung memancarkan status awal.
  Stream<String?> userIdChanges();

  /// Daftar dengan email + password. Akun aktif setelah [verifySignUp].
  Future<SignUpResult> signUp({
    required String email,
    required String password,
  });

  Future<void> verifySignUp({required String email, required String code});

  Future<void> resendSignUpCode(String email);

  /// [identifier] = username atau email. Melempar [InvalidLogin] atau
  /// [EmailNotConfirmed].
  Future<void> signInWithPassword({
    required String identifier,
    required String password,
  });

  /// Kirim kode reset password. Tidak membedakan email terdaftar atau tidak.
  Future<void> sendPasswordReset(String email);

  /// Verifikasi kode reset, lalu pasang [newPassword]. User langsung masuk.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });

  /// Selesai tanpa error kalau user membatalkan pilihan akun.
  Future<void> signInWithGoogle();

  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client, {required this.googleWebClientId});

  final SupabaseClient _client;

  /// OAuth client "Web application" di Google Cloud (bukan yang Android).
  final String googleWebClientId;

  GoTrueClient get _auth => _client.auth;

  static Future<void>? _googleInit;

  @override
  Stream<String?> userIdChanges() =>
      _auth.onAuthStateChange.map((state) => state.session?.user.id).distinct();

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
  }) async {
    final response = await _auth.signUp(
      email: normalizeEmail(email),
      password: password,
    );
    // Email terdaftar: Supabase membalas user palsu tanpa identitas (supaya
    // tidak bisa dipakai menebak email) dan tidak mengirim kode.
    final identities = response.user?.identities;
    if (identities != null && identities.isEmpty) {
      return SignUpResult.alreadyRegistered;
    }
    return SignUpResult.codeSent;
  }

  @override
  Future<void> verifySignUp({
    required String email,
    required String code,
  }) async {
    await _auth.verifyOTP(
      email: normalizeEmail(email),
      token: code.trim(),
      type: OtpType.signup,
    );
  }

  @override
  Future<void> resendSignUpCode(String email) =>
      _auth.resend(type: OtpType.signup, email: normalizeEmail(email));

  @override
  Future<void> signInWithPassword({
    required String identifier,
    required String password,
  }) async {
    final id = identifier.trim();
    final String email;
    if (id.contains('@')) {
      email = normalizeEmail(id);
    } else {
      // Email hanya dikembalikan kalau password-nya benar (lihat migrasi M8).
      final resolved = await _client.rpc<String?>(
        'resolve_login',
        params: {'p_username': id.toLowerCase(), 'p_password': password},
      );
      if (resolved == null) throw const InvalidLogin();
      email = resolved;
    }
    try {
      await _auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      if (e.code == 'email_not_confirmed') {
        await resendSignUpCode(email);
        throw EmailNotConfirmed(email);
      }
      if (e.code == 'invalid_credentials') throw const InvalidLogin();
      rethrow;
    }
  }

  @override
  Future<void> sendPasswordReset(String email) =>
      _auth.resetPasswordForEmail(normalizeEmail(email));

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _auth.verifyOTP(
      email: normalizeEmail(email),
      token: code.trim(),
      type: OtpType.recovery,
    );
    await _auth.updateUser(UserAttributes(password: newPassword));
  }

  @override
  Future<void> signInWithGoogle() async {
    final google = GoogleSignIn.instance;
    await (_googleInit ??= google.initialize(
      serverClientId: googleWebClientId,
    ));
    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      rethrow;
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: 'tanpa id token',
      );
    }
    await _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }

  @override
  Future<void> signOut() async {
    // Supaya lain kali bisa pilih akun Google lain.
    if (_googleInit != null) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    await _auth.signOut();
  }
}

String normalizeEmail(String email) => email.trim().toLowerCase();

final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final otpPattern = RegExp(r'^\d{6}$');

/// Sama dengan `minimum_password_length` di Supabase Auth.
const passwordMinLength = 8;
