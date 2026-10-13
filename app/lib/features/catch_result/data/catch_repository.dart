import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/dates.dart';
import '../../../shared/uuid.dart';
import 'photo_compressor.dart';

enum AnimalKind {
  pet('pet', 'peliharaan'),
  wild('wild', 'liar');

  const AnimalKind(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static AnimalKind? fromDb(String? value) =>
      values.where((k) => k.dbValue == value).firstOrNull;
}

const animalNameMaxLength = 40;
const catchPhotosBucket = 'catch-photos';

class NewCatch {
  const NewCatch({
    required this.animalPhoto,
    required this.selfiePhoto,
    required this.animalName,
    required this.kind,
    required this.areaLabel,
    required this.locationHidden,
  });

  final Uint8List animalPhoto;
  final Uint8List selfiePhoto;
  final String animalName;
  final AnimalKind kind;
  final String? areaLabel;
  final bool locationHidden;
}

/// Catch milik user untuk hari ini (Asia/Jakarta).
class TodayCatch {
  const TodayCatch({
    required this.id,
    required this.animalPhotoPath,
    required this.selfiePhotoPath,
    this.animalId,
    this.animalName,
    this.kind,
  });

  factory TodayCatch.fromJson(Map<String, dynamic> json) {
    final animal = json['animals'] as Map<String, dynamic>?;
    return TodayCatch(
      id: json['id'] as String,
      animalPhotoPath: json['animal_photo_path'] as String,
      selfiePhotoPath: json['selfie_photo_path'] as String,
      animalId: json['animal_id'] as String?,
      animalName: animal?['name'] as String?,
      kind: AnimalKind.fromDb(animal?['kind'] as String?),
    );
  }

  final String id;
  final String animalPhotoPath;
  final String selfiePhotoPath;
  final String? animalId;
  final String? animalName;
  final AnimalKind? kind;
}

abstract interface class CatchRepository {
  Future<TodayCatch?> todayCatch();

  /// Kompres + upload foto, lalu simpan catch & hewan baru.
  /// Melempar PostgrestException `FR001` kalau sudah catch hari ini.
  Future<void> submit(NewCatch newCatch);

  /// Hapus catch hari ini beserta fotonya (dipakai tombol debug).
  Future<void> deleteTodayCatch();
}

class SupabaseCatchRepository implements CatchRepository {
  SupabaseCatchRepository(this._client, this._compressor);

  final SupabaseClient _client;
  final PhotoCompressor _compressor;

  String get _userId => _client.auth.currentUser!.id;

  StorageFileApi get _photos => _client.storage.from(catchPhotosBucket);

  @override
  Future<TodayCatch?> todayCatch() async {
    final row = await _client
        .from('catches')
        .select(
          'id, animal_id, animal_photo_path, selfie_photo_path, animals(name, kind)',
        )
        .eq('user_id', _userId)
        .eq('catch_date', isoDate(jakartaToday()))
        .maybeSingle();
    return row == null ? null : TodayCatch.fromJson(row);
  }

  @override
  Future<void> submit(NewCatch newCatch) async {
    final catchId = uuidV4();
    final folder = '$_userId/$catchId';
    final paths = ['$folder/animal.jpg', '$folder/selfie.jpg'];

    final compressed = await Future.wait([
      _compressor.compress(newCatch.animalPhoto),
      _compressor.compress(newCatch.selfiePhoto),
    ]);

    const options = FileOptions(contentType: 'image/jpeg', upsert: true);
    try {
      await _photos.uploadBinary(paths[0], compressed[0], fileOptions: options);
      await _photos.uploadBinary(paths[1], compressed[1], fileOptions: options);
      await _client.rpc(
        'create_catch',
        params: {
          'p_catch_id': catchId,
          'p_animal_name': newCatch.animalName,
          'p_animal_kind': newCatch.kind.dbValue,
          'p_area_label': newCatch.locationHidden ? null : newCatch.areaLabel,
          'p_location_hidden': newCatch.locationHidden,
        },
      );
    } catch (_) {
      // Jangan tinggalkan foto yatim kalau catch gagal disimpan.
      await _photos.remove(paths).catchError((_) => <FileObject>[]);
      rethrow;
    }
  }

  @override
  Future<void> deleteTodayCatch() async {
    final today = await todayCatch();
    if (today == null) return;
    await _photos.remove([today.animalPhotoPath, today.selfiePhotoPath]);
    await _client.from('catches').delete().eq('id', today.id);
    final animalId = today.animalId;
    if (animalId != null) {
      await _client.from('animals').delete().eq('id', animalId);
    }
  }
}
