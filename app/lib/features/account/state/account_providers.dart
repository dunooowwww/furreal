import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/supabase.dart';
import '../data/account_repository.dart';
import '../data/avatar_picker.dart';

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => SupabaseAccountRepository(ref.watch(supabaseClientProvider)),
);

final avatarPickerProvider = Provider<AvatarPicker>(
  (ref) => GalleryAvatarPicker(),
);
