import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AccountRepository {
  /// Hapus akun yang sedang login beserta semua data & fotonya, lalu keluar.
  Future<void> deleteAccount();
}

class SupabaseAccountRepository implements AccountRepository {
  SupabaseAccountRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> deleteAccount() async {
    await _client.functions.invoke('delete-account');
    // Akunnya sudah tidak ada di server: cukup buang sesi di HP.
    await _client.auth.signOut(scope: SignOutScope.local);
  }
}
