import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/supabase.dart';
import '../../auth/state/auth_providers.dart';
import '../data/daily_drop.dart';

final dailyDropRepositoryProvider = Provider<DailyDropRepository>(
  (ref) => SupabaseDailyDropRepository(ref.watch(supabaseClientProvider)),
);

/// Daily drop hari ini. Dimuat ulang saat notifikasi masuk, app dibuka lagi,
/// atau beranda ditarik ke bawah.
final todayDropProvider = FutureProvider<DailyDrop>((ref) async {
  final userId = await ref.watch(authUserIdProvider.future);
  if (userId == null) return DailyDrop.waiting;
  return ref.watch(dailyDropRepositoryProvider).today();
});

/// Jam sekarang, berdetak tiap detik selama ada yang menonton (hitung mundur).
/// Di test di-override supaya tidak ada timer yang terus berjalan.
final clockProvider = StreamProvider.autoDispose<DateTime>(
  (ref) => Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
);

/// Waktu sekarang untuk UI: detak terakhir dari [clockProvider].
DateTime watchNow(WidgetRef ref) =>
    ref.watch(clockProvider).value ?? DateTime.now();

/// Waktu sekarang untuk UI daily drop. Berdetak tiap detik hanya selama fase
/// tepat-waktu (hitung mundur tampil); di fase lain tanpa timer.
DateTime watchDropClock(WidgetRef ref, DailyDrop? drop) {
  final now = DateTime.now();
  return drop?.phaseAt(now) == DropPhase.onTime ? watchNow(ref) : now;
}
