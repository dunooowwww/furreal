import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/errors.dart';
import '../../circles/state/circle_providers.dart';
import '../../collection/state/collection_providers.dart';
import '../../feed/state/feed_providers.dart';
import '../data/catch_repository.dart';
import '../state/catch_providers.dart';

/// Edit nama hewan & caption catch hari ini (M13).
Future<void> showEditCatchSheet(BuildContext context, TodayCatch today) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => EditCatchSheet(today: today),
  );
}

/// Konfirmasi lalu hapus catch hari ini (M13). Hasil: true kalau terhapus.
Future<bool> confirmDeleteTodayCatch(
  BuildContext context,
  WidgetRef ref,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('hapus catch hari ini?'),
      content: const Text(
        'foto & caption-nya hilang dari feed, dan streak dihitung ulang. '
        'lo bisa catch lagi hari ini.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('batal'),
        ),
        TextButton(
          key: const Key('confirm-delete-catch'),
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('hapus'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(catchRepositoryProvider).deleteTodayCatch();
    refreshAfterCatchChange(ref);
    messenger.showSnackBar(
      const SnackBar(content: Text('catch hari ini dihapus.')),
    );
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    return false;
  }
}

/// Muat ulang semua yang bergantung pada catch hari ini.
void refreshAfterCatchChange(WidgetRef ref) {
  ref.invalidate(todayCatchProvider);
  for (final p in catchDerivedProviders) {
    ref.invalidate(p);
  }
  for (final circle in ref.read(myCirclesProvider).value ?? const []) {
    ref.invalidate(feedControllerProvider(circle.id));
  }
}

class EditCatchSheet extends ConsumerStatefulWidget {
  const EditCatchSheet({super.key, required this.today});

  final TodayCatch today;

  @override
  ConsumerState<EditCatchSheet> createState() => _EditCatchSheetState();
}

class _EditCatchSheetState extends ConsumerState<EditCatchSheet> {
  late final _name = TextEditingController(text: widget.today.animalName);
  late final _caption = TextEditingController(text: widget.today.caption);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _caption.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'nama hewan nggak boleh kosong.');
      return;
    }
    final caption = _caption.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(catchRepositoryProvider)
          .editTodayCatch(
            animalName: name,
            caption: caption.isEmpty ? null : caption,
          );
      refreshAfterCatchChange(ref);
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('catch diperbarui.')),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('edit catch', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            key: const Key('edit-animal-name'),
            controller: _name,
            maxLength: animalNameMaxLength,
            decoration: const InputDecoration(
              labelText: 'nama hewan',
              counterText: '',
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'nama berlaku untuk hewan ini di koleksi juga.',
            style: TextStyle(color: FurrealColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('edit-caption'),
            controller: _caption,
            maxLength: captionMaxLength,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'caption (opsional)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(
              _error!,
              key: const Key('edit-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('edit-save'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'menyimpan…' : 'simpan'),
          ),
        ],
      ),
    );
  }
}
