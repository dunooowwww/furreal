import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/supabase.dart';
import '../../auth/state/auth_providers.dart';
import '../data/circle_repository.dart';

final circleRepositoryProvider = Provider<CircleRepository>(
  (ref) => SupabaseCircleRepository(ref.watch(supabaseClientProvider)),
);

final myCirclesProvider = FutureProvider<List<Circle>>((ref) async {
  final userId = await ref.watch(authUserIdProvider.future);
  if (userId == null) return const [];
  return ref.watch(circleRepositoryProvider).myCircles();
});
