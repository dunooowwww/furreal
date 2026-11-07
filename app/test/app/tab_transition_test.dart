import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furreal/app/theme.dart';
import 'package:furreal/features/auth/data/profile_repository.dart';
import 'package:furreal/features/circles/data/circle_repository.dart';
import 'package:furreal/features/collection/ui/collection_screen.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets('pindah tab: halaman baru berlatar penuh, halaman lama hilang', (
    tester,
  ) async {
    await pumpApp(
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
    );
    await tester.tap(find.text('koleksi').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Di tengah animasi: koleksi (yang aslinya transparan) dibungkus latar
    // penuh, jadi beranda di bawahnya tidak tembus.
    final backdrop = find.ancestor(
      of: find.byType(CollectionScreen),
      matching: find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == FurrealColors.background,
      ),
    );
    expect(backdrop, findsWidgets);

    await tester.pumpAndSettle();
    expect(find.text('halo, bob'), findsNothing);
    expect(find.byType(CollectionScreen), findsOneWidget);
  });
}
