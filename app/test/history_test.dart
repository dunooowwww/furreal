import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furreal/features/collection/data/collection_models.dart';
import 'package:furreal/features/collection/data/collection_repository.dart';
import 'package:furreal/features/collection/ui/history_view.dart';
import 'package:furreal/features/daily_drop/data/daily_drop.dart';

import 'collection_test.dart' show openCollection, pumpHome;
import 'helpers/fakes.dart';

HistoryCatch historyCatch(String id, DateTime date, {String? caption}) =>
    HistoryCatch(
      id: id,
      catchDate: date,
      createdAt: date.add(const Duration(hours: 10)),
      animalPhotoPath: 'u/$id/animal.jpg',
      selfiePhotoPath: 'u/$id/selfie.jpg',
      animalName: 'Milo',
      animalType: 'kucing',
      caption: caption,
      timing: CatchTiming.late,
    );

void main() {
  testWidgets('tab riwayat: catch per hari dikelompokkan per bulan', (
    tester,
  ) async {
    final repo = FakeCollectionRepository()
      ..history = [
        historyCatch('c3', DateTime.utc(2026, 11, 7), caption: 'nunggu jatah'),
        historyCatch('c2', DateTime.utc(2026, 11, 2)),
        historyCatch('c1', DateTime.utc(2026, 10, 30)),
      ];
    await pumpHome(tester, collection: repo);
    await openCollection(tester);
    expect(find.byKey(const Key('history-c3')), findsNothing);

    await tapFinder(tester, find.byKey(const Key('tab-history')));
    expect(find.text('3 hari catch'), findsOneWidget);
    expect(find.text('NOVEMBER 2026'), findsOneWidget);
    expect(find.text('OKTOBER 2026'), findsOneWidget);
    expect(find.byKey(const Key('history-more')), findsNothing);

    await tapFinder(tester, find.byKey(const Key('history-c3')));
    final detail = find.byKey(const Key('history-detail'));
    expect(detail, findsOneWidget);
    expect(
      find.descendant(of: detail, matching: find.text('nunggu jatah')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: detail,
        matching: find.text('sabtu, 7 nov 2026 · kucing · telat'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: detail,
        matching: find.byKey(const Key('photo-u/c3/selfie.jpg')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('riwayat kosong', (tester) async {
    await pumpHome(tester, collection: FakeCollectionRepository());
    await openCollection(tester);
    await tapFinder(tester, find.byKey(const Key('tab-history')));
    expect(find.text('riwayat lo masih kosong'), findsOneWidget);
  });

  testWidgets('muat lagi memuat halaman berikutnya', (tester) async {
    final start = DateTime.utc(2026, 11, 7);
    final repo = FakeCollectionRepository()
      ..history = [
        for (var i = 0; i < historyPageSize + 5; i++)
          historyCatch('c$i', start.subtract(Duration(days: i))),
      ];
    await pumpHome(tester, collection: repo);
    await openCollection(tester);
    await tapFinder(tester, find.byKey(const Key('tab-history')));
    expect(find.text('$historyPageSize+ hari catch'), findsOneWidget);

    await tapFinder(tester, find.byKey(const Key('history-more')));
    expect(find.text('${historyPageSize + 5} hari catch'), findsOneWidget);
    expect(repo.historyQueries.last, start.subtract(const Duration(days: 29)));
    expect(find.byKey(const Key('history-more')), findsNothing);
  });

  test('label bulan', () {
    expect(monthLabel(DateTime(2026, 1, 3)), 'januari 2026');
  });

  group('hapus & bagikan dari riwayat', () {
    Future<(FakeCatchRepository, FakeCollectionRepository)> openDetail(
      WidgetTester tester,
    ) async {
      final history = [
        historyCatch('c2', DateTime.utc(2026, 11, 7), caption: 'nunggu jatah'),
        historyCatch('c1', DateTime.utc(2026, 11, 2)),
      ];
      final collection = FakeCollectionRepository()..history = history;
      final catches = FakeCatchRepository()..history = history;
      await pumpHome(tester, collection: collection, catches: catches);
      await openCollection(tester);
      await tapFinder(tester, find.byKey(const Key('tab-history')));
      await tapFinder(tester, find.byKey(const Key('history-c2')));
      return (catches, collection);
    }

    testWidgets('bagikan → gambar dibuat dari foto catch itu', (tester) async {
      composedShares.clear();
      await openDetail(tester);
      await tapFinder(tester, find.byKey(const Key('history-share')));
      expect(find.byKey(const Key('share-preview')), findsOneWidget);
      expect(composedShares, [(animalName: 'Milo', caption: 'nunggu jatah')]);
    });

    testWidgets('hapus perlu konfirmasi, lalu hilang dari riwayat', (
      tester,
    ) async {
      final (catches, _) = await openDetail(tester);
      await tapFinder(tester, find.byKey(const Key('history-delete')));
      expect(find.text('hapus catch 7 nov 2026?'), findsOneWidget);
      await tapText(tester, 'batal');
      expect(catches.deletedIds, isEmpty);

      await tapFinder(tester, find.byKey(const Key('history-delete')));
      await tapFinder(tester, find.byKey(const Key('confirm-delete-history')));
      expect(catches.deletedIds, ['c2']);
      expect(find.byKey(const Key('history-detail')), findsNothing);
      expect(find.byKey(const Key('history-c2')), findsNothing);
      expect(find.text('1 hari catch'), findsOneWidget);
      expect(find.text('catch dihapus.'), findsOneWidget);
    });
  });

  testWidgets('detail riwayat: tombol kembali menutup halaman', (tester) async {
    final repo = FakeCollectionRepository()
      ..history = [historyCatch('c1', DateTime.utc(2026, 11, 2))];
    await pumpHome(tester, collection: repo);
    await openCollection(tester);
    await tapFinder(tester, find.byKey(const Key('tab-history')));
    await tapFinder(tester, find.byKey(const Key('history-c1')));
    expect(find.byKey(const Key('history-detail')), findsOneWidget);

    await tapFinder(tester, find.byKey(const Key('detail-back')));
    expect(find.byKey(const Key('history-detail')), findsNothing);
    expect(find.byKey(const Key('history-c1')), findsOneWidget);
  });
}
