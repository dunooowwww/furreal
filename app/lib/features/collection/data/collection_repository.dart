import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/dates.dart';
import '../../catch_result/data/catch_repository.dart' show catchPhotosBucket;
import 'collection_models.dart';

const _signedUrlTtlSeconds = 3600;

abstract interface class CollectionRepository {
  Future<List<CollectionAnimal>> myCollection();

  Future<Streak> myStreak();

  Future<YesterdayCatch?> yesterdayCatch();
}

class SupabaseCollectionRepository implements CollectionRepository {
  SupabaseCollectionRepository(this._client);

  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  Future<Map<String, String>> _sign(Iterable<String> paths) async {
    final list = paths.toList();
    if (list.isEmpty) return const {};
    final results = await _client.storage
        .from(catchPhotosBucket)
        .createSignedUrlsResult(list, _signedUrlTtlSeconds);
    return {
      for (final r in results)
        if (r is SignedUrlSuccess) r.path: r.signedUrl,
    };
  }

  @override
  Future<List<CollectionAnimal>> myCollection() async {
    final rows = (await _client.rpc('my_collection') as List)
        .cast<Map<String, dynamic>>();
    final urls = await _sign(
      rows.map((r) => r['last_animal_photo_path']).whereType<String>(),
    );
    return [
      for (final row in rows) CollectionAnimal.fromJson(row, signedUrls: urls),
    ];
  }

  @override
  Future<Streak> myStreak() async {
    final rows = (await _client.rpc('my_streak') as List)
        .cast<Map<String, dynamic>>();
    if (rows.isEmpty) return Streak.none;
    return Streak(
      current: rows.first['current'] as int? ?? 0,
      longest: rows.first['longest'] as int? ?? 0,
    );
  }

  @override
  Future<YesterdayCatch?> yesterdayCatch() async {
    final yesterday = jakartaToday().subtract(const Duration(days: 1));
    final row = await _client
        .from('catches')
        .select(
          'animal_photo_path, animals(name, animal_type, encounter_count)',
        )
        .eq('user_id', _userId)
        .eq('catch_date', isoDate(yesterday))
        .maybeSingle();
    if (row == null) return null;
    final animal = row['animals'] as Map<String, dynamic>?;
    final path = row['animal_photo_path'] as String;
    final urls = await _sign([path]);
    return YesterdayCatch(
      animalName: animal?['name'] as String? ?? 'tanpa nama',
      animalType: animal?['animal_type'] as String?,
      encounterCount: animal?['encounter_count'] as int? ?? 1,
      photoPath: path,
      photoUrl: urls[path],
    );
  }
}
