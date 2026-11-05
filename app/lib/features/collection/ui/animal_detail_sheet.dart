import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../data/collection_models.dart';
import 'animal_card.dart';

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
    builder: (_) => AnimalDetailSheet(animal: animal, number: number),
  );
}

class AnimalDetailSheet extends StatelessWidget {
  const AnimalDetailSheet({super.key, required this.animal, this.number});

  final CollectionAnimal animal;
  final int? number;

  @override
  Widget build(BuildContext context) {
    final label = FurrealText.mono(fontSize: 11)
        .copyWith(color: FurrealColors.textSecondary, letterSpacing: 0.5);

    return SingleChildScrollView(
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
        ],
      ),
    );
  }
}
