import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/dates.dart';
import '../../catch_result/data/catch_repository.dart'
    show AnimalKind, catchPhotosBucket;
import 'collection_models.dart';

const _signedUrlTtlSeconds = 3600;

/// Berapa catch dimuat per halaman riwayat.
const historyPageSize = 30;

abstract interface class CollectionRepository {
  Future<List<CollectionAnimal>> myCollection();

  Future<Streak> myStreak();

  Future<YesterdayCatch?> yesterdayCatch();

  /// Ubah data kartu (M15). [personality] null/kosong = pakai kepribadian
  /// catch terakhir.
  Future<void> editAnimal(
    String animalId, {
    required String name,
    required AnimalKind kind,
    required String? animalType,
    required String? personality,
  });

  /// Hapus hewan dari koleksi; catch & fotonya tetap ada (M15).
  Future<void> removeAnimal(String animalId);

  /// Pajang / lepas kartu favorit (M17). PostgrestException FR007 kalau
  /// sudah ada 3 kartu dipajang.
  Future<void> setPinned(String animalId, {required bool pinned});

  /// Riwayat catch sendiri, terbaru dulu, [limit] per halaman. [before] =
  /// tanggal catch terakhir halaman sebelumnya.
  Future<List<HistoryCatch>> myCatches({DateTime? before, int limit});
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
    final urls = await _sign([
      for (final r in rows) ...[
        ?r['last_animal_photo_path'] as String?,
        ?r['last_cutout_path'] as String?,
      ],
    ]);
    return [
      for (final row in rows) CollectionAnimal.fromJson(row, signedUrls: urls),
    ];
  }

  @override
  Future<void> editAnimal(
    String animalId, {
    required String name,
    required AnimalKind kind,
    required String? animalType,
    required String? personality,
  }) => _client.rpc<void>(
    'edit_animal',
    params: {
      'p_animal_id': animalId,
      'p_name': name,
      'p_kind': kind.dbValue,
      'p_animal_type': animalType,
      'p_personality': personality,
    },
  );

  @override
  Future<List<HistoryCatch>> myCatches({
    DateTime? before,
    int limit = historyPageSize,
  }) async {
    var query = _client
        .from('catches')
        .select(
          'id, animal_id, catch_date, created_at, animal_photo_path, '
          'selfie_photo_path, '
          'caption, timing, is_late, animals(name, animal_type)',
        )
        .eq('user_id', _userId);
    if (before != null) query = query.lt('catch_date', isoDate(before));
    final rows =
        (await query
                .order('catch_date', ascending: false)
                .order('created_at', ascending: false)
                .limit(limit))
            .cast<Map<String, dynamic>>();
    final urls = await _sign([
      for (final r in rows) ...[
        r['animal_photo_path'] as String,
        r['selfie_photo_path'] as String,
      ],
    ]);
    return [for (final r in rows) HistoryCatch.fromJson(r, signedUrls: urls)];
  }

  @override
  Future<void> setPinned(String animalId, {required bool pinned}) =>
      _client.rpc<void>(
        'set_animal_pinned',
        params: {'p_animal_id': animalId, 'p_pinned': pinned},
      );

  @override
  Future<void> removeAnimal(String animalId) =>
      _client.rpc<void>('remove_animal', params: {'p_animal_id': animalId});

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
