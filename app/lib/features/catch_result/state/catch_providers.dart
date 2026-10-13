import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/supabase.dart';
import '../../auth/state/auth_providers.dart';
import '../data/area_locator.dart';
import '../data/catch_repository.dart';
import '../data/photo_compressor.dart';

final photoCompressorProvider = Provider<PhotoCompressor>(
  (ref) => NativePhotoCompressor(),
);

final catchRepositoryProvider = Provider<CatchRepository>(
  (ref) => SupabaseCatchRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(photoCompressorProvider),
  ),
);

final areaLocatorProvider = Provider<AreaLocator>((ref) => GeoAreaLocator());

final todayCatchProvider = FutureProvider<TodayCatch?>((ref) async {
  final userId = await ref.watch(authUserIdProvider.future);
  if (userId == null) return null;
  return ref.watch(catchRepositoryProvider).todayCatch();
});
