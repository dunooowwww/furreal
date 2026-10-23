import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/uuid.dart';

/// Bucket private foto profil: {uid}/{uuid}.jpg (M9).
const avatarsBucket = 'avatars';

class Profile {
  const Profile({
    required this.id,
    this.username,
    this.displayName,
    this.guidelinesAcceptedAt,
    this.avatarPath,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    final accepted = json['guidelines_accepted_at'] as String?;
    return Profile(
      id: json['id'] as String,
      username: json['username'] as String?,
      displayName: json['display_name'] as String?,
      guidelinesAcceptedAt: accepted == null ? null : DateTime.parse(accepted),
      avatarPath: json['avatar_path'] as String?,
    );
  }

  final String id;
  final String? username;
  final String? displayName;

  /// Kapan pedoman kesejahteraan hewan disetujui (null = belum).
  final DateTime? guidelinesAcceptedAt;

  /// Path foto profil di bucket [avatarsBucket] (null = belum ada).
  final String? avatarPath;
}

/// Sama dengan check constraint `profiles.username` di database.
final usernamePattern = RegExp(r'^[a-z0-9_.]{3,20}$');

abstract interface class ProfileRepository {
  Future<Profile?> fetchProfile(String userId);

  /// Juga dipakai untuk edit profil di pengaturan.
  Future<void> saveUsername({
    required String userId,
    required String username,
    required String displayName,
  });

  /// Setujui pedoman kesejahteraan hewan (onboarding, sekali per akun).
  Future<void> acceptGuidelines();

  /// Upload [jpeg] sebagai foto profil baru, lalu hapus yang lama.
  Future<String> setAvatar({required String userId, required Uint8List jpeg});

  Future<void> removeAvatar(String userId);

  /// Signed URL foto profil (null kalau tidak bisa dibaca).
  Future<String?> avatarUrl(String path);
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Profile?> fetchProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select(
          'id, username, display_name, guidelines_accepted_at, avatar_path',
        )
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

  @override
  Future<String> setAvatar({
    required String userId,
    required Uint8List jpeg,
  }) async {
    final old = await _currentAvatar(userId);
    // Nama baru tiap ganti supaya cache gambar di HP teman tidak basi.
    final path = '$userId/${uuidV4()}.jpg';
    final bucket = _client.storage.from(avatarsBucket);
    await bucket.uploadBinary(
      path,
      jpeg,
      fileOptions: const FileOptions(contentType: 'image/jpeg'),
    );
    try {
      await _client
          .from('profiles')
          .update({'avatar_path': path})
          .eq('id', userId);
    } catch (_) {
      await _removeQuietly(path);
      rethrow;
    }
    if (old != null) await _removeQuietly(old);
    return path;
  }

  @override
  Future<void> removeAvatar(String userId) async {
    final old = await _currentAvatar(userId);
    await _client
        .from('profiles')
        .update({'avatar_path': null})
        .eq('id', userId);
    if (old != null) await _removeQuietly(old);
  }

  @override
  Future<String?> avatarUrl(String path) async {
    try {
      return await _client.storage
          .from(avatarsBucket)
          .createSignedUrl(path, 3600);
    } on StorageException {
      return null;
    }
  }

  Future<String?> _currentAvatar(String userId) async {
    final row = await _client
        .from('profiles')
        .select('avatar_path')
        .eq('id', userId)
        .maybeSingle();
    return row?['avatar_path'] as String?;
  }

  /// File lama yang gagal dihapus tidak menggagalkan ganti foto; sisanya
  /// ikut terhapus saat hapus akun.
  Future<void> _removeQuietly(String path) async {
    try {
      await _client.storage.from(avatarsBucket).remove([path]);
    } catch (_) {}
  }
}
