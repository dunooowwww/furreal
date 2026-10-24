import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../daily_drop/data/daily_drop.dart';
import '../../../shared/dates.dart';
import '../../../shared/uuid.dart';
import '../../camera/data/captured_photos.dart';
import 'ai_identification.dart';
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

const animalTypeMaxLength = 40;
const personalityMaxLength = 300;

/// Foto sudah ter-upload ke `{user_id}/{id}/`, baris catch belum dibuat.
class PreparedCatch {
  const PreparedCatch({
    required this.id,
    required this.animalPath,
    required this.selfiePath,
  });

  final String id;
  final String animalPath;
  final String selfiePath;
}

/// Isian user di layar hasil tangkapan.
class CatchDetails {
  const CatchDetails({
    required this.animalName,
    required this.kind,
    required this.animalType,
    required this.personality,
    required this.areaLabel,
    required this.locationHidden,
    this.existingAnimalId,
  });

  /// "Ketemu lagi": hewan lama milik sendiri. null = hewan baru.
  final String? existingAnimalId;
  final String animalName;
  final AnimalKind kind;

  /// Jenis final (pilihan/koreksi user), boleh kosong.
  final String? animalType;

  /// Kartu kepribadian final (boleh diedit user), boleh kosong.
  final String? personality;
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
    this.animalType,
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
      animalType: animal?['animal_type'] as String?,
    );
  }

  final String id;
  final String animalPhotoPath;
  final String selfiePhotoPath;
  final String? animalId;
  final String? animalName;
  final AnimalKind? kind;
  final String? animalType;
}

abstract interface class CatchRepository {
  Future<TodayCatch?> todayCatch();

  /// Kompres + upload kedua foto. Catch belum dibuat.
  Future<PreparedCatch> prepare(CapturedPhotos photos);

  /// Kenali hewan lewat Edge Function `identify-animal`.
  /// Melempar [AiFailure] kalau gagal; `animalType` null = tidak ada hewan.
  Future<AiIdentification> identify(PreparedCatch prepared);

  /// Simpan catch + hewan baru. Melempar PostgrestException `FR001` kalau
  /// sudah catch hari ini. Hasil: label waktu dari server.
  Future<CatchTiming> submit(PreparedCatch prepared, CatchDetails details);

  /// Kabari anggota circle lewat Edge Function `notify-catch` (sekali per
  /// catch, dijaga server). Gagal tidak membatalkan catch.
  Future<void> notifyCircle(String catchId);

  /// Hapus foto yang sudah ter-upload kalau user batal posting.
  Future<void> discard(PreparedCatch prepared);

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
          'id, animal_id, animal_photo_path, selfie_photo_path, '
          'animals(name, kind, animal_type)',
        )
        .eq('user_id', _userId)
        .eq('catch_date', isoDate(jakartaToday()))
        .maybeSingle();
    return row == null ? null : TodayCatch.fromJson(row);
  }

  @override
  Future<PreparedCatch> prepare(CapturedPhotos photos) async {
    final id = uuidV4();
    final prepared = PreparedCatch(
      id: id,
      animalPath: '$_userId/$id/animal.jpg',
      selfiePath: '$_userId/$id/selfie.jpg',
    );
    final compressed = await Future.wait([
      _compressor.compress(photos.animal),
      _compressor.compress(photos.selfie),
    ]);
    const options = FileOptions(contentType: 'image/jpeg', upsert: true);
    try {
      await Future.wait([
        _photos.uploadBinary(
          prepared.animalPath,
          compressed[0],
          fileOptions: options,
        ),
        _photos.uploadBinary(
          prepared.selfiePath,
          compressed[1],
          fileOptions: options,
        ),
      ]);
    } catch (_) {
      await discard(prepared);
      rethrow;
    }
    return prepared;
  }

  @override
  Future<AiIdentification> identify(PreparedCatch prepared) async {
    try {
      final response = await _client.functions
          .invoke('identify-animal', body: {'catch_id': prepared.id})
          // Function punya batas 15 detik; beri jeda untuk jaringan.
          .timeout(const Duration(seconds: 20));
      return AiIdentification.fromJson(response.data);
    } on FunctionException catch (e) {
      final error = switch (e.details) {
        {'error': final Map<dynamic, dynamic> error} => error,
        _ => null,
      };
      final code = error?['code'];
      throw AiFailure(code is String ? code : 'ai_unavailable');
    } on TimeoutException {
      throw const AiFailure('timeout');
    } on AiFailure {
      rethrow;
    } catch (_) {
      throw const AiFailure('ai_unavailable');
    }
  }

  @override
  Future<CatchTiming> submit(
    PreparedCatch prepared,
    CatchDetails details,
  ) async {
    final row = await _client.rpc(
      'create_catch',
      params: {
        'p_catch_id': prepared.id,
        'p_animal_name': details.animalName,
        'p_animal_kind': details.kind.dbValue,
        'p_area_label': details.locationHidden ? null : details.areaLabel,
        'p_location_hidden': details.locationHidden,
        'p_animal_type': details.animalType,
        'p_personality': details.personality,
        'p_animal_id': details.existingAnimalId,
      },
    );
    final json = row as Map<String, dynamic>;
    return CatchTiming.fromDb(
      json['timing'] as String?,
      isLate: json['is_late'] as bool? ?? false,
    );
  }

  @override
  Future<void> notifyCircle(String catchId) async {
    await _client.functions.invoke('notify-catch', body: {'catch_id': catchId});
  }

  @override
  Future<void> discard(PreparedCatch prepared) async {
    await _photos
        .remove([prepared.animalPath, prepared.selfiePath])
        .catchError((_) => <FileObject>[]);
  }

  @override
  Future<void> deleteTodayCatch() async {
    final today = await todayCatch();
    if (today == null) return;
    await _photos.remove([today.animalPhotoPath, today.selfiePhotoPath]);
    await _client.from('catches').delete().eq('id', today.id);
    // Hapus hewannya hanya kalau dibuat oleh catch ini (tanpa catch lain).
    // Hewan "ketemu lagi" tetap, encounter_count-nya turun lewat trigger.
    final animalId = today.animalId;
    if (animalId != null) {
      final others = await _client
          .from('catches')
          .select('id')
          .eq('animal_id', animalId)
          .limit(1);
      if (others.isEmpty) {
        await _client.from('animals').delete().eq('id', animalId);
      }
    }
  }
}
