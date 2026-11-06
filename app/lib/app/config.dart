/// Konfigurasi dari `--dart-define-from-file=.env.local`.
/// Hanya nilai yang boleh ada di app (lihat PRD §10).
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// OAuth client ID tipe "Web application" (Google Cloud). Kosong = tombol
  /// masuk dengan Google disembunyikan.
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  /// Opsional (M13): link unduh app (mis. Play Store / Firebase App
  /// Distribution) yang ikut di pesan undangan circle. Kosong = tanpa link.
  static const inviteLink = String.fromEnvironment('INVITE_LINK');

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
