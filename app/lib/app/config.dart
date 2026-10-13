/// Konfigurasi dari `--dart-define-from-file=.env.local`.
/// Hanya nilai yang boleh ada di app (lihat PRD §10).
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
