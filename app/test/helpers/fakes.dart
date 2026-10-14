import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furreal/app/app.dart';
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
import 'package:furreal/features/circles/state/circle_providers.dart';
import 'package:furreal/shared/app_settings.dart';
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
  FakeProfileRepository({Map<String, Profile>? profiles, this.taken = const {}})
    : profiles = profiles ?? {};

  final Map<String, Profile> profiles;
  final Set<String> taken;

  @override
  Future<Profile?> fetchProfile(String userId) async =>
      profiles[userId] ?? Profile(id: userId);

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
}

class FakeCircleRepository implements CircleRepository {
  FakeCircleRepository({List<Circle>? circles}) : circles = circles ?? [];

  final List<Circle> circles;

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

Future<void> pumpApp(
  WidgetTester tester, {
  required FakeAuthRepository auth,
  FakeProfileRepository? profiles,
  FakeCircleRepository? circles,
  List<AuthMethod>? authMethods,
  FakeCatchCamera? camera,
  FakeAreaLocator? area,
  FakeCatchRepository? catches,
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
