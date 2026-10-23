import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furreal/app/app.dart';
import 'package:furreal/features/account/data/account_repository.dart';
import 'package:furreal/features/account/data/avatar_picker.dart';
import 'package:furreal/features/account/state/account_providers.dart';
import 'package:furreal/features/auth/data/auth_repository.dart';
import 'package:furreal/features/auth/data/profile_repository.dart';
import 'package:furreal/features/auth/state/auth_providers.dart';
import 'package:furreal/features/camera/data/captured_photos.dart';
import 'package:furreal/features/camera/data/catch_camera.dart';
import 'package:furreal/features/camera/state/camera_providers.dart';
import 'package:furreal/features/catch_result/data/ai_identification.dart';
import 'package:furreal/features/catch_result/data/area_locator.dart';
import 'package:furreal/features/catch_result/data/catch_repository.dart';
import 'package:furreal/features/catch_result/state/catch_providers.dart';
import 'package:furreal/features/circles/data/circle_repository.dart';
import 'package:furreal/features/collection/data/collection_models.dart';
import 'package:furreal/features/collection/data/collection_repository.dart';
import 'package:furreal/features/collection/state/collection_providers.dart';
import 'package:furreal/features/daily_drop/data/daily_drop.dart';
import 'package:furreal/features/daily_drop/state/daily_drop_providers.dart';
import 'package:furreal/features/notifications/data/push_messaging.dart';
import 'package:furreal/features/notifications/state/notification_providers.dart';
import 'package:furreal/features/circles/state/circle_providers.dart';
import 'package:furreal/features/feed/data/feed_models.dart';
import 'package:furreal/features/feed/data/feed_repository.dart';
import 'package:furreal/features/feed/state/feed_providers.dart';
import 'package:furreal/shared/analytics.dart';
import 'package:furreal/shared/app_settings.dart';
import 'package:furreal/shared/widgets/remote_photo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const validOtp = '123456';
const existingInviteCode = 'KOS234';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.userId});

  final _changes = StreamController<String?>.broadcast();
  String? userId;
  final otpRequests = <String>[];
  final verified = <({String email, String code})>[];

  void _set(String? id) {
    userId = id;
    _changes.add(id);
  }

  @override
  Stream<String?> userIdChanges() async* {
    yield userId;
    yield* _changes.stream;
  }

  @override
  Future<void> sendEmailOtp(String email) async => otpRequests.add(email);

  @override
  Future<void> verifyEmailOtp({
    required String email,
    required String code,
  }) async {
    verified.add((email: email, code: code));
    if (code != validOtp) {
      throw const AuthException(
        'Token has expired or is invalid',
        statusCode: '403',
        code: 'otp_expired',
      );
    }
    _set('user-1');
  }

  @override
  Future<void> signInWithGoogle() async => _set('user-google');

  @override
  Future<void> signOut() async => _set(null);
}

class FakeProfileRepository implements ProfileRepository {
  /// Profil awal dianggap sudah menyetujui pedoman, kecuali [accepted] diisi.
  FakeProfileRepository({
    Map<String, Profile>? profiles,
    this.taken = const {},
    Set<String>? accepted,
  }) : profiles = profiles ?? {},
       accepted = accepted ?? {...?profiles?.keys};

  final Map<String, Profile> profiles;
  final Set<String> taken;
  final Set<String> accepted;

  /// Kalau diisi, acceptGuidelines melempar error ini.
  Object? acceptError;

  /// Foto profil per user (path) dan upload yang terjadi.
  final avatars = <String, String>{};
  final uploads = <Uint8List>[];

  /// Kalau diisi, setAvatar melempar error ini.
  Object? avatarError;

  @override
  Future<Profile?> fetchProfile(String userId) async {
    _current = userId;
    final p = profiles[userId] ?? Profile(id: userId);
    return Profile(
      id: p.id,
      username: p.username,
      displayName: p.displayName,
      avatarPath: avatars[userId],
      guidelinesAcceptedAt: accepted.contains(userId)
          ? DateTime(2026, 10, 14)
          : null,
    );
  }

  String? _current;

  @override
  Future<void> acceptGuidelines() async {
    final error = acceptError;
    if (error != null) throw error;
    // Seperti auth.uid() di server: user yang sedang login.
    accepted.add(_current!);
  }

  @override
  Future<void> saveUsername({
    required String userId,
    required String username,
    required String displayName,
  }) async {
    if (taken.contains(username)) {
      throw const PostgrestException(message: 'duplicate key', code: '23505');
    }
    profiles[userId] = Profile(
      id: userId,
      username: username,
      displayName: displayName,
    );
  }

  @override
  Future<String> setAvatar({
    required String userId,
    required Uint8List jpeg,
  }) async {
    final error = avatarError;
    if (error != null) throw error;
    uploads.add(jpeg);
    return avatars[userId] = '$userId/avatar-${uploads.length}.jpg';
  }

  @override
  Future<void> removeAvatar(String userId) async => avatars.remove(userId);

  @override
  Future<String?> avatarUrl(String path) async => 'https://test/$path';
}

class FakeAvatarPicker implements AvatarPicker {
  FakeAvatarPicker({this.result});

  /// null = user batal memilih.
  Uint8List? result;
  var picks = 0;

  @override
  Future<Uint8List?> pickJpeg() async {
    picks++;
    return result;
  }
}

class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository(this.auth);

  final FakeAuthRepository auth;
  var deletes = 0;

  /// Kalau diisi, deleteAccount melempar error ini.
  Object? error;

  @override
  Future<void> deleteAccount() async {
    deletes++;
    final e = error;
    if (e != null) throw e;
    await auth.signOut();
  }
}

class FakeCircleRepository implements CircleRepository {
  FakeCircleRepository({
    List<Circle>? circles,
    Map<String, List<CircleMember>>? members,
  }) : circles = circles ?? [],
       membersByCircle = members ?? {};

  final List<Circle> circles;
  final Map<String, List<CircleMember>> membersByCircle;
  final left = <String>[];

  /// Kalau diisi, leaveCircle melempar error ini.
  Object? leaveError;

  @override
  Future<List<CircleMember>> members(String circleId) async =>
      membersByCircle[circleId] ??
      const [CircleMember(userId: 'user-1', displayName: 'bob')];

  @override
  Future<void> leaveCircle(String circleId) async {
    final error = leaveError;
    if (error != null) throw error;
    left.add(circleId);
    circles.removeWhere((c) => c.id == circleId);
  }

  @override
  Future<List<Circle>> myCircles() async => List.of(circles);

  @override
  Future<Circle> createCircle(String name) async {
    final circle = Circle(id: 'c-new', name: name, inviteCode: 'ABC789');
    circles.add(circle);
    return circle;
  }

  @override
  Future<Circle> joinCircle(String inviteCode) async {
    if (inviteCode != existingInviteCode) {
      throw const PostgrestException(
        message: 'kode undangan tidak ditemukan',
        code: 'P0002',
      );
    }
    const circle = Circle(
      id: 'c-kos',
      name: 'kos ceria',
      inviteCode: existingInviteCode,
    );
    circles.add(circle);
    return circle;
  }
}

/// PNG 1x1 valid, supaya Image.memory tidak error di test.
final testPhoto = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

class FakeCatchCamera implements CatchCamera {
  FakeCatchCamera({this.denyPermission = false});

  bool denyPermission;
  CameraLens? current;
  final opened = <CameraLens>[];
  final shots = <CameraLens>[];

  @override
  Future<void> open(CameraLens lens) async {
    if (denyPermission) throw const CameraPermissionDenied();
    current = lens;
    opened.add(lens);
  }

  @override
  Widget buildPreview() =>
      ColoredBox(key: Key('preview-${current!.name}'), color: Colors.grey);

  @override
  Future<Uint8List> takePicture() async {
    shots.add(current!);
    return testPhoto;
  }

  @override
  Future<void> setFlashAuto(bool auto) async {}

  @override
  Future<void> dispose() async {}
}

class FakeAreaLocator implements AreaLocator {
  FakeAreaLocator([this.result = const AreaFound('sekitar Depok, Sleman')]);

  final AreaResult result;

  @override
  Future<AreaResult> currentArea() async => result;
}

class FakeCatchRepository implements CatchRepository {
  FakeCatchRepository({
    this.today,
    this.failWith,
    this.uploadFailures = 0,
    AiIdentification? ai,
    this.aiFailure,
  }) : ai = ai ?? mockKucing;

  TodayCatch? today;
  Object? failWith;

  /// Berapa kali prepare() gagal dulu sebelum berhasil.
  int uploadFailures;
  AiIdentification ai;
  AiFailure? aiFailure;

  /// Kalau diisi, identify() menunggu sampai completer ini selesai.
  Completer<void>? identifyGate;

  final prepared = <PreparedCatch>[];
  final identified = <String>[];
  final discarded = <String>[];
  final submitted = <CatchDetails>[];
  var deleted = 0;

  @override
  Future<TodayCatch?> todayCatch() async => today;

  @override
  Future<PreparedCatch> prepare(CapturedPhotos photos) async {
    if (uploadFailures > 0) {
      uploadFailures--;
      throw const StorageException('upload gagal');
    }
    final id = 'catch-${prepared.length + 1}';
    final p = PreparedCatch(
      id: id,
      animalPath: 'u/$id/animal.jpg',
      selfiePath: 'u/$id/selfie.jpg',
    );
    prepared.add(p);
    return p;
  }

  @override
  Future<AiIdentification> identify(PreparedCatch prepared) async {
    identified.add(prepared.id);
    await identifyGate?.future;
    final failure = aiFailure;
    if (failure != null) throw failure;
    return ai;
  }

  @override
  Future<void> discard(PreparedCatch prepared) async =>
      discarded.add(prepared.id);

  @override
  Future<void> submit(PreparedCatch prepared, CatchDetails details) async {
    final failure = failWith;
    if (failure != null) throw failure;
    submitted.add(details);
    today = TodayCatch(
      id: prepared.id,
      animalPhotoPath: prepared.animalPath,
      selfiePhotoPath: prepared.selfiePath,
      animalName: details.animalName,
      kind: details.kind,
      animalType: details.animalType,
    );
  }

  @override
  Future<void> deleteTodayCatch() async {
    deleted++;
    today = null;
  }
}

const mockKucing = AiIdentification(
  animalType: 'kucing',
  confidence: 0.94,
  candidates: ['kucing', 'musang'],
  personality: 'si penjaga parkiran. hobi: tidur di jok motor orang.',
);

class FakeFeedRepository implements FeedRepository {
  FakeFeedRepository({
    Map<String, List<FeedItem>>? feeds,
    Map<String, int>? members,
    Map<String, List<FeedComment>>? comments,
  }) : feeds = feeds ?? {},
       members = members ?? {},
       commentsByCatch = comments ?? {};

  final Map<String, List<FeedItem>> feeds;
  final Map<String, int> members;
  final Map<String, List<FeedComment>> commentsByCatch;

  final feedLoads = <String>[];
  final reactionCalls = <({String catchId, ReactionType type, bool on})>[];
  final added = <({String catchId, String body})>[];
  final deletedComments = <String>[];

  /// Kalau diisi, setReaction menunggu gate lalu melempar error ini.
  Object? reactionError;
  Completer<void>? reactionGate;

  @override
  Future<List<FeedItem>> todayFeed(String circleId) async {
    feedLoads.add(circleId);
    return feeds[circleId] ?? const [];
  }

  @override
  Future<int> memberCount(String circleId) async => members[circleId] ?? 1;

  @override
  Future<void> setReaction(
    String catchId,
    ReactionType type, {
    required bool on,
  }) async {
    reactionCalls.add((catchId: catchId, type: type, on: on));
    await reactionGate?.future;
    final error = reactionError;
    if (error != null) throw error;
  }

  @override
  Future<List<FeedComment>> comments(String catchId) async =>
      List.of(commentsByCatch[catchId] ?? const []);

  @override
  Future<void> addComment(String catchId, String body) async {
    added.add((catchId: catchId, body: body));
    (commentsByCatch[catchId] ??= []).add(
      FeedComment(
        id: 'c-${added.length}',
        displayName: 'bob',
        body: body,
        createdAt: DateTime.now(),
        isMine: true,
      ),
    );
  }

  @override
  Future<void> deleteComment(String commentId) async {
    deletedComments.add(commentId);
    for (final list in commentsByCatch.values) {
      list.removeWhere((c) => c.id == commentId);
    }
  }
}

class FakeCollectionRepository implements CollectionRepository {
  FakeCollectionRepository({
    List<CollectionAnimal>? animals,
    this.streak = Streak.none,
    this.yesterday,
  }) : animals = animals ?? [];

  final List<CollectionAnimal> animals;
  Streak streak;
  YesterdayCatch? yesterday;
  var loads = 0;

  @override
  Future<List<CollectionAnimal>> myCollection() async {
    loads++;
    return List.of(animals);
  }

  @override
  Future<Streak> myStreak() async => streak;

  @override
  Future<YesterdayCatch?> yesterdayCatch() async => yesterday;
}

CollectionAnimal animal({
  required String id,
  required String name,
  String? type,
  AnimalKind kind = AnimalKind.pet,
  int encounters = 1,
  Duration lastSeenAgo = const Duration(days: 1),
  String? personality,
}) => CollectionAnimal(
  id: id,
  name: name,
  kind: kind,
  animalType: type,
  encounterCount: encounters,
  firstSeenAt: DateTime(2026, 9, 1, 12),
  lastSeenAt: DateTime.now().subtract(lastSeenAgo),
  lastPhotoPath: 'u/$id/animal.jpg',
  lastPersonality: personality,
);

class FakeDailyDropRepository implements DailyDropRepository {
  /// Default: drop turun 10 menit lalu (tepat waktu, kamera terbuka).
  FakeDailyDropRepository([DailyDrop? drop])
    : drop =
          drop ??
          DailyDrop(
            sentAt: DateTime.now().subtract(const Duration(minutes: 10)),
          );

  DailyDrop drop;
  var loads = 0;

  @override
  Future<DailyDrop> today() async {
    loads++;
    return drop;
  }
}

DailyDrop dropSentAgo(Duration ago) =>
    DailyDrop(sentAt: DateTime.now().subtract(ago));

class FakePushMessaging implements PushMessaging {
  FakePushMessaging({
    this.current = PushPermission.denied,
    this.afterRequest = PushPermission.granted,
    this.deviceToken = 'tok-hp',
  });

  PushPermission current;
  PushPermission afterRequest;
  String? deviceToken;
  var requests = 0;
  final refreshes = StreamController<String>.broadcast();
  final drops = StreamController<DropMessage>.broadcast();

  @override
  Future<PushPermission> permission() async => current;

  @override
  Future<PushPermission> requestPermission() async {
    requests++;
    return current = afterRequest;
  }

  @override
  Future<String?> token() async => deviceToken;

  @override
  Stream<String> get tokenRefreshes => refreshes.stream;

  @override
  Stream<DropMessage> get dropMessages => drops.stream;
}

class FakePushTokenRepository implements PushTokenRepository {
  final saved = <String?>[];

  @override
  Future<void> save(String? token) async => saved.add(token);
}

class FakeAnalytics implements Analytics {
  final events = <String>[];

  @override
  Future<void> catchCreated({
    required String encounter,
    required String timing,
  }) async => events.add('catch_created encounter=$encounter timing=$timing');

  @override
  Future<void> reactionAdded({required String type}) async =>
      events.add('reaction_added type=$type');

  @override
  Future<void> circleJoined({required String method}) async =>
      events.add('circle_joined method=$method');
}

/// Foto palsu untuk test (tanpa jaringan): kotak abu-abu ber-key path.
Widget fakeRemotePhoto(BuildContext context, String? url, String cacheKey) =>
    ColoredBox(key: Key('photo-$cacheKey'), color: Colors.grey);

Future<void> pumpApp(
  WidgetTester tester, {
  required FakeAuthRepository auth,
  FakeProfileRepository? profiles,
  FakeCircleRepository? circles,
  List<AuthMethod>? authMethods,
  FakeCatchCamera? camera,
  FakeAreaLocator? area,
  FakeCatchRepository? catches,
  FakeFeedRepository? feed,
  FakeCollectionRepository? collection,
  FakeDailyDropRepository? drop,
  FakePushMessaging? push,
  FakePushTokenRepository? pushTokens,
  FakeAnalytics? analytics,
  FakeAccountRepository? account,
  FakeAvatarPicker? avatarPicker,
  VoidCallback? onOpenSettings,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(
          profiles ?? FakeProfileRepository(),
        ),
        circleRepositoryProvider.overrideWithValue(
          circles ?? FakeCircleRepository(),
        ),
        catchCameraFactoryProvider.overrideWithValue(
          () => camera ?? FakeCatchCamera(),
        ),
        areaLocatorProvider.overrideWithValue(area ?? FakeAreaLocator()),
        catchRepositoryProvider.overrideWithValue(
          catches ?? FakeCatchRepository(),
        ),
        feedRepositoryProvider.overrideWithValue(feed ?? FakeFeedRepository()),
        collectionRepositoryProvider.overrideWithValue(
          collection ?? FakeCollectionRepository(),
        ),
        dailyDropRepositoryProvider.overrideWithValue(
          drop ?? FakeDailyDropRepository(),
        ),
        // Tanpa detak per detik: pumpAndSettle tidak menunggu timer.
        clockProvider.overrideWith((ref) => const Stream.empty()),
        pushMessagingProvider.overrideWithValue(
          push ?? FakePushMessaging(current: PushPermission.granted),
        ),
        pushTokenRepositoryProvider.overrideWithValue(
          pushTokens ?? FakePushTokenRepository(),
        ),
        analyticsProvider.overrideWithValue(analytics ?? FakeAnalytics()),
        accountRepositoryProvider.overrideWithValue(
          account ?? FakeAccountRepository(auth),
        ),
        avatarPickerProvider.overrideWithValue(
          avatarPicker ?? FakeAvatarPicker(),
        ),
        remotePhotoBuilderProvider.overrideWithValue(fakeRemotePhoto),
        openAppSettingsProvider.overrideWithValue(() async {
          onOpenSettings?.call();
          return true;
        }),
        if (authMethods != null)
          enabledAuthMethodsProvider.overrideWithValue(authMethods),
      ],
      child: const FurrealApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) =>
    tapFinder(tester, find.text(text));

/// Gulir layar sampai [finder] dirender (ListView hanya membangun yang terlihat).
Future<void> reveal(WidgetTester tester, Finder finder) async {
  final scrollable = find.byType(Scrollable);
  if (finder.evaluate().isEmpty && scrollable.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(finder, 200, scrollable: scrollable.first);
  }
}

Future<void> tapFinder(WidgetTester tester, Finder finder) async {
  await reveal(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pump(); // terapkan posisi scroll sebelum tap
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String text) async {
  final finder = find.byKey(Key(key));
  await reveal(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.enterText(finder, text);
}
