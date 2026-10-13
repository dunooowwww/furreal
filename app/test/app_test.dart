import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furreal/app/app.dart';

void main() {
  testWidgets('app jalan dan menampilkan beranda placeholder', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FurrealApp()));
    await tester.pumpAndSettle();

    expect(find.text('furreal'), findsOneWidget);
    expect(find.text('segera hadir. siap-siap catch!'), findsOneWidget);
  });
}
