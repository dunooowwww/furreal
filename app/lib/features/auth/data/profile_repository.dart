import 'package:supabase_flutter/supabase_flutter.dart';

class Profile {
  const Profile({
    required this.id,
    this.username,
    this.displayName,
    this.guidelinesAcceptedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    final accepted = json['guidelines_accepted_at'] as String?;
    return Profile(
      id: json['id'] as String,
      username: json['username'] as String?,
      displayName: json['display_name'] as String?,
      guidelinesAcceptedAt: accepted == null ? null : DateTime.parse(accepted),
    );
  }

  final String id;
  final String? username;
  final String? displayName;

  /// Kapan pedoman kesejahteraan hewan disetujui (null = belum).
  final DateTime? guidelinesAcceptedAt;
}

/// Sama dengan check constraint `profiles.username` di database.
final usernamePattern = RegExp(r'^[a-z0-9_.]{3,20}$');

abstract interface class ProfileRepository {
  Future<Profile?> fetchProfile(String userId);

  Future<void> saveUsername({
    required String userId,
    required String username,
    required String displayName,
  });

  /// Setujui pedoman kesejahteraan hewan (onboarding, sekali per akun).
  Future<void> acceptGuidelines();
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Profile?> fetchProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select('id, username, display_name, guidelines_accepted_at')
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }

  @override
  Future<void> saveUsername({
    required String userId,
    required String username,
    required String displayName,
  }) async {
    await _client
        .from('profiles')
        .update({'username': username, 'display_name': displayName})
        .eq('id', userId);
  }

  @override
  Future<void> acceptGuidelines() => _client.rpc<void>('accept_guidelines');
}
