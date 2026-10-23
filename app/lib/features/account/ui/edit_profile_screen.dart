import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../shared/errors.dart';
import '../../../shared/widgets/busy_button.dart';
import '../../../shared/widgets/error_text.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/data/profile_repository.dart';
import '../../auth/state/auth_providers.dart';
import '../state/account_providers.dart';

/// Edit profil: foto (dari galeri), nama tampilan, username.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _username = TextEditingController();
  final _displayName = TextEditingController();
  bool _filled = false;
  bool _saving = false;
  bool _photoBusy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _displayName.dispose();
    super.dispose();
  }

  String? get _userId => ref.read(authUserIdProvider).value;

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _changePhoto() async {
    final userId = _userId;
    if (userId == null) return;
    setState(() => _photoBusy = true);
    try {
      final jpeg = await ref.read(avatarPickerProvider).pickJpeg();
      if (jpeg == null) return; // batal memilih
      await ref
          .read(profileRepositoryProvider)
          .setAvatar(userId: userId, jpeg: jpeg);
      ref.invalidate(myProfileProvider);
      if (mounted) _snack('foto profil diganti.');
    } catch (_) {
      if (mounted) _snack('gagal ganti foto. cek koneksi lalu coba lagi.');
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto() async {
    final userId = _userId;
    if (userId == null) return;
    setState(() => _photoBusy = true);
    try {
      await ref.read(profileRepositoryProvider).removeAvatar(userId);
      ref.invalidate(myProfileProvider);
      if (mounted) _snack('foto profil dihapus.');
    } catch (_) {
      if (mounted) _snack('gagal hapus foto. coba lagi ya.');
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _save() async {
    final username = _username.text.trim().toLowerCase();
    final displayName = _displayName.text.trim();
    if (!usernamePattern.hasMatch(username)) {
      setState(
        () => _error = 'username 3–20 karakter: huruf kecil, angka, _ atau .',
      );
      return;
    }
    if (displayName.isEmpty || displayName.length > 40) {
      setState(() => _error = 'nama tampilan 1–40 karakter.');
      return;
    }
    final userId = _userId;
    if (userId == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(profileRepositoryProvider)
          .saveUsername(
            userId: userId,
            username: username,
            displayName: displayName,
          );
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      _snack('profil disimpan.');
      if (context.canPop()) context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider).value;
    if (profile != null && !_filled) {
      _filled = true;
      _username.text = profile.username ?? '';
      _displayName.text = profile.displayName ?? '';
    }
    final name = profile?.displayName ?? profile?.username ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('edit profil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  UserAvatar(
                    key: const Key('edit-avatar'),
                    name: name,
                    avatarPath: profile?.avatarPath,
                    size: 112,
                  ),
                  if (_photoBusy)
                    const SizedBox.square(
                      dimension: 112,
                      child: CircularProgressIndicator(
                        color: FurrealColors.ink,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('change-photo'),
                  onPressed: _photoBusy ? null : _changePhoto,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: Text(
                    profile?.avatarPath == null ? 'pilih foto' : 'ganti foto',
                  ),
                ),
                if (profile?.avatarPath != null)
                  TextButton(
                    key: const Key('remove-photo'),
                    onPressed: _photoBusy ? null : _removePhoto,
                    child: const Text('hapus foto'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              key: const Key('edit-display-name'),
              controller: _displayName,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'nama tampilan'),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('edit-username'),
              controller: _username,
              autocorrect: false,
              maxLength: 20,
              decoration: const InputDecoration(
                labelText: 'username',
                prefixText: '@',
                helperText: 'huruf kecil, angka, _ atau .',
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            BusyButton(label: 'simpan', busy: _saving, onPressed: _save),
            ErrorText(_error),
          ],
        ),
      ),
    );
  }
}
