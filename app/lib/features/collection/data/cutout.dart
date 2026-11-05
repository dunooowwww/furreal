import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/uuid.dart';
import '../../catch_result/data/catch_repository.dart' show catchPhotosBucket;
import 'collection_models.dart';

/// Potong hewan dari foto: PNG transparan, atau null kalau tidak ada subjek
/// yang cukup jelas. Melempar kalau ML Kit tidak tersedia (dicoba lagi nanti).
abstract interface class CutoutMaker {
  Future<Uint8List?> cutout(Uint8List photo);
}

/// Subjek terbesar harus menutupi minimal sekian bagian foto.
const minSubjectArea = 0.03;

/// Indeks subjek utama (terbesar), atau null kalau terlalu kecil / tidak ada.
int? pickMainSubject(
  List<({int width, int height})> subjects, {
  required int imageWidth,
  required int imageHeight,
}) {
  if (subjects.isEmpty || imageWidth <= 0 || imageHeight <= 0) return null;
  var best = 0;
  for (var i = 1; i < subjects.length; i++) {
    final s = subjects[i];
    final b = subjects[best];
    if (s.width * s.height > b.width * b.height) best = i;
  }
  final s = subjects[best];
  final area = s.width * s.height / (imageWidth * imageHeight);
  return area >= minSubjectArea ? best : null;
}

/// Google ML Kit Subject Segmentation, di HP (Android 7+, Play Services).
class MlKitCutoutMaker implements CutoutMaker {
  static const maxSide = 720;

  @override
  Future<Uint8List?> cutout(Uint8List photo) async {
    // Tegakkan sesuai EXIF dulu (ML Kit membaca piksel apa adanya).
    final upright = await FlutterImageCompress.compressWithList(
      photo,
      minWidth: 1280,
      minHeight: 1280,
      quality: 90,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    final codec = await ui.instantiateImageCodec(upright);
    final frame = await codec.getNextFrame();
    final width = frame.image.width;
    final height = frame.image.height;
    frame.image.dispose();

    final file = File('${Directory.systemTemp.path}/cutout-${uuidV4()}.jpg');
    final segmenter = SubjectSegmenter(
      options: SubjectSegmenterOptions(
        enableForegroundBitmap: false,
        enableForegroundConfidenceMask: false,
        enableMultipleSubjects: SubjectResultOptions(
          enableConfidenceMask: false,
          enableSubjectBitmap: true,
        ),
      ),
    );
    try {
      await file.writeAsBytes(upright);
      final result = await segmenter.processImage(
        InputImage.fromFilePath(file.path),
      );
      final index = pickMainSubject(
        [for (final s in result.subjects) (width: s.width, height: s.height)],
        imageWidth: width,
        imageHeight: height,
      );
      final png = index == null ? null : result.subjects[index].bitmap;
      if (png == null) return null;
      // Bitmap subjek sudah dipotong ke kotak subjeknya; kecilkan ke 720px.
      return await FlutterImageCompress.compressWithList(
        png,
        minWidth: maxSide,
        minHeight: maxSide,
        format: CompressFormat.png,
      );
    } finally {
      await segmenter.close();
      if (await file.exists()) await file.delete();
    }
  }
}

abstract interface class CutoutRepository {
  /// Foto hewan dari storage (untuk catch lama).
  Future<Uint8List> download(String path);

  /// Upload potongan lalu tandai catch-nya; [png] null = tidak ada hewan
  /// terdeteksi (catch ditandai sudah dicoba).
  Future<void> save(String catchId, Uint8List? png);
}

class SupabaseCutoutRepository implements CutoutRepository {
  SupabaseCutoutRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Uint8List> download(String path) =>
      _client.storage.from(catchPhotosBucket).download(path);

  @override
  Future<void> save(String catchId, Uint8List? png) async {
    if (png != null) {
      final userId = _client.auth.currentUser!.id;
      await _client.storage
          .from(catchPhotosBucket)
          .uploadBinary(
            '$userId/$catchId/cutout.png',
            png,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              upsert: true,
            ),
          );
    }
    await _client.rpc<void>(
      'set_catch_cutout',
      params: {'p_catch_id': catchId, 'p_has_cutout': png != null},
    );
  }
}

/// Alur potong + simpan, untuk catch baru dan catch lama.
class CutoutService {
  CutoutService(this._maker, this._repository);

  final CutoutMaker _maker;
  final CutoutRepository _repository;

  /// Catch lama yang sudah dicoba di sesi ini (berhasil atau gagal).
  final _tried = <String>{};

  /// Potong [photo]. null kalau tidak ada hewan atau ML Kit gagal.
  Future<Uint8List?> make(Uint8List photo) async {
    try {
      return await _maker.cutout(photo);
    } catch (e) {
      debugPrint('cutout: $e');
      return null;
    }
  }

  /// Simpan hasil [make] untuk catch baru. Tidak pernah melempar.
  Future<void> save(String catchId, Uint8List? png) async {
    try {
      await _repository.save(catchId, png);
    } catch (e) {
      debugPrint('cutout save: $e');
    }
  }

  /// Hewan yang catch terakhirnya belum punya potongan dan belum dicoba.
  static List<CollectionAnimal> pending(List<CollectionAnimal> animals) => [
    for (final a in animals)
      if (a.lastCatchId != null &&
          a.lastPhotoPath != null &&
          a.lastCutoutPath == null &&
          !a.cutoutAttempted)
        a,
  ];

  /// Proses catch lama satu per satu (maks [limit] per panggilan).
  /// Hasil: berapa catch yang tersimpan (ada atau tidak ada hewannya).
  Future<int> backfill(List<CollectionAnimal> animals, {int limit = 8}) async {
    var saved = 0;
    for (final animal in pending(animals)) {
      if (saved >= limit) break;
      final catchId = animal.lastCatchId!;
      if (!_tried.add(catchId)) continue;
      try {
        final photo = await _repository.download(animal.lastPhotoPath!);
        // ML Kit gagal (mis. model belum terunduh) → jangan ditandai,
        // dicoba lagi di sesi berikutnya.
        final png = await _maker.cutout(photo);
        await _repository.save(catchId, png);
        saved++;
      } catch (e) {
        debugPrint('cutout backfill $catchId: $e');
      }
    }
    return saved;
  }
}
