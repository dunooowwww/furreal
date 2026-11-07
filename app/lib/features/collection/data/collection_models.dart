import '../../catch_result/data/catch_repository.dart' show AnimalKind;
import '../../daily_drop/data/daily_drop.dart' show CatchTiming;

/// Hewan di koleksi + foto & kepribadian dari catch terakhirnya.
class CollectionAnimal {
  const CollectionAnimal({
    required this.id,
    required this.name,
    required this.kind,
    required this.animalType,
    required this.encounterCount,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.lastPhotoPath,
    required this.lastPersonality,
    this.lastPhotoUrl,
    this.lastCatchId,
    this.lastCutoutPath,
    this.lastCutoutUrl,
    this.cutoutAttempted = false,
    this.lastCatchDate,
    this.lastAreaLabel,
    this.pinnedAt,
  });

  factory CollectionAnimal.fromJson(
    Map<String, dynamic> json, {
    Map<String, String> signedUrls = const {},
  }) {
    final path = json['last_animal_photo_path'] as String?;
    final cutout = json['last_cutout_path'] as String?;
    return CollectionAnimal(
      id: json['animal_id'] as String,
      name: json['name'] as String,
      kind: AnimalKind.fromDb(json['kind'] as String?) ?? AnimalKind.pet,
      animalType: json['animal_type'] as String?,
      encounterCount: json['encounter_count'] as int? ?? 1,
      firstSeenAt: DateTime.parse(json['first_seen_at'] as String),
      lastSeenAt: DateTime.parse(json['last_seen_at'] as String),
      lastPhotoPath: path,
      lastPersonality: json['last_personality'] as String?,
      lastPhotoUrl: path == null ? null : signedUrls[path],
      lastCatchId: json['last_catch_id'] as String?,
      lastCutoutPath: cutout,
      lastCutoutUrl: cutout == null ? null : signedUrls[cutout],
      cutoutAttempted: json['last_cutout_attempted'] as bool? ?? false,
      lastCatchDate: switch (json['last_catch_date']) {
        final String d => DateTime.parse(d),
        _ => null,
      },
      lastAreaLabel: json['last_area_label'] as String?,
      pinnedAt: switch (json['pinned_at']) {
        final String d => DateTime.parse(d),
        _ => null,
      },
    );
  }

  final String id;
  final String name;
  final AnimalKind kind;
  final String? animalType;
  final int encounterCount;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  final String? lastPhotoPath;
  final String? lastPersonality;
  final String? lastPhotoUrl;

  /// Catch terakhir dan potongan hewannya (M11). Tanpa potongan, kartu
  /// memakai foto biasa.
  final String? lastCatchId;
  final String? lastCutoutPath;
  final String? lastCutoutUrl;

  /// Sudah pernah dicoba dipotong (berhasil atau tidak ada hewannya).
  final bool cutoutAttempted;

  /// Tanggal & label area catch terakhir (null kalau lokasi disembunyikan).
  final DateTime? lastCatchDate;
  final String? lastAreaLabel;

  /// Dipajang di atas koleksi (kartu favorit, maks 3; M17).
  final DateTime? pinnedAt;
  bool get pinned => pinnedAt != null;

  CollectionAnimal copyWith({
    String? name,
    AnimalKind? kind,
    String? Function()? animalType,
    String? Function()? lastPersonality,
    DateTime? Function()? pinnedAt,
  }) => CollectionAnimal(
    id: id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    animalType: animalType == null ? this.animalType : animalType(),
    encounterCount: encounterCount,
    firstSeenAt: firstSeenAt,
    lastSeenAt: lastSeenAt,
    lastPhotoPath: lastPhotoPath,
    lastPersonality: lastPersonality == null
        ? this.lastPersonality
        : lastPersonality(),
    lastPhotoUrl: lastPhotoUrl,
    lastCatchId: lastCatchId,
    lastCutoutPath: lastCutoutPath,
    lastCutoutUrl: lastCutoutUrl,
    cutoutAttempted: cutoutAttempted,
    lastCatchDate: lastCatchDate,
    lastAreaLabel: lastAreaLabel,
    pinnedAt: pinnedAt == null ? this.pinnedAt : pinnedAt(),
  );
}

/// Nomor koleksi: #1 = hewan yang paling dulu ditemui.
Map<String, int> collectionNumbers(List<CollectionAnimal> animals) {
  final sorted = [...animals]
    ..sort((a, b) {
      final byDate = a.firstSeenAt.compareTo(b.firstSeenAt);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
  return {for (var i = 0; i < sorted.length; i++) sorted[i].id: i + 1};
}

/// Kepribadian AI dipecah: kalimat pertama jadi tagline kartu, sisanya
/// isi kotak "kepribadian". Satu kalimat saja → semuanya tagline.
({String? tagline, String? traits}) splitPersonality(String? personality) {
  final text = personality?.trim();
  if (text == null || text.isEmpty) return (tagline: null, traits: null);
  final match = RegExp(r'^(.+?[.!?])\s+(.+)$', dotAll: true).firstMatch(text);
  if (match == null) return (tagline: text, traits: null);
  return (tagline: match.group(1)!.trim(), traits: match.group(2)!.trim());
}

/// Streak yang ditampilkan (sudah 0 kalau putus, lihat `my_streak()`).
class Streak {
  const Streak({required this.current, required this.longest});

  static const none = Streak(current: 0, longest: 0);

  final int current;
  final int longest;
}

/// Catch kemarin untuk kartu "tangkapan kemarin" di beranda.
class YesterdayCatch {
  const YesterdayCatch({
    required this.animalName,
    required this.animalType,
    required this.encounterCount,
    required this.photoPath,
    this.photoUrl,
  });

  final String animalName;
  final String? animalType;
  final int encounterCount;
  final String photoPath;
  final String? photoUrl;
}

/// Hewan "ketemu lagi" diurutkan: jenis sama dengan [type] dulu, lalu yang
/// terakhir ditemui.
List<CollectionAnimal> sortForReencounter(
  List<CollectionAnimal> animals,
  String? type,
) {
  final wanted = type?.trim().toLowerCase();
  final sorted = List.of(animals);
  sorted.sort((a, b) {
    final aMatch = wanted != null && a.animalType == wanted ? 0 : 1;
    final bMatch = wanted != null && b.animalType == wanted ? 0 : 1;
    if (aMatch != bMatch) return aMatch - bMatch;
    return b.lastSeenAt.compareTo(a.lastSeenAt);
  });
  return sorted;
}

/// Satu catch sendiri di riwayat (ala BeReal Memories). Tetap ada walau
/// hewannya dihapus dari koleksi.
class HistoryCatch {
  const HistoryCatch({
    required this.id,
    required this.catchDate,
    required this.createdAt,
    required this.animalPhotoPath,
    required this.selfiePhotoPath,
    this.animalId,
    this.animalName,
    this.animalType,
    this.caption,
    this.timing = CatchTiming.onTime,
    this.animalPhotoUrl,
    this.selfiePhotoUrl,
  });

  factory HistoryCatch.fromJson(
    Map<String, dynamic> json, {
    Map<String, String> signedUrls = const {},
  }) {
    final animal = json['animals'] as Map<String, dynamic>?;
    final animalPath = json['animal_photo_path'] as String;
    final selfiePath = json['selfie_photo_path'] as String;
    return HistoryCatch(
      id: json['id'] as String,
      catchDate: DateTime.parse(json['catch_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      animalPhotoPath: animalPath,
      selfiePhotoPath: selfiePath,
      animalId: json['animal_id'] as String?,
      animalName: animal?['name'] as String?,
      animalType: animal?['animal_type'] as String?,
      caption: json['caption'] as String?,
      timing: CatchTiming.fromDb(
        json['timing'] as String?,
        isLate: json['is_late'] as bool? ?? false,
      ),
      animalPhotoUrl: signedUrls[animalPath],
      selfiePhotoUrl: signedUrls[selfiePath],
    );
  }

  final String id;

  /// Tanggal catch (Asia/Jakarta).
  final DateTime catchDate;
  final DateTime createdAt;
  final String animalPhotoPath;
  final String selfiePhotoPath;
  final String? animalId;
  final String? animalName;
  final String? animalType;
  final String? caption;
  final CatchTiming timing;
  final String? animalPhotoUrl;
  final String? selfiePhotoUrl;
}
