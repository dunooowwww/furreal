import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/errors.dart';
import '../../catch_result/data/catch_repository.dart';
import '../../catch_result/ui/edit_catch_sheet.dart'
    show refreshAfterCatchChange;
import '../data/collection_models.dart';
import '../state/collection_providers.dart';

/// Edit nama, peliharaan/liar, jenis, dan kepribadian kartu (M15).
Future<void> showEditAnimalSheet(
  BuildContext context,
  CollectionAnimal animal,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useRootNavigator: true,
    builder: (_) => EditAnimalSheet(animal: animal),
  );
}

/// Konfirmasi lalu hapus hewan dari koleksi (catch tetap ada). True = terhapus.
Future<bool> confirmRemoveAnimal(
  BuildContext context,
  WidgetRef ref,
  CollectionAnimal animal,
) async {
  final ok = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (context) => AlertDialog(
      title: Text('hapus ${animal.name} dari koleksi?'),
      content: const Text(
        'kartunya hilang dari koleksi. catch & fotonya tetap ada di riwayat '
        'dan feed, streak lo nggak berubah.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('batal'),
        ),
        TextButton(
          key: const Key('confirm-remove-animal'),
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
    await ref.read(collectionRepositoryProvider).removeAnimal(animal.id);
    ref.invalidate(collectionProvider);
    messenger.showSnackBar(
      SnackBar(content: Text('${animal.name} dihapus dari koleksi.')),
    );
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    return false;
  }
}

class EditAnimalSheet extends ConsumerStatefulWidget {
  const EditAnimalSheet({super.key, required this.animal});

  final CollectionAnimal animal;

  @override
  ConsumerState<EditAnimalSheet> createState() => _EditAnimalSheetState();
}

class _EditAnimalSheetState extends ConsumerState<EditAnimalSheet> {
  late final _name = TextEditingController(text: widget.animal.name);
  late final _type = TextEditingController(text: widget.animal.animalType);
  late final _personality = TextEditingController(
    text: widget.animal.lastPersonality,
  );
  late AnimalKind _kind = widget.animal.kind;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _type.dispose();
    _personality.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'nama hewan nggak boleh kosong.');
      return;
    }
    final type = _type.text.trim().toLowerCase();
    final personality = _personality.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(collectionRepositoryProvider)
          .editAnimal(
            widget.animal.id,
            name: name,
            kind: _kind,
            animalType: type.isEmpty ? null : type,
            personality: personality.isEmpty ? null : personality,
          );
      // Nama/jenis juga tampil di beranda & feed.
      refreshAfterCatchChange(ref);
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('kartu diperbarui.')),
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
    return SingleChildScrollView(
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
          Text('edit kartu', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            key: const Key('animal-edit-name'),
            controller: _name,
            maxLength: animalNameMaxLength,
            decoration: const InputDecoration(
              labelText: 'nama hewan',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<AnimalKind>(
            key: const Key('animal-edit-kind'),
            segments: [
              for (final k in AnimalKind.values)
                ButtonSegment(value: k, label: Text(k.label)),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('animal-edit-type'),
            controller: _type,
            maxLength: animalTypeMaxLength,
            decoration: const InputDecoration(
              labelText: 'jenis hewan',
              hintText: 'mis. kucing',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('animal-edit-personality'),
            controller: _personality,
            maxLength: personalityMaxLength,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'kepribadian',
              helperText:
                  'kalimat pertama jadi tagline kartu. kosongin buat '
                  'pakai kepribadian dari catch terakhir.',
              helperMaxLines: 2,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(
              _error!,
              key: const Key('animal-edit-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('animal-edit-save'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'menyimpan…' : 'simpan'),
          ),
        ],
      ),
    );
  }
}
