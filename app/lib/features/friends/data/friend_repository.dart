import 'package:supabase_flutter/supabase_flutter.dart';

import '../../catch_result/data/catch_repository.dart' show catchPhotosBucket;
import '../../collection/data/collection_models.dart';

/// Hubungan saya dengan user lain (M18).
enum FriendRelation {
  self,
  friend,

  /// Saya sudah minta, menunggu dia.
  outgoing,

  /// Dia minta, menunggu saya.
  incoming,
  none;

  static FriendRelation fromDb(String? v) =>
      values.where((r) => r.name == v).firstOrNull ?? none;
}

class FriendUser {
  const FriendUser({
    required this.id,
    required this.username,
    required this.relation,
    this.displayName,
    this.avatarPath,
  });

  factory FriendUser.fromJson(Map<String, dynamic> json) => FriendUser(
    id: json['user_id'] as String,
    username: json['username'] as String? ?? '',
    displayName: json['display_name'] as String?,
    avatarPath: json['avatar_path'] as String?,
    relation: FriendRelation.fromDb(json['relation'] as String?),
  );

  final String id;
  final String username;
  final String? displayName;
  final String? avatarPath;
  final FriendRelation relation;

  String get name => displayName ?? username;

  FriendUser withRelation(FriendRelation r) => FriendUser(
    id: id,
    username: username,
    displayName: displayName,
    avatarPath: avatarPath,
    relation: r,
  );
}

/// Profil (diri sendiri, teman, atau satu circle; M19).
class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.relation,
    this.displayName,
    this.avatarPath,
    this.streak = 0,
    this.longestStreak = 0,
    this.animalCount = 0,
    this.catchCount = 0,
    this.friendCount = 0,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['user_id'] as String,
    username: json['username'] as String? ?? '',
    displayName: json['display_name'] as String?,
    avatarPath: json['avatar_path'] as String?,
    streak: json['streak'] as int? ?? 0,
    longestStreak: json['longest_streak'] as int? ?? 0,
    animalCount: json['animal_count'] as int? ?? 0,
    catchCount: json['catch_count'] as int? ?? 0,
    friendCount: json['friend_count'] as int? ?? 0,
    relation: FriendRelation.fromDb(json['relation'] as String?),
  );

  final String id;
  final String username;
  final String? displayName;
  final String? avatarPath;
  final int streak;
  final int longestStreak;
  final int animalCount;
  final int catchCount;
  final int friendCount;
  final FriendRelation relation;

  String get name => displayName ?? username;
}

abstract interface class FriendRepository {
  /// Username persis; null kalau tidak ada.
  Future<FriendUser?> findUser(String username);

  /// Hasil: relasi baru (outgoing, atau friend kalau dia sudah minta duluan).
  Future<FriendRelation> sendRequest(String userId);

  Future<FriendRelation> respond(String userId, {required bool accept});

  /// Batalkan permintaan keluar atau hapus pertemanan.
  Future<void> remove(String userId);

  /// Teman + permintaan masuk/keluar.
  Future<List<FriendUser>> myFriends();

  /// null kalau tidak boleh dilihat (bukan teman / bukan satu circle).
  Future<UserProfile?> profile(String userId);

  /// Koleksi user lain (bentuk sama dengan koleksi sendiri).
  Future<List<CollectionAnimal>> collectionOf(String userId);

  /// Catch user (terbaru dulu, yang boleh dilihat), 30 per halaman.
  Future<List<HistoryCatch>> catchesOf(String userId, {DateTime? before});
}

class SupabaseFriendRepository implements FriendRepository {
  SupabaseFriendRepository(this._client);

  final SupabaseClient _client;

  Future<Map<String, String>> _sign(Iterable<String> paths) async {
    final list = paths.toList();
    if (list.isEmpty) return const {};
    final results = await _client.storage
        .from(catchPhotosBucket)
        .createSignedUrlsResult(list, 3600);
    return {
      for (final r in results)
        if (r is SignedUrlSuccess) r.path: r.signedUrl,
    };
  }

  @override
  Future<FriendUser?> findUser(String username) async {
    final rows = (await _client.rpc(
      'find_user',
      params: {'p_username': username},
    ) as List).cast<Map<String, dynamic>>();
    return rows.isEmpty ? null : FriendUser.fromJson(rows.first);
  }

  @override
  Future<FriendRelation> sendRequest(String userId) async =>
      FriendRelation.fromDb(
        await _client.rpc<String>(
          'send_friend_request',
          params: {'p_user_id': userId},
        ),
      );

  @override
  Future<FriendRelation> respond(String userId, {required bool accept}) async =>
      FriendRelation.fromDb(
        await _client.rpc<String>(
          'respond_friend_request',
          params: {'p_user_id': userId, 'p_accept': accept},
        ),
      );

  @override
  Future<void> remove(String userId) =>
      _client.rpc<void>('remove_friend', params: {'p_user_id': userId});

  @override
  Future<List<FriendUser>> myFriends() async {
    final rows = (await _client.rpc('my_friends') as List)
        .cast<Map<String, dynamic>>();
    return [for (final r in rows) FriendUser.fromJson(r)];
  }

  @override
  Future<UserProfile?> profile(String userId) async {
    final rows = (await _client.rpc(
      'user_profile',
      params: {'p_user_id': userId},
    ) as List).cast<Map<String, dynamic>>();
    return rows.isEmpty ? null : UserProfile.fromJson(rows.first);
  }

  @override
  Future<List<CollectionAnimal>> collectionOf(String userId) async {
    final rows = (await _client.rpc(
      'user_collection',
      params: {'p_user_id': userId},
    ) as List).cast<Map<String, dynamic>>();
    final urls = await _sign([
      for (final r in rows) ...[
        ?r['last_animal_photo_path'] as String?,
        ?r['last_cutout_path'] as String?,
      ],
    ]);
    return [
      for (final r in rows) CollectionAnimal.fromJson(r, signedUrls: urls),
    ];
  }

  @override
  Future<List<HistoryCatch>> catchesOf(
    String userId, {
    DateTime? before,
  }) async {
    var query = _client
        .from('catches')
        .select(
          'id, animal_id, catch_date, created_at, animal_photo_path, '
          'selfie_photo_path, caption, timing, is_late, animals(name, animal_type)',
        )
        .eq('user_id', userId);
    if (before != null) {
      final d = before;
      query = query.lt(
        'catch_date',
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      );
    }
    final rows =
        (await query
                .order('catch_date', ascending: false)
                .order('created_at', ascending: false)
                .limit(30))
            .cast<Map<String, dynamic>>();
    final urls = await _sign([
      for (final r in rows) ...[
        r['animal_photo_path'] as String,
        r['selfie_photo_path'] as String,
      ],
    ]);
    return [for (final r in rows) HistoryCatch.fromJson(r, signedUrls: urls)];
  }
}
