import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furreal/features/auth/data/profile_repository.dart';
import 'package:furreal/features/catch_result/data/ai_identification.dart';
import 'package:furreal/features/circles/data/circle_repository.dart';

import 'helpers/fakes.dart';

Future<void> pumpReady(WidgetTester tester, FakeCatchRepository catches) =>
    pumpApp(
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
      catches: catches,
    );

Future<void> toResult(WidgetTester tester) async {
  await tapText(tester, 'buka kamera');
  await tapFinder(tester, find.byKey(const Key('shutter')));
  await tapFinder(tester, find.byKey(const Key('shutter')));
}

Future<void> nameAndPost(WidgetTester tester) async {
  await enter(tester, 'animal-name', 'Milo');
  await tapText(tester, 'posting ke circle');
}

void main() {
  testWidgets('layar loading AI tampil sampai hasil datang', (tester) async {
    final gate = Completer<void>();
    final catches = FakeCatchRepository()..identifyGate = gate;
    await pumpReady(tester, catches);

    await tapText(tester, 'buka kamera');
    await tapFinder(tester, find.byKey(const Key('shutter')));
    await tester.tap(find.byKey(const Key('shutter')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('AI lagi ngenalin hewannya…'), findsOneWidget);
    expect(find.text('kartu kepribadian lagi ditulis'), findsOneWidget);
    expect(find.text('posting ke circle'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('dapet!'), findsOneWidget);
  });

  testWidgets('hasil AI: jenis, persen yakin, kandidat, kartu kepribadian', (
    tester,
  ) async {
    await pumpReady(tester, FakeCatchRepository());
    await toResult(tester);

    expect(find.byKey(const Key('ai-type')), findsOneWidget);
    expect(find.text('kucing'), findsNWidgets(2)); // judul + chip
    expect(find.text('yakin 94%'), findsOneWidget);
    expect(find.text('bukan ini?'), findsOneWidget);
    expect(find.text('musang'), findsOneWidget);
    expect(find.text('lainnya'), findsOneWidget);
    expect(find.text('KARTU KEPRIBADIAN · DITULIS AI'), findsOneWidget);
    expect(find.text(mockKucing.personality!), findsOneWidget);
    expect(find.byKey(const Key('ai-message')), findsNothing);
  });

  testWidgets('koreksi lewat chip kandidat', (tester) async {
    final catches = FakeCatchRepository();
    await pumpReady(tester, catches);
    await toResult(tester);

    await tapText(tester, 'musang');
    expect(find.text('yakin 94%'), findsNothing);
    await nameAndPost(tester);

    expect(catches.submitted.single.animalType, 'musang');
  });

  testWidgets('"lainnya" → isi jenis sendiri', (tester) async {
    final catches = FakeCatchRepository();
    await pumpReady(tester, catches);
    await toResult(tester);

    await tapText(tester, 'lainnya');
    await enter(tester, 'animal-type', '  Luwak ');
    await nameAndPost(tester);

    expect(catches.submitted.single.animalType, 'luwak');
  });

  testWidgets('kartu kepribadian bisa diedit user', (tester) async {
    final catches = FakeCatchRepository();
    await pumpReady(tester, catches);
    await toResult(tester);

    await enter(tester, 'personality', 'raja parkiran, versi gue.');
    await tester.pump();
    expect(
      find.text('KARTU KEPRIBADIAN · DITULIS AI · DIEDIT'),
      findsOneWidget,
    );
    await nameAndPost(tester);

    expect(catches.submitted.single.personality, 'raja parkiran, versi gue.');
    expect(catches.submitted.single.animalType, 'kucing');
  });

  for (final (code, message) in [
    ('rate_limited', 'jatah AI hari ini udah habis. isi jenisnya sendiri ya.'),
    ('timeout', 'AI kelamaan mikir. isi jenisnya sendiri ya.'),
    ('ai_unavailable', 'AI lagi nggak bisa ngenalin. isi jenisnya sendiri ya.'),
  ]) {
    testWidgets(
      'AI gagal ($code) → pesan ramah, isi jenis manual, tetap posting',
      (tester) async {
        final catches = FakeCatchRepository(aiFailure: AiFailure(code));
        await pumpReady(tester, catches);
        await toResult(tester);

        expect(find.text(message), findsOneWidget);
        expect(find.text('bukan ini?'), findsNothing);
        expect(find.text('KARTU KEPRIBADIAN'), findsOneWidget);

        await enter(tester, 'animal-type', 'Kucing');
        await nameAndPost(tester);

        final posted = catches.submitted.single;
        expect(posted.animalType, 'kucing');
        expect(posted.personality, isNull);
        expect(find.text('udah catch\nhari ini!'), findsOneWidget);
      },
    );
  }

  testWidgets('AI tidak menemukan hewan → jenis boleh kosong', (tester) async {
    final catches = FakeCatchRepository(
      ai: const AiIdentification(
        animalType: null,
        confidence: 0,
        candidates: [],
        personality: null,
      ),
    );
    await pumpReady(tester, catches);
    await toResult(tester);

    expect(
      find.text('AI nggak nemu hewan di foto ini. isi jenisnya sendiri ya.'),
      findsOneWidget,
    );
    await nameAndPost(tester);
    expect(catches.submitted.single.animalType, isNull);
  });

  testWidgets('upload gagal → coba lagi → lanjut ke AI', (tester) async {
    final catches = FakeCatchRepository(uploadFailures: 1);
    await pumpReady(tester, catches);
    await toResult(tester);

    expect(find.text('foto belum kesimpen'), findsOneWidget);
    expect(
      find.text('upload foto gagal. cek koneksi lalu coba lagi.'),
      findsOneWidget,
    );
    await tapText(tester, 'coba lagi');

    expect(find.text('yakin 94%'), findsOneWidget);
    expect(catches.identified, ['catch-1']);
  });

  test('AiIdentification.fromJson menolak bentuk yang salah', () {
    final ok = AiIdentification.fromJson({
      'animal_type': 'ayam',
      'confidence': 0.876,
      'candidates': ['ayam', 1],
      'personality': null,
    });
    expect(ok.confidencePercent, 88);
    expect(ok.candidates, ['ayam']);
    for (final bad in [
      null,
      'teks',
      {'animal_type': 1, 'confidence': 0.5, 'candidates': []},
      {'animal_type': 'x', 'confidence': '0.5', 'candidates': []},
      {'animal_type': 'x', 'confidence': 0.5},
    ]) {
      expect(
        () => AiIdentification.fromJson(bad),
        throwsA(
          isA<AiFailure>().having((f) => f.code, 'code', 'invalid_ai_response'),
        ),
      );
    }
  });
}
