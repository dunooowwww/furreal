import '../../catch_result/data/catch_repository.dart' show AnimalKind;

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
  });

  factory CollectionAnimal.fromJson(
    Map<String, dynamic> json, {
    Map<String, String> signedUrls = const {},
  }) {
    final path = json['last_animal_photo_path'] as String?;
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
