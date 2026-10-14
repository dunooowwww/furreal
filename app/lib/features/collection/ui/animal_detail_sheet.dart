import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/remote_photo.dart';
import '../data/collection_models.dart';

const _months = [
  'jan', 'feb', 'mar', 'apr', 'mei', 'jun', //
  'jul', 'agu', 'sep', 'okt', 'nov', 'des',
];

/// "14 okt 2026" (waktu lokal HP).
String shortDate(DateTime time) {
  final t = time.toLocal();
  return '${t.day} ${_months[t.month - 1]} ${t.year}';
}

Future<void> showAnimalDetail(BuildContext context, CollectionAnimal animal) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: FurrealColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(FurrealShape.cardRadius),
      ),
      side: BorderSide(
        color: FurrealColors.ink,
        width: FurrealShape.borderWidth,
      ),
    ),
    builder: (_) => AnimalDetailSheet(animal: animal),
  );
}

class AnimalDetailSheet extends ConsumerWidget {
  const AnimalDetailSheet({super.key, required this.animal});

  final CollectionAnimal animal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(remotePhotoBuilderProvider);
    final label = FurrealText.mono(fontSize: 11)
        .copyWith(color: FurrealColors.textSecondary, letterSpacing: 0.5);

    return SingleChildScrollView(
      key: const Key('animal-detail'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              height: 260,
              child: animal.lastPhotoPath == null
                  ? const RemotePhotoPlaceholder()
                  : photo(context, animal.lastPhotoUrl, animal.lastPhotoPath!),
            ),
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
          if (animal.lastPersonality != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F3F3),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('KARTU KEPRIBADIAN TERAKHIR', style: label),
                  const SizedBox(height: 6),
                  Text(
                    animal.lastPersonality!,
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
