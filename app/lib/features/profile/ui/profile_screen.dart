import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/config.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../shared/errors.dart';
import '../../../shared/widgets/remote_photo.dart';
import '../../auth/state/auth_providers.dart';
import '../../collection/data/collection_models.dart';
import '../../collection/state/collection_providers.dart';
import '../../collection/ui/animal_card.dart';
import '../../collection/ui/animal_detail_sheet.dart';
import '../../collection/ui/history_view.dart';
import '../../feed/state/feed_providers.dart';
import '../../friends/data/friend_repository.dart';
import '../../friends/state/friend_providers.dart';
import '../../friends/ui/friend_action_button.dart';

/// Profil ala BeReal (M19). [userId] null = profil sendiri (tombol teman &
/// pengaturan di kanan atas); selain itu profil teman / anggota satu circle.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(authUserIdProvider).value;
    final own = userId == null || userId == myId;
    return Scaffold(
      backgroundColor: FurrealColors.background,
      body: own ? const _OwnProfile() : _OtherProfile(userId: userId!),
    );
  }
}

/// Data yang ditampilkan di profil (sendiri atau orang lain).
class _ProfileData {
  const _ProfileData({
    required this.name,
    required this.username,
    required this.avatarPath,
    required this.streak,
    required this.stats,
  });

  final String name;
  final String username;
  final String? avatarPath;
  final int streak;
  final String stats;
}

class _OwnProfile extends ConsumerWidget {
  const _OwnProfile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value;
    final streak = ref.watch(streakProvider).value ?? Streak.none;
    final animals = ref.watch(collectionProvider).value ?? const [];
    final friends = ref.watch(myFriendsProvider).value ?? const [];
    final history = ref.watch(catchHistoryProvider);
    final pinned = ref.watch(pinnedAnimalsProvider);
    final numbers = ref.watch(collectionNumbersProvider);
    final incoming = ref.watch(incomingRequestCountProvider);
    final friendCount = friends
        .where((f) => f.relation == FriendRelation.friend)
        .length;
    final name = profile?.displayName ?? profile?.username ?? '';

    Future<void> refresh() async {
      ref.invalidate(myProfileProvider);
      ref.invalidate(myFriendsProvider);
      for (final p in catchDerivedProviders) {
        ref.invalidate(p);
      }
      await ref.read(collectionProvider.future);
    }

    Future<void> share() async {
      final username = profile?.username;
      if (username == null) return;
      final link = AppConfig.inviteLink.trim();
      try {
        await ref
            .read(catchSharerProvider)
            .shareText(
              [
                'tambahin gue jadi teman di furreal: @$username 🐾',
                '(buka furreal → profil → ikon tambah teman → cari @$username)',
                if (link.isNotEmpty) 'download app: $link',
              ].join('\n'),
            );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(friendlyError(e))));
        }
      }
    }

    return RefreshIndicator(
      onRefresh: refresh,
      color: FurrealColors.ink,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Header(
              data: _ProfileData(
                name: name,
                username: profile?.username ?? '',
                avatarPath: profile?.avatarPath,
                streak: streak.current,
                stats:
                    '$friendCount teman · ${animals.length} hewan · '
                    '${streak.longest} streak terlama',
              ),
              actions: [
                _HeaderIcon(
                  key: const Key('profile-friends'),
                  tooltip: 'teman',
                  icon: Icons.person_add_alt_1_outlined,
                  badge: incoming > 0,
                  onTap: () => context.push(Routes.friends),
                ),
                _HeaderIcon(
                  key: const Key('profile-settings'),
                  tooltip: 'pengaturan',
                  icon: Icons.settings_outlined,
                  onTap: () => context.push(Routes.settings),
                ),
              ],
              below: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('profile-share'),
                      onPressed: share,
                      icon: const Icon(Icons.ios_share, size: 18),
                      label: const Text('bagikan profil'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    key: const Key('profile-edit'),
                    tooltip: 'edit profil',
                    onPressed: () => context.push(Routes.editProfile),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _Pins(
              pinned: pinned,
              numbers: numbers,
              onOpen: (a) =>
                  showAnimalDetail(context, a, number: numbers[a.id]),
              onAdd: () => _pickPin(context, ref, animals, numbers),
            ),
          ),
          ..._catchesSlivers(
            context,
            title: 'catch lo',
            items: history.value?.items,
            failed: history.hasError,
            onOpen: (c) => showHistoryDetail(context, c),
          ),
        ],
      ),
    );
  }
}

class _OtherProfile extends ConsumerWidget {
  const _OtherProfile({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider(userId));
    final collection = ref.watch(userCollectionProvider(userId));
    final catches = ref.watch(userCatchesProvider(userId));

    Future<void> refresh() async {
      refreshFriends(ref, userId);
      await ref.read(userProfileProvider(userId).future);
    }

    return switch (profile) {
      AsyncData(value: final p?) => RefreshIndicator(
        onRefresh: refresh,
        color: FurrealColors.ink,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                data: _ProfileData(
                  name: p.name,
                  username: p.username,
                  avatarPath: p.avatarPath,
                  streak: p.streak,
                  stats:
                      '${p.friendCount} teman · ${p.animalCount} hewan · '
                      '${p.catchCount} catch',
                ),
                actions: const [],
                below: Align(
                  alignment: Alignment.centerLeft,
                  child: FriendActionButton(
                    userId: p.id,
                    name: p.name,
                    relation: p.relation,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Builder(
                builder: (context) {
                  final animals = collection.value ?? const [];
                  final numbers = collectionNumbers(animals);
                  final pinned = [
                    for (final a in animals)
                      if (a.pinned) a,
                  ]..sort((a, b) => a.pinnedAt!.compareTo(b.pinnedAt!));
                  return _Pins(
                    pinned: pinned,
                    numbers: numbers,
                    onOpen: (a) => showAnimalDetail(
                      context,
                      a,
                      number: numbers[a.id],
                      readOnly: true,
                    ),
                  );
                },
              ),
            ),
            ..._catchesSlivers(
              context,
              title: 'catch ${p.name}',
              items: catches.value,
              failed: catches.hasError,
              onOpen: (c) => showHistoryDetail(context, c, readOnly: true),
            ),
          ],
        ),
      ),
      AsyncData() => const _Unavailable(),
      AsyncError() => const _Unavailable(failed: true),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({this.failed = false});

  final bool failed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BackButton(),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  failed ? 'profil gagal dimuat. coba lagi nanti.' : 'profil ini cuma bisa dilihat teman atau anggota satu circle.',
                  key: const Key('profile-unavailable'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Foto profil besar + gradasi, streak, nama, @username, lalu statistik dan
/// tombol di bawahnya.
class _Header extends ConsumerWidget {
  const _Header({
    required this.data,
    required this.actions,
    required this.below,
  });

  final _ProfileData data;
  final List<Widget> actions;
  final Widget below;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = data.avatarPath;
    final url = path == null ? null : ref.watch(avatarUrlProvider(path)).value;
    final photo = ref.watch(remotePhotoBuilderProvider);
    final initial = data.name.isEmpty
        ? '?'
        : data.name.characters.first.toUpperCase();
    final top = MediaQuery.paddingOf(context).top;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(FurrealShape.cardRadius),
          ),
          child: SizedBox(
            height: 340 + top,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (path != null && url != null)
                  photo(context, url, path)
                else
                  ColoredBox(
                    color: FurrealColors.accent,
                    child: Center(
                      child: Text(
                        initial,
                        style: FurrealText.display(fontSize: 120),
                      ),
                    ),
                  ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x66000000),
                        Color(0x00000000),
                        Color(0x00000000),
                        Color(0xB3000000),
                      ],
                      stops: [0, 0.25, 0.55, 1],
                    ),
                  ),
                ),
                Positioned(
                  top: top + 4,
                  left: 4,
                  right: 8,
                  child: Row(
                    children: [
                      if (Navigator.of(context).canPop())
                        IconButton(
                          key: const Key('profile-back'),
                          tooltip: 'kembali',
                          color: Colors.white,
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back),
                        ),
                      const Spacer(),
                      ...actions,
                    ],
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        key: const Key('profile-streak'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x99000000),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '🔥 ${data.streak}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FurrealText.display(fontSize: 34)
                            .copyWith(color: Colors.white),
                      ),
                      Text(
                        '@${data.username}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                data.stats,
                key: const Key('profile-stats'),
                style: const TextStyle(color: FurrealColors.textSecondary),
              ),
              const SizedBox(height: 12),
              below,
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.badge = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      color: Colors.white,
      onPressed: onTap,
      icon: Badge(
        isLabelVisible: badge,
        smallSize: 9,
        backgroundColor: const Color(0xFFFF3B30),
        child: Icon(icon),
      ),
    );
  }
}

/// Pins: maks 3 kartu koleksi. [onAdd] (profil sendiri) menampilkan slot "+".
class _Pins extends StatelessWidget {
  const _Pins({
    required this.pinned,
    required this.numbers,
    required this.onOpen,
    this.onAdd,
  });

  final List<CollectionAnimal> pinned;
  final Map<String, int> numbers;
  final ValueChanged<CollectionAnimal> onOpen;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    if (pinned.isEmpty && onAdd == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('pins', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < maxPinned; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: i < pinned.length
                      ? GestureDetector(
                          key: Key('pin-${pinned[i].id}'),
                          onTap: () => onOpen(pinned[i]),
                          child: AnimalCard(
                            data: AnimalCardData.fromAnimal(
                              pinned[i],
                              number: numbers[pinned[i].id],
                            ),
                            compact: true,
                          ),
                        )
                      : (i == pinned.length && onAdd != null)
                      ? _AddPinSlot(onTap: onAdd!)
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _AddPinSlot extends StatelessWidget {
  const _AddPinSlot({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: AnimalCard.aspectRatio,
      child: Material(
        color: FurrealColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: FurrealColors.textSecondary),
        ),
        child: InkWell(
          key: const Key('pin-add'),
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onTap: onTap,
          child: const Center(child: Icon(Icons.add, size: 32)),
        ),
      ),
    );
  }
}

/// Pilih kartu koleksi untuk di-pin ke profil.
Future<void> _pickPin(
  BuildContext context,
  WidgetRef ref,
  List<CollectionAnimal> animals,
  Map<String, int> numbers,
) async {
  final candidates = [
    for (final a in animals)
      if (!a.pinned) a,
  ];
  final messenger = ScaffoldMessenger.of(context);
  if (candidates.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('belum ada kartu lain. catch hewan dulu ya!'),
      ),
    );
    return;
  }
  final picked = await showModalBottomSheet<CollectionAnimal>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useRootNavigator: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (context, controller) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'pin kartu ke profil',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: GridView.builder(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: AnimalCard.aspectRatio,
              ),
              itemCount: candidates.length,
              itemBuilder: (context, i) => GestureDetector(
                key: Key('pick-${candidates[i].id}'),
                onTap: () => Navigator.pop(context, candidates[i]),
                child: AnimalCard(
                  data: AnimalCardData.fromAnimal(
                    candidates[i],
                    number: numbers[candidates[i].id],
                  ),
                  compact: true,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  if (picked == null) return;
  try {
    await ref
        .read(collectionRepositoryProvider)
        .setPinned(picked.id, pinned: true);
    ref.invalidate(collectionProvider);
    messenger.showSnackBar(
      SnackBar(content: Text('${picked.name} di-pin ke profil.')),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
  }
}

/// Judul + grid 3 kolom catch (terbaru dulu).
List<Widget> _catchesSlivers(
  BuildContext context, {
  required String title,
  required List<HistoryCatch>? items,
  required bool failed,
  required ValueChanged<HistoryCatch> onOpen,
}) => [
  SliverPadding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
    sliver: SliverToBoxAdapter(
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    ),
  ),
  if (items == null)
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: failed
            ? const Text('catch gagal dimuat.', textAlign: TextAlign.center)
            : const Center(child: CircularProgressIndicator()),
      ),
    )
  else if (items.isEmpty)
    const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Text(
          'belum ada catch.',
          style: TextStyle(color: FurrealColors.textSecondary),
        ),
      ),
    )
  else
    SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      sliver: SliverGrid.count(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 3 / 4,
        children: [
          for (final c in items) HistoryTile(item: c, onTap: () => onOpen(c)),
        ],
      ),
    ),
];
