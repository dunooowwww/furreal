import 'package:supabase_flutter/supabase_flutter.dart';

enum FeedbackCategory {
  feature('feature', 'saran fitur'),
  bug('bug', 'laporan bug');

  const FeedbackCategory(this.dbValue, this.label);

  final String dbValue;
  final String label;
}

/// Sama dengan check constraint `feedback.message`.
const feedbackMaxLength = 1000;

/// Versi app dari `flutter build` (kosong saat `flutter run`/test).
const appVersion = String.fromEnvironment('FLUTTER_BUILD_NAME');
const appBuildNumber = String.fromEnvironment('FLUTTER_BUILD_NUMBER');

abstract interface class FeedbackRepository {
  /// Kirim saran / laporan bug (tabel `feedback`, hanya bisa insert).
  Future<void> submit(FeedbackCategory category, String message);
}

class SupabaseFeedbackRepository implements FeedbackRepository {
  SupabaseFeedbackRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> submit(FeedbackCategory category, String message) async {
    await _client.from('feedback').insert({
      'category': category.dbValue,
      'message': message,
      if (appVersion.isNotEmpty)
        'app_version': appBuildNumber.isEmpty
            ? appVersion
            : '$appVersion+$appBuildNumber',
    });
  }
}
