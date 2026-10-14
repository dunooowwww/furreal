import 'package:supabase_flutter/supabase_flutter.dart';

import '../../catch_result/data/catch_repository.dart' show catchPhotosBucket;
import 'feed_models.dart';

/// Signed URL foto berlaku 1 jam; feed di-refresh jauh lebih sering.
const signedUrlTtlSeconds = 3600;

abstract interface class FeedRepository {
  /// Catch hari ini (Asia/Jakarta) anggota circle, terbaru dulu.
  Future<List<FeedItem>> todayFeed(String circleId);

  Future<int> memberCount(String circleId);

  Future<void> setReaction(
    String catchId,
    ReactionType type, {
    required bool on,
  });

  Future<List<FeedComment>> comments(String catchId);

  Future<void> addComment(String catchId, String body);

  /// Hanya komentar sendiri (dijaga RLS).
  Future<void> deleteComment(String commentId);
}

class SupabaseFeedRepository implements FeedRepository {
  SupabaseFeedRepository(this._client);

  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<List<FeedItem>> todayFeed(String circleId) async {
    final rows = (await _client.rpc(
      'circle_feed',
      params: {'p_circle_id': circleId},
    ) as List).cast<Map<String, dynamic>>();
    if (rows.isEmpty) return const [];

    final paths = [
      for (final row in rows) ...[
        row['animal_photo_path'] as String,
        row['selfie_photo_path'] as String,
      ],
    ];
    final signed = await _client.storage
        .from(catchPhotosBucket)
        .createSignedUrlsResult(paths, signedUrlTtlSeconds);
    final urls = {
      for (final result in signed)
        if (result is SignedUrlSuccess) result.path: result.signedUrl,
    };
    return [for (final row in rows) FeedItem.fromJson(row, signedUrls: urls)];
  }

  @override
  Future<int> memberCount(String circleId) async {
    final rows = await _client
        .from('circle_members')
        .select('user_id')
        .eq('circle_id', circleId);
    return rows.length;
  }

  @override
  Future<void> setReaction(
    String catchId,
    ReactionType type, {
    required bool on,
  }) async {
    if (on) {
      try {
        await _client.from('reactions').insert({
          'catch_id': catchId,
          'type': type.dbValue,
        });
      } on PostgrestException catch (e) {
        if (e.code != '23505') rethrow; // sudah ada: anggap sukses
      }
    } else {
      await _client
          .from('reactions')
          .delete()
          .eq('catch_id', catchId)
          .eq('type', type.dbValue)
          .eq('user_id', _userId);
    }
  }

  @override
  Future<List<FeedComment>> comments(String catchId) async {
    final rows = (await _client.rpc(
      'catch_comments',
      params: {'p_catch_id': catchId},
    ) as List).cast<Map<String, dynamic>>();
    return rows.map(FeedComment.fromJson).toList();
  }

  @override
  Future<void> addComment(String catchId, String body) async {
    await _client.from('comments').insert({'catch_id': catchId, 'body': body});
  }

  @override
  Future<void> deleteComment(String commentId) async {
    await _client.from('comments').delete().eq('id', commentId);
  }
}
