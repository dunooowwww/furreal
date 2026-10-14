enum ReactionType {
  like('like'),
  laugh('laugh');

  const ReactionType(this.dbValue);
  final String dbValue;
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
    required this.animalName,
    required this.animalType,
    required this.encounterCount,
    required this.personality,
    required this.animalPhotoPath,
    required this.selfiePhotoPath,
    required this.likeCount,
    required this.laughCount,
    required this.commentCount,
    required this.likedByMe,
    required this.laughedByMe,
    this.animalPhotoUrl,
    this.selfiePhotoUrl,
  });

  factory FeedItem.fromJson(
    Map<String, dynamic> json, {
    Map<String, String> signedUrls = const {},
  }) {
    final animalPath = json['animal_photo_path'] as String;
    final selfiePath = json['selfie_photo_path'] as String;
    return FeedItem(
      catchId: json['catch_id'] as String,
      userId: json['user_id'] as String,
      displayName:
          (json['display_name'] as String?) ??
          (json['username'] as String?) ??
          'seseorang',
      createdAt: DateTime.parse(json['created_at'] as String),
      isLate: json['is_late'] as bool? ?? false,
      lateMinutes: json['late_minutes'] as int?,
      animalName: json['animal_name'] as String?,
      animalType: json['animal_type'] as String?,
      encounterCount: json['encounter_count'] as int? ?? 1,
      personality: json['personality'] as String?,
      animalPhotoPath: animalPath,
      selfiePhotoPath: selfiePath,
      likeCount: json['like_count'] as int? ?? 0,
      laughCount: json['laugh_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      likedByMe: json['liked_by_me'] as bool? ?? false,
      laughedByMe: json['laughed_by_me'] as bool? ?? false,
      animalPhotoUrl: signedUrls[animalPath],
      selfiePhotoUrl: signedUrls[selfiePath],
    );
  }

  final String catchId;
  final String userId;
  final String displayName;
  final DateTime createdAt;
  final bool isLate;
  final int? lateMinutes;
  final String? animalName;
  final String? animalType;
  final int encounterCount;
  final String? personality;
  final String animalPhotoPath;
  final String selfiePhotoPath;
  final int likeCount;
  final int laughCount;
  final int commentCount;
  final bool likedByMe;
  final bool laughedByMe;
  final String? animalPhotoUrl;
  final String? selfiePhotoUrl;

  bool reactedByMe(ReactionType type) =>
      type == ReactionType.like ? likedByMe : laughedByMe;

  int reactionCount(ReactionType type) =>
      type == ReactionType.like ? likeCount : laughCount;

  /// Pasang/lepas reaksi saya, beserta hitungannya.
  FeedItem withReaction(ReactionType type, bool on) {
    if (reactedByMe(type) == on) return this;
    final delta = on ? 1 : -1;
    return _copy(
      likeCount: type == ReactionType.like ? likeCount + delta : likeCount,
      laughCount: type == ReactionType.laugh ? laughCount + delta : laughCount,
      likedByMe: type == ReactionType.like ? on : likedByMe,
      laughedByMe: type == ReactionType.laugh ? on : laughedByMe,
    );
  }

  FeedItem withCommentCount(int count) => _copy(commentCount: count);

  FeedItem _copy({
    int? likeCount,
    int? laughCount,
    int? commentCount,
    bool? likedByMe,
    bool? laughedByMe,
  }) => FeedItem(
    catchId: catchId,
    userId: userId,
    displayName: displayName,
    createdAt: createdAt,
    isLate: isLate,
    lateMinutes: lateMinutes,
    animalName: animalName,
    animalType: animalType,
    encounterCount: encounterCount,
    personality: personality,
    animalPhotoPath: animalPhotoPath,
    selfiePhotoPath: selfiePhotoPath,
    likeCount: likeCount ?? this.likeCount,
    laughCount: laughCount ?? this.laughCount,
    commentCount: commentCount ?? this.commentCount,
    likedByMe: likedByMe ?? this.likedByMe,
    laughedByMe: laughedByMe ?? this.laughedByMe,
    animalPhotoUrl: animalPhotoUrl,
    selfiePhotoUrl: selfiePhotoUrl,
  );
}

class FeedComment {
  const FeedComment({
    required this.id,
    required this.displayName,
    required this.body,
    required this.createdAt,
    required this.isMine,
  });

  factory FeedComment.fromJson(Map<String, dynamic> json) => FeedComment(
    id: json['id'] as String,
    displayName:
        (json['display_name'] as String?) ??
        (json['username'] as String?) ??
        'seseorang',
    body: json['body'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    isMine: json['is_mine'] as bool? ?? false,
  );

  final String id;
  final String displayName;
  final String body;
  final DateTime createdAt;
  final bool isMine;
}

const commentMaxLength = 300;
