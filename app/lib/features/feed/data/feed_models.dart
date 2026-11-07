import '../../daily_drop/data/daily_drop.dart';

enum ReactionType {
  like('like', '❤️', 'suka'),
  laugh('laugh', '😂', 'lucu'),
  cute('cute', '😻', 'gemes'),
  fire('fire', '🔥', 'keren'),
  aww('aww', '🥺', 'kasian');

  const ReactionType(this.dbValue, this.emoji, this.label);
  final String dbValue;
  final String emoji;
  final String label;

  static ReactionType? fromDb(String? value) =>
      values.where((t) => t.dbValue == value).firstOrNull;
}

/// Satu kartu catch di feed (hasil RPC `circle_feed` + signed URL foto).
class FeedItem {
  const FeedItem({
    required this.catchId,
    required this.userId,
    required this.displayName,
    required this.createdAt,
    required this.isLate,
    required this.lateMinutes,
    this.timing,
    required this.animalName,
    required this.animalType,
    required this.encounterCount,
    required this.caption,
    required this.animalPhotoPath,
    required this.selfiePhotoPath,
    required this.likeCount,
    required this.laughCount,
    required this.commentCount,
    required this.likedByMe,
    required this.laughedByMe,
    this.locked = false,
    this.avatarPath,
    this.animalPhotoUrl,
    this.selfiePhotoUrl,
    this.extraCounts = const {},
    this.extraMine = const {},
  });

  factory FeedItem.fromJson(
    Map<String, dynamic> json, {
    Map<String, String> signedUrls = const {},
  }) {
    final animalPath = json['animal_photo_path'] as String?;
    final selfiePath = json['selfie_photo_path'] as String?;
    return FeedItem(
      catchId: json['catch_id'] as String,
      userId: json['user_id'] as String,
      displayName:
          (json['display_name'] as String?) ??
          (json['username'] as String?) ??
          'seseorang',
      createdAt: DateTime.parse(json['created_at'] as String),
      isLate: json['is_late'] as bool? ?? false,
      timing: CatchTiming.fromDb(
        json['timing'] as String?,
        isLate: json['is_late'] as bool? ?? false,
      ),
      lateMinutes: json['late_minutes'] as int?,
      animalName: json['animal_name'] as String?,
      animalType: json['animal_type'] as String?,
      encounterCount: json['encounter_count'] as int? ?? 1,
      caption: json['caption'] as String?,
      animalPhotoPath: animalPath,
      selfiePhotoPath: selfiePath,
      likeCount: json['like_count'] as int? ?? 0,
      laughCount: json['laugh_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      likedByMe: json['liked_by_me'] as bool? ?? false,
      laughedByMe: json['laughed_by_me'] as bool? ?? false,
      locked: json['locked'] as bool? ?? false,
      avatarPath: json['avatar_path'] as String?,
      animalPhotoUrl: signedUrls[animalPath],
      selfiePhotoUrl: signedUrls[selfiePath],
      // Feed v5 (M17): reaksi selain suka & lucu.
      extraCounts: {
        for (final MapEntry(:key, :value)
            in ((json['reaction_counts'] as Map<String, dynamic>?) ?? {})
                .entries)
          if (ReactionType.fromDb(key) case final t?)
            if (t != ReactionType.like && t != ReactionType.laugh)
              t: (value as num).toInt(),
      },
      extraMine: {
        for (final v in (json['my_reactions'] as List?) ?? const [])
          if (ReactionType.fromDb(v as String?) case final t?)
            if (t != ReactionType.like && t != ReactionType.laugh) t,
      },
    );
  }

  final String catchId;
  final String userId;
  final String displayName;
  final DateTime createdAt;
  final bool isLate;

  /// Label waktu dari server (M10). null di data lama → ikut [isLate].
  final CatchTiming? timing;

  CatchTiming get timingLabel =>
      timing ?? (isLate ? CatchTiming.late : CatchTiming.onTime);
  final int? lateMinutes;
  final String? animalName;
  final String? animalType;
  final int encounterCount;

  /// Caption manual dari pemilik catch (M12). Kepribadian AI hanya di koleksi.
  final String? caption;

  /// null kalau [locked].
  final String? animalPhotoPath;
  final String? selfiePhotoPath;
  final int likeCount;
  final int laughCount;
  final int commentCount;
  final bool likedByMe;
  final bool laughedByMe;

  /// Catch teman hari ini yang belum boleh dilihat karena saya belum catch
  /// (ala BeReal). Isinya dikosongkan oleh server.
  final bool locked;

  /// Foto profil pemilik catch (bucket avatars).
  final String? avatarPath;
  final String? animalPhotoUrl;
  final String? selfiePhotoUrl;

  /// Hitungan & reaksi saya untuk jenis selain suka & lucu (M17).
  final Map<ReactionType, int> extraCounts;
  final Set<ReactionType> extraMine;

  bool reactedByMe(ReactionType type) => switch (type) {
    ReactionType.like => likedByMe,
    ReactionType.laugh => laughedByMe,
    _ => extraMine.contains(type),
  };

  int reactionCount(ReactionType type) => switch (type) {
    ReactionType.like => likeCount,
    ReactionType.laugh => laughCount,
    _ => extraCounts[type] ?? 0,
  };

  /// Pasang/lepas reaksi saya, beserta hitungannya.
  FeedItem withReaction(ReactionType type, bool on) {
    if (reactedByMe(type) == on) return this;
    final delta = on ? 1 : -1;
    return _copy(
      likeCount: type == ReactionType.like ? likeCount + delta : likeCount,
      laughCount: type == ReactionType.laugh ? laughCount + delta : laughCount,
      likedByMe: type == ReactionType.like ? on : likedByMe,
      laughedByMe: type == ReactionType.laugh ? on : laughedByMe,
      extraCounts: type == ReactionType.like || type == ReactionType.laugh
          ? null
          : {...extraCounts, type: reactionCount(type) + delta},
      extraMine: type == ReactionType.like || type == ReactionType.laugh
          ? null
          : (on ? {...extraMine, type} : ({...extraMine}..remove(type))),
    );
  }

  FeedItem withCommentCount(int count) => _copy(commentCount: count);

  FeedItem _copy({
    int? likeCount,
    int? laughCount,
    int? commentCount,
    bool? likedByMe,
    bool? laughedByMe,
    Map<ReactionType, int>? extraCounts,
    Set<ReactionType>? extraMine,
  }) => FeedItem(
    catchId: catchId,
    userId: userId,
    displayName: displayName,
    createdAt: createdAt,
    isLate: isLate,
    timing: timing,
    lateMinutes: lateMinutes,
    animalName: animalName,
    animalType: animalType,
    encounterCount: encounterCount,
    caption: caption,
    animalPhotoPath: animalPhotoPath,
    selfiePhotoPath: selfiePhotoPath,
    likeCount: likeCount ?? this.likeCount,
    laughCount: laughCount ?? this.laughCount,
    commentCount: commentCount ?? this.commentCount,
    likedByMe: likedByMe ?? this.likedByMe,
    laughedByMe: laughedByMe ?? this.laughedByMe,
    locked: locked,
    avatarPath: avatarPath,
    animalPhotoUrl: animalPhotoUrl,
    selfiePhotoUrl: selfiePhotoUrl,
    extraCounts: extraCounts ?? this.extraCounts,
    extraMine: extraMine ?? this.extraMine,
  );
}

class FeedComment {
  const FeedComment({
    required this.id,
    required this.displayName,
    required this.body,
    required this.createdAt,
    required this.isMine,
    this.avatarPath,
  });

  factory FeedComment.fromJson(Map<String, dynamic> json) => FeedComment(
    id: json['id'] as String,
    displayName:
        (json['display_name'] as String?) ??
        (json['username'] as String?) ??
        'seseorang',
    body: json['body'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    avatarPath: json['avatar_path'] as String?,
    isMine: json['is_mine'] as bool? ?? false,
  );

  final String id;
  final String displayName;
  final String body;
  final DateTime createdAt;
  final bool isMine;
  final String? avatarPath;
}

const commentMaxLength = 300;
