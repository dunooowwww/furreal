import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furreal/features/auth/data/profile_repository.dart';
import 'package:furreal/features/camera/data/catch_camera.dart';
import 'package:furreal/features/catch_result/data/area_locator.dart';
import 'package:furreal/features/catch_result/data/catch_repository.dart';
import 'package:furreal/features/circles/data/circle_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/fakes.dart';

Future<void> pumpReadyApp(
  WidgetTester tester, {
  FakeCatchCamera? camera,
  FakeAreaLocator? area,
  FakeCatchRepository? catches,
  VoidCallback? onOpenSettings,
}) => pumpApp(
  tester,
  auth: FakeAuthRepository(userId: 'user-1'),
  profiles: FakeProfileRepository(
    profiles: {
      'user-1': const Profile(
        id: 'user-1',
        username: 'bob',
        displayName: 'bob',
      ),
    },
  ),
  circles: FakeCircleRepository(
    circles: [const Circle(id: 'c', name: 'lab', inviteCode: 'LAB234')],
  ),
  camera: camera,
  area: area,
  catches: catches,
  onOpenSettings: onOpenSettings,
);

/// Dari beranda sampai layar hasil, tanpa ganti kamera.
Future<void> captureBoth(WidgetTester tester) async {
  await tapText(tester, 'buka kamera');
  await tapFinder(tester, find.byKey(const Key('shutter')));
  await tapFinder(tester, find.byKey(const Key('shutter')));
  expect(find.text('dapet!'), findsOneWidget);
}

void main() {
  testWidgets(
    'kamera → hasil → posting, dengan ganti kamera di kedua langkah',
    (tester) async {
      final camera = FakeCatchCamera();
      final catches = FakeCatchRepository();
      await pumpReadyApp(tester, camera: camera, catches: catches);

      await tapText(tester, 'buka kamera');

      // langkah 1: default kamera belakang, user ganti ke depan
      expect(find.text('1/2 · foto hewan'), findsOneWidget);
      expect(find.text('galeri off'), findsOneWidget);
      expect(find.byKey(const Key('preview-back')), findsOneWidget);
      await tapFinder(tester, find.byTooltip('ganti kamera'));
      expect(find.byKey(const Key('preview-front')), findsOneWidget);
      await tapFinder(tester, find.byKey(const Key('shutter')));

      // langkah 2: default kamera depan, user ganti ke belakang
      expect(find.text('2/2 · foto lo'), findsOneWidget);
      expect(camera.current, CameraLens.front);
      expect(find.byKey(const Key('animal-thumbnail')), findsOneWidget);
      await tapFinder(tester, find.byTooltip('ganti kamera'));
      expect(find.byKey(const Key('preview-back')), findsOneWidget);
      await tapFinder(tester, find.byKey(const Key('shutter')));

      expect(camera.shots, [CameraLens.front, CameraLens.back]);
      expect(camera.opened, [
        CameraLens.back,
        CameraLens.front,
        CameraLens.front,
        CameraLens.back,
      ]);

      // layar hasil
      expect(find.text('dapet!'), findsOneWidget);
      expect(find.byKey(const Key('result-animal-photo')), findsOneWidget);
      expect(find.byKey(const Key('result-selfie-photo')), findsOneWidget);
      expect(
        find.text('sekitar Depok, Sleman · lokasi disamarkan'),
        findsOneWidget,
      );

      await tapText(tester, 'posting ke circle');
      expect(find.text('kasih nama dulu hewannya.'), findsOneWidget);
      expect(catches.submitted, isEmpty);

      await enter(tester, 'animal-name', '  Milo ');
      await tapText(tester, 'liar');
      await tapText(tester, 'posting ke circle');

      final posted = catches.submitted.single;
      expect(posted.animalName, 'Milo');
      expect(posted.kind, AnimalKind.wild);
      expect(posted.areaLabel, 'sekitar Depok, Sleman');
      expect(posted.locationHidden, isFalse);
      expect(posted.animalPhoto, isNotEmpty);
      expect(posted.selfiePhoto, isNotEmpty);

      // kembali ke beranda dengan status sudah catch
      expect(find.text('catch terposting ke circle!'), findsOneWidget);
      expect(find.text('udah catch\nhari ini!'), findsOneWidget);
      expect(find.text('Milo · liar'), findsOneWidget);
      expect(find.text('buka kamera'), findsNothing);
    },
  );

  testWidgets('toggle sembunyikan → tanpa area_label', (tester) async {
    final catches = FakeCatchRepository();
    await pumpReadyApp(tester, catches: catches);
    await captureBoth(tester);

    await tapFinder(tester, find.byKey(const Key('hide-location')));
    expect(find.text('lokasi disembunyikan'), findsOneWidget);
    await enter(tester, 'animal-name', 'Mochi');
    await tapText(tester, 'posting ke circle');

    expect(catches.submitted.single.areaLabel, isNull);
    expect(catches.submitted.single.locationHidden, isTrue);
    expect(catches.submitted.single.kind, AnimalKind.pet);
  });

  testWidgets('izin lokasi ditolak → tetap bisa posting tanpa lokasi', (
    tester,
  ) async {
    final catches = FakeCatchRepository();
    await pumpReadyApp(
      tester,
      catches: catches,
      area: FakeAreaLocator(const AreaDenied()),
    );
    await captureBoth(tester);

    expect(
      find.text('izin lokasi ditolak · lokasi disembunyikan'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('hide-location')), findsNothing);
    await enter(tester, 'animal-name', 'Kiko');
    await tapText(tester, 'posting ke circle');

    expect(catches.submitted.single.areaLabel, isNull);
    expect(catches.submitted.single.locationHidden, isTrue);
  });

  testWidgets('catch kedua hari ini ditolak dengan pesan jelas', (
    tester,
  ) async {
    await pumpReadyApp(
      tester,
      catches: FakeCatchRepository(
        failWith: const PostgrestException(
          message: 'sudah catch hari ini',
          code: 'FR001',
        ),
      ),
    );
    await captureBoth(tester);
    await enter(tester, 'animal-name', 'Milo');
    await tapText(tester, 'posting ke circle');

    expect(
      find.text('kamu udah catch hari ini. besok lagi ya!'),
      findsOneWidget,
    );
    expect(find.text('dapet!'), findsOneWidget);
  });

  testWidgets('izin kamera ditolak → penjelasan + buka pengaturan', (
    tester,
  ) async {
    var settingsOpened = 0;
    final camera = FakeCatchCamera(denyPermission: true);
    await pumpReadyApp(
      tester,
      camera: camera,
      onOpenSettings: () => settingsOpened++,
    );
    await tapText(tester, 'buka kamera');

    expect(find.text('butuh izin kamera'), findsOneWidget);
    expect(find.byKey(const Key('shutter')), findsNothing);
    await tapText(tester, 'buka pengaturan');
    expect(settingsOpened, 1);

    // setelah izin diberikan, coba lagi membuka kamera
    camera.denyPermission = false;
    await tapText(tester, 'coba lagi');
    expect(find.text('1/2 · foto hewan'), findsOneWidget);

    await tapFinder(tester, find.byTooltip('tutup kamera'));
    expect(find.text('buka kamera'), findsOneWidget);
  });

  testWidgets('foto ulang dari layar hasil kembali ke langkah 1', (
    tester,
  ) async {
    await pumpReadyApp(tester);
    await captureBoth(tester);
    await tapFinder(tester, find.byTooltip('foto ulang'));
    expect(find.text('1/2 · foto hewan'), findsOneWidget);
  });

  testWidgets('debug: hapus catch hari ini supaya bisa catch lagi', (
    tester,
  ) async {
    final catches = FakeCatchRepository(
      today: const TodayCatch(
        id: 'catch-1',
        animalPhotoPath: 'a',
        selfiePhotoPath: 's',
        animalName: 'Milo',
        kind: AnimalKind.pet,
      ),
    );
    await pumpReadyApp(tester, catches: catches);

    expect(find.text('Milo · peliharaan'), findsOneWidget);
    await tapText(tester, 'hapus catch hari ini (debug)');
    expect(catches.deleted, 1);
    expect(find.text('buka kamera'), findsOneWidget);
  });
}
