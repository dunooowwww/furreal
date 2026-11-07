import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furreal/features/auth/data/profile_repository.dart';
import 'package:furreal/features/catch_result/data/catch_repository.dart';
import 'package:furreal/features/circles/data/circle_repository.dart';

import 'helpers/fakes.dart';
import 'share_feedback_test.dart' show feedItem;

const kos = Circle(id: 'kos', name: 'kos', inviteCode: 'KSM234');

Future<void> openFeed(WidgetTester tester) async {
  await pumpApp(
    tester,
    auth: FakeAuthRepository(userId: 'user-1'),
    profiles: FakeProfileRepository(
      profiles: {
        'user-1': const Profile(
          id: 'user-1',
          username: 'bob',
          displayName: 'Bob',
        ),
      },
    ),
    circles: FakeCircleRepository(circles: [kos]),
    catches: FakeCatchRepository(
      today: const TodayCatch(
        id: 'mine',
        animalPhotoPath: 'a',
        selfiePhotoPath: 's',
        animalName: 'Milo',
        kind: AnimalKind.pet,
      ),
    ),
    feed: FakeFeedRepository(
      feeds: {
        'kos': [feedItem(id: 'dinda', userId: 'u-dinda')],
      },
    ),
  );
  await tester.tap(find.text('feed').last);
  await tester.pumpAndSettle();
}

Finder inKey(String key, String photoPath) => find.descendant(
  of: find.byKey(Key(key)),
  matching: find.byKey(Key('photo-$photoPath')),
);

void main() {
  const animal = 'u-dinda/dinda/animal.jpg';
  const selfie = 'u-dinda/dinda/selfie.jpg';

  testWidgets('tap foto kecil → foto hewan & selfie bertukar', (tester) async {
    await openFeed(tester);
    expect(inKey('photo-main-dinda', animal), findsOneWidget);
    expect(inKey('photo-inset-dinda', selfie), findsOneWidget);

    await tapFinder(tester, find.byKey(const Key('photo-inset-dinda')));
    expect(inKey('photo-main-dinda', selfie), findsOneWidget);
    expect(inKey('photo-inset-dinda', animal), findsOneWidget);

    await tapFinder(tester, find.byKey(const Key('photo-inset-dinda')));
    expect(inKey('photo-main-dinda', animal), findsOneWidget);
  });

  testWidgets('tahan foto besar → layar penuh, bisa tukar & tutup', (
    tester,
  ) async {
    await openFeed(tester);
    await tester.longPress(find.byKey(const Key('photo-main-dinda')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('photo-viewer')), findsOneWidget);
    expect(find.byKey(const Key('viewer-main-$animal')), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tapFinder(tester, find.byKey(const Key('viewer-inset')));
    expect(find.byKey(const Key('viewer-main-$selfie')), findsOneWidget);

    await tapFinder(tester, find.byKey(const Key('viewer-close')));
    expect(find.byKey(const Key('photo-viewer')), findsNothing);
    expect(find.byKey(const Key('photo-main-dinda')), findsOneWidget);
  });
}
