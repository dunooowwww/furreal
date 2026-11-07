import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../shared/errors.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../data/friend_repository.dart';
import '../state/friend_providers.dart';
import 'friend_action_button.dart';

/// Teman (M18): cari username, permintaan masuk, teman, permintaan terkirim.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _query = TextEditingController();
  bool _searching = false;
  String? _message;
  FriendUser? _result;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _message = null;
      _result = null;
    });
    try {
      final user = await ref.read(friendRepositoryProvider).findUser(q);
      setState(() {
        _result = user;
        _message = user == null
            ? 'username @${q.toLowerCase()} nggak ketemu.'
            : null;
      });
    } catch (e) {
      setState(() => _message = friendlyError(e));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(myFriendsProvider);
    final label = FurrealText.mono(fontSize: 11)
        .copyWith(color: FurrealColors.textSecondary, letterSpacing: 0.5);

    List<Widget> section(String title, List<FriendUser> users) => [
      if (users.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text('$title · ${users.length}', style: label),
        const SizedBox(height: 4),
        for (final u in users) _FriendTile(user: u),
      ],
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('teman')),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(myFriendsProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('friend-search'),
                    controller: _query,
                    autocorrect: false,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(
                      hintText: 'cari username teman',
                      prefixText: '@',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('friend-search-go'),
                  onPressed: _searching ? null : _search,
                  child: Text(_searching ? '…' : 'cari'),
                ),
              ],
            ),
            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(_message!, key: const Key('friend-search-message')),
            ],
            if (_result case final user?) ...[
              const SizedBox(height: 8),
              _FriendTile(
                user: user,
                onChanged: (r) =>
                    setState(() => _result = user.withRelation(r)),
              ),
            ],
            switch (friends) {
              AsyncData(:final value) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...section('PERMINTAAN MASUK', [
                    for (final f in value)
                      if (f.relation == FriendRelation.incoming) f,
                  ]),
                  ...section('TEMAN', [
                    for (final f in value)
                      if (f.relation == FriendRelation.friend) f,
                  ]),
                  ...section('TERKIRIM', [
                    for (final f in value)
                      if (f.relation == FriendRelation.outgoing) f,
                  ]),
                  if (value.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Text(
                        'belum ada teman. cari username temen lo di atas, '
                        'nanti catch mereka muncul di feed "teman".',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: FurrealColors.textSecondary),
                      ),
                    ),
                ],
              ),
              AsyncError() => const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Text(
                  'gagal memuat teman. tarik ke bawah buat coba lagi.',
                  textAlign: TextAlign.center,
                ),
              ),
              _ => const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
            },
          ],
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.user, this.onChanged});

  final FriendUser user;
  final ValueChanged<FriendRelation>? onChanged;

  @override
  Widget build(BuildContext context) {
    final canOpen =
        user.relation == FriendRelation.friend ||
        user.relation == FriendRelation.self;
    return ListTile(
      key: Key('friend-${user.username}'),
      contentPadding: EdgeInsets.zero,
      onTap: canOpen ? () => context.push(Routes.user(user.id)) : null,
      leading: UserAvatar(name: user.name, avatarPath: user.avatarPath),
      title: Text(user.name),
      subtitle: Text('@${user.username}'),
      trailing: FriendActionButton(
        userId: user.id,
        name: user.name,
        relation: user.relation,
        onChanged: onChanged,
        dense: true,
      ),
    );
  }
}
