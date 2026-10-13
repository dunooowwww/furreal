import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:furreal/features/catch_result/data/area_locator.dart';
import 'package:furreal/shared/dates.dart';
import 'package:furreal/shared/uuid.dart';

void main() {
  group('uuidV4', () {
    test('format UUID v4 yang valid', () {
      final pattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      for (var i = 0; i < 100; i++) {
        expect(uuidV4(), matches(pattern));
      }
    });

    test('acak', () {
      expect(uuidV4(Random(1)), isNot(uuidV4(Random(2))));
    });
  });

  group('jakartaToday', () {
    test('17:00 UTC sudah besoknya di Jakarta', () {
      final d = jakartaToday(DateTime.utc(2026, 10, 13, 17));
      expect(isoDate(d), '2026-10-14');
    });

    test('16:59 UTC masih hari yang sama', () {
      final d = jakartaToday(DateTime.utc(2026, 10, 13, 16, 59));
      expect(isoDate(d), '2026-10-13');
    });
  });

  group('formatAreaLabel', () {
    test('buang awalan kecamatan/kabupaten', () {
      expect(
        formatAreaLabel(
          district: 'Kecamatan Depok',
          regency: 'Kabupaten Sleman',
        ),
        'sekitar Depok, Sleman',
      );
    });

    test('nama sama tidak diulang', () {
      expect(
        formatAreaLabel(district: 'Kota Yogyakarta', regency: 'Yogyakarta'),
        'sekitar Yogyakarta',
      );
    });

    test('hanya satu bagian', () {
      expect(formatAreaLabel(regency: 'Kab. Bantul'), 'sekitar Bantul');
    });

    test('kosong → null', () {
      expect(formatAreaLabel(district: '  ', regency: null), isNull);
    });
  });
}
