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
import 'package:furreal/features/camera/data/catch_camera.dart';
import 'package:furreal/features/camera/state/camera_providers.dart';
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
  FakeCatchRepository({this.today, this.failWith});

  TodayCatch? today;
  Object? failWith;
  final submitted = <NewCatch>[];
  var deleted = 0;

  @override
  Future<TodayCatch?> todayCatch() async => today;

  @override
  Future<void> submit(NewCatch newCatch) async {
    final failure = failWith;
    if (failure != null) throw failure;
    submitted.add(newCatch);
    today = TodayCatch(
      id: 'catch-1',
      animalPhotoPath: 'u/catch-1/animal.jpg',
      selfiePhotoPath: 'u/catch-1/selfie.jpg',
      animalName: newCatch.animalName,
      kind: newCatch.kind,
    );
  }

  @override
  Future<void> deleteTodayCatch() async {
    deleted++;
    today = null;
  }
}

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

Future<void> tapFinder(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String text) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.enterText(finder, text);
}
