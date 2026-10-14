import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/remote_photo.dart';
import '../../catch_result/data/catch_repository.dart' show AnimalKind;
import '../data/collection_models.dart';
import '../state/collection_providers.dart';
import 'animal_detail_sheet.dart';

/// Koleksi hewan (prototype "Koleksi"). Rarity & musim di luar MVP (PRD §9).
class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref.watch(collectionProvider);
    final streak = ref.watch(streakProvider).value ?? Streak.none;
    final filter = ref.watch(collectionFilterProvider);

    Future<void> refresh() async {
      ref.invalidate(collectionProvider);
      ref.invalidate(streakProvider);
      await ref.read(collectionProvider.future);
    }

    return RefreshIndicator(
      onRefresh: refresh,
      color: FurrealColors.ink,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          Text('koleksi', style: FurrealText.display(fontSize: 30)),
          const SizedBox(height: 18),
          switch (collection) {
            AsyncData(:final value) => _buildBody(
              context,
              ref,
              value,
              streak,
              filter,
            ),
            AsyncError() => const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Text(
                'koleksi gagal dimuat. tarik ke bawah buat coba lagi.',
                textAlign: TextAlign.center,
              ),
            ),
            _ => const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
          },
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    List<CollectionAnimal> animals,
    Streak streak,
    AnimalKind? filter,
  ) {
    final types = animals.map((a) => a.animalType).whereType<String>().toSet();
    final shown = [
      for (final a in animals)
        if (filter == null || a.kind == filter) a,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _Stat(
                key: const Key('stat-animals'),
                value: animals.length,
                label: 'hewan',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Stat(
                key: const Key('stat-types'),
                value: types.length,
                label: 'jenis',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Stat(
                key: const Key('stat-streak'),
                value: streak.current,
                label: 'hari streak',
                highlight: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (kind, label) in [
              (null, 'semua'),
              (AnimalKind.pet, AnimalKind.pet.label),
              (AnimalKind.wild, AnimalKind.wild.label),
            ])
              _FilterPill(
                label: label,
                selected: filter == kind,
                onTap: () =>
                    ref.read(collectionFilterProvider.notifier).set(kind),
              ),
          ],
        ),
        const SizedBox(height: 18),
        if (animals.isEmpty)
          const _Empty(
            title: 'koleksi lo masih kosong',
            subtitle: 'catch hewan pertama lo hari ini, nanti muncul di sini.',
          )
        else if (shown.isEmpty)
          _Empty(
            title: 'belum ada hewan ${filter?.label ?? ''}',
            subtitle: 'coba filter lain dulu.',
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 248,
            ),
            itemCount: shown.length,
            itemBuilder: (context, i) => _AnimalCard(
              animal: shown[i],
              onTap: () => showAnimalDetail(context, shown[i]),
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    super.key,
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final int value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? FurrealColors.accent : FurrealColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: FurrealColors.ink,
          width: FurrealShape.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: FurrealText.display(fontSize: 28)),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: highlight
                  ? FurrealColors.ink
                  : FurrealColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: OutlinedButton(
        key: Key('filter-$label'),
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, FurrealShape.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          backgroundColor: selected ? FurrealColors.ink : Colors.white,
          foregroundColor: selected ? Colors.white : FurrealColors.ink,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}

class _AnimalCard extends ConsumerWidget {
  const _AnimalCard({required this.animal, required this.onTap});

  final CollectionAnimal animal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(remotePhotoBuilderProvider);
    return Card(
      key: Key('animal-${animal.id}'),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(
          color: FurrealColors.ink,
          width: FurrealShape.borderWidth,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 140,
              child: animal.lastPhotoPath == null
                  ? const RemotePhotoPlaceholder()
                  : photo(context, animal.lastPhotoUrl, animal.lastPhotoPath!),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    animal.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FurrealText.display(fontSize: 18)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    animal.animalType ?? 'jenis belum diisi',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: FurrealColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ketemu ${animal.encounterCount}x · ${animal.kind.label}',
                    style: FurrealText.mono(fontSize: 11)
                        .copyWith(color: FurrealColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          const Icon(Icons.pets, size: 40, color: FurrealColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: FurrealText.display(fontSize: 22),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: FurrealColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
