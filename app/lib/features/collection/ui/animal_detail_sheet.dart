import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../data/collection_models.dart';
import '../state/collection_providers.dart';
import '../../../shared/transitions.dart';
import '../../../shared/widgets/detail_scaffold.dart';
import 'animal_card.dart';
import 'edit_animal_sheet.dart';

const _months = [
  'jan', 'feb', 'mar', 'apr', 'mei', 'jun', //
  'jul', 'agu', 'sep', 'okt', 'nov', 'des',
];

/// "14 okt 2026" (waktu lokal HP).
String shortDate(DateTime time) {
  final t = time.toLocal();
  return '${t.day} ${_months[t.month - 1]} ${t.year}';
}

Future<void> showAnimalDetail(
  BuildContext context,
  CollectionAnimal animal, {
  int? number,
}) {
  return pushSlide(context, AnimalDetailSheet(animal: animal, number: number));
}

class AnimalDetailSheet extends ConsumerWidget {
  const AnimalDetailSheet({super.key, required this.animal, this.number});

  final CollectionAnimal animal;
  final int? number;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ikuti hasil edit (M15); kalau sudah tidak ada, tampilkan data awal.
    final animal =
        ref
            .watch(collectionProvider)
            .value
            ?.where((a) => a.id == this.animal.id)
            .firstOrNull ??
        this.animal;
    final label = FurrealText.mono(fontSize: 11)
        .copyWith(color: FurrealColors.textSecondary, letterSpacing: 0.5);

    return DetailScaffold(
      title: number == null
          ? 'kartu koleksi'
          : 'kartu #${number.toString().padLeft(4, '0')}',
      child: SingleChildScrollView(
        key: const Key('animal-detail'),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: AnimalCard(
                  data: AnimalCardData.fromAnimal(animal, number: number),
                  interactive: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'geser jari di kartu buat lihat kilaunya',
              textAlign: TextAlign.center,
              style: label,
            ),
            const SizedBox(height: 16),
            Text(animal.name, style: FurrealText.display(fontSize: 30)),
            Text(
              '${animal.animalType ?? 'jenis belum diisi'} · ${animal.kind.label}',
              style: const TextStyle(color: FurrealColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PERTEMUAN', style: label),
                      Text(
                        '${animal.encounterCount}x',
                        style: FurrealText.display(fontSize: 22),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PERTAMA DITEMUI', style: label),
                      Text(
                        shortDate(animal.firstSeenAt),
                        style: FurrealText.display(fontSize: 22),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('animal-edit'),
                    onPressed: () => showEditAnimalSheet(context, animal),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('edit'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('animal-remove'),
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      if (await confirmRemoveAnimal(context, ref, animal)) {
                        navigator.pop();
                      }
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('hapus'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
