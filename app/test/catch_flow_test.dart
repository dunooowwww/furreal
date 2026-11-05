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
  expect(find.text('dapet!'), findsOneWidget);
}

void main() {
  testWidgets('kamera: pilih "lo dulu" → selfie dulu (depan), hewan otomatis', (
    tester,
  ) async {
    final camera = FakeCatchCamera();
    final catches = FakeCatchRepository();
    await pumpReadyApp(tester, camera: camera, catches: catches);
    await tapText(tester, 'buka kamera');

    await tapFinder(tester, find.byKey(const Key('order-selfieFirst')));
    expect(find.text('1/2 · foto lo'), findsOneWidget);
    expect(find.byKey(const Key('preview-front')), findsOneWidget);
    expect(
      find.text('siapin muka lo. abis itu hewannya kejepret otomatis'),
      findsOneWidget,
    );
    await tapFinder(tester, find.byKey(const Key('shutter')));

    expect(camera.shots, [CameraLens.front, CameraLens.back]);
    final photos = catches.capturedPhotos.single;
    expect(photos.selfie, testPhotoFront, reason: 'foto pertama = selfie');
    expect(photos.animal, testPhoto);
    expect(find.text('dapet!'), findsOneWidget);
  });

  testWidgets(
    'kamera: ganti kamera sebelum jepret, foto kedua pakai kamera satunya',
    (tester) async {
      final camera = FakeCatchCamera();
      await pumpReadyApp(tester, camera: camera);
      await tapText(tester, 'buka kamera');

      await tapFinder(tester, find.byTooltip('ganti kamera'));
      expect(find.byKey(const Key('preview-front')), findsOneWidget);
      await tapFinder(tester, find.byKey(const Key('shutter')));
      expect(camera.shots, [CameraLens.front, CameraLens.back]);
      expect(find.text('dapet!'), findsOneWidget);
    },
  );

  testWidgets(
    'kamera: 1 tap → foto hewan lalu selfie otomatis → hasil → posting',
    (tester) async {
      final camera = FakeCatchCamera();
      final catches = FakeCatchRepository();
      await pumpReadyApp(tester, camera: camera, catches: catches);

      await tapText(tester, 'buka kamera');

      // default: hewan dulu, kamera belakang
      expect(find.text('1/2 · foto hewan'), findsOneWidget);
      expect(find.text('galeri off'), findsOneWidget);
      expect(find.byKey(const Key('preview-back')), findsOneWidget);
      expect(
        find.text('arahin ke hewan. abis itu selfie lo kejepret otomatis'),
        findsOneWidget,
      );
      await tapFinder(tester, find.byKey(const Key('shutter')));

      // sekali tap: belakang lalu depan, otomatis
      expect(camera.shots, [CameraLens.back, CameraLens.front]);
      expect(camera.opened, [CameraLens.back, CameraLens.front]);
      final photos = catches.capturedPhotos.single;
      expect(photos.animal, testPhoto, reason: 'foto pertama = hewan');
      expect(photos.selfie, testPhotoFront);

      // layar hasil
      expect(find.text('dapet!'), findsOneWidget);
      expect(find.byKey(const Key('result-animal-photo')), findsOneWidget);
      expect(find.byKey(const Key('result-selfie-photo')), findsOneWidget);
      await reveal(
        tester,
        find.text('sekitar Depok, Sleman · lokasi disamarkan'),
      );
      expect(
        find.text('sekitar Depok, Sleman · lokasi disamarkan'),
        findsOneWidget,
      );

      await postToCircle(tester);
      expect(find.text('kasih nama dulu hewannya.'), findsOneWidget);
      expect(catches.submitted, isEmpty);

      await enter(tester, 'animal-name', '  Milo ');
      await enter(tester, 'caption', '  ketemu di parkiran  ');
      await tapText(tester, 'liar');
      await postToCircle(tester);

      final posted = catches.submitted.single;
      expect(posted.animalName, 'Milo');
      expect(posted.kind, AnimalKind.wild);
      expect(posted.areaLabel, 'sekitar Depok, Sleman');
      expect(posted.locationHidden, isFalse);
      // AI dipanggil sekali untuk foto yang sudah ter-upload
      expect(catches.prepared.single.id, 'catch-1');
      expect(catches.identified, ['catch-1']);
      expect(posted.animalType, 'kucing');
      expect(posted.personality, mockKucing.personality);
      expect(
        posted.caption,
        'ketemu di parkiran',
        reason: 'caption feed dirapikan',
      );
      expect(catches.discarded, isEmpty);

      // kembali ke beranda dengan status sudah catch
      expect(find.text('catch terposting ke circle!'), findsOneWidget);
      expect(find.text('CATCH HARI INI · BERES'), findsOneWidget);
      expect(find.text('Milo'), findsOneWidget);
      expect(find.text('kucing · liar'), findsOneWidget);
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
    await postToCircle(tester);

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

    await reveal(
      tester,
      find.text('izin lokasi ditolak · lokasi disembunyikan'),
    );
    expect(
      find.text('izin lokasi ditolak · lokasi disembunyikan'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('hide-location')), findsNothing);
    await enter(tester, 'animal-name', 'Kiko');
    await postToCircle(tester);

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
    await postToCircle(tester);

    expect(
      find.text('kamu udah catch hari ini. besok lagi ya!'),
      findsOneWidget,
    );
    // tetap di layar hasil, belum diposting
    expect(find.text('posting ke circle'), findsOneWidget);
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

  testWidgets('foto ulang membuang foto yang sudah ter-upload', (tester) async {
    final catches = FakeCatchRepository();
    await pumpReadyApp(tester, catches: catches);
    await captureBoth(tester);
    await tapFinder(tester, find.byTooltip('foto ulang'));
    expect(catches.discarded, ['catch-1']);
    expect(catches.submitted, isEmpty);
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

    expect(find.text('peliharaan'), findsOneWidget);
    expect(find.byKey(const Key('today-animal')), findsOneWidget);
    await tapText(tester, 'hapus catch hari ini (debug)');
    expect(catches.deleted, 1);
    expect(find.text('buka kamera'), findsOneWidget);
  });
}
