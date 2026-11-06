import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furreal/app/session.dart';
import 'package:furreal/app/splash_overlay.dart';
import 'package:furreal/app/splash_screen.dart';
import 'package:furreal/app/theme.dart';

Future<void> pumpSplash(
  WidgetTester tester,
  Future<SessionStatus> Function() status,
) => tester.pumpWidget(
  ProviderScope(
    overrides: [sessionStatusProvider.overrideWith((ref) => status())],
    child: const MaterialApp(home: SplashScreen()),
  ),
);

void main() {
  testWidgets('splash: latar aksen + tapak + logo, sama dengan splash native', (
    tester,
  ) async {
    await pumpSplash(tester, () => Completer<SessionStatus>().future);

    final scaffold = tester.widget<Scaffold>(find.byKey(const Key('splash')));
    expect(scaffold.backgroundColor, FurrealColors.accent);
    expect(find.byIcon(Icons.pets), findsOneWidget);
    expect(find.text('furreal'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('splash: gagal memuat → tombol coba lagi', (tester) async {
    await pumpSplash(tester, () async => throw Exception('offline'));
    await tester.pump();

    expect(
      find.text('gagal memuat. cek koneksi lalu coba lagi.'),
      findsOneWidget,
    );
    expect(find.text('coba lagi'), findsOneWidget);
  });

  testWidgets('splash animasi menutupi app sebentar lalu hilang', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) => SplashOverlay(child: child!),
          home: const Scaffold(body: Text('beranda')),
        ),
      ),
    );
    expect(find.byKey(const Key('splash-overlay')), findsOneWidget);
    expect(find.text('beranda'), findsOneWidget, reason: 'app jalan di bawah');

    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byKey(const Key('splash-overlay')), findsOneWidget);
    expect(find.text('furreal'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('splash-overlay')), findsNothing);
    expect(find.text('beranda'), findsOneWidget);
  });
}
