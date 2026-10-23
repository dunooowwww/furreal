import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/errors.dart';
import '../../../shared/relative_time.dart';
import '../../../shared/widgets/error_text.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../data/feed_models.dart';
import '../state/feed_providers.dart';

/// Bottom sheet komentar sebuah catch.
Future<void> showCommentsSheet(
  BuildContext context, {
  required String circleId,
  required String catchId,
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
    builder: (_) => CommentsSheet(circleId: circleId, catchId: catchId),
  );
}

class CommentsSheet extends ConsumerStatefulWidget {
  const CommentsSheet({
    super.key,
    required this.circleId,
    required this.catchId,
  });

  final String circleId;
  final String catchId;

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final _input = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  /// Muat ulang daftar komentar & samakan hitungan di kartu feed.
  Future<void> _reload() async {
    ref.invalidate(commentsProvider(widget.catchId));
    final comments = await ref.read(commentsProvider(widget.catchId).future);
    ref
        .read(feedControllerProvider(widget.circleId).notifier)
        .setCommentCount(widget.catchId, comments.length);
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(feedRepositoryProvider).addComment(widget.catchId, body);
      _input.clear();
      await _reload();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(FeedComment comment) async {
    setState(() => _error = null);
    try {
      await ref.read(feedRepositoryProvider).deleteComment(comment.id);
      await _reload();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(commentsProvider(widget.catchId));
    final insets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'komentar',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Flexible(
              child: switch (comments) {
                AsyncData(:final value) when value.isEmpty => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'belum ada komentar. mulai duluan!',
                    style: TextStyle(color: FurrealColors.textSecondary),
                  ),
                ),
                AsyncData(:final value) => ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: value.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _CommentTile(
                    comment: value[i],
                    onDelete: () => _delete(value[i]),
                  ),
                ),
                AsyncError() => Padding(
                  padding: const EdgeInsets.all(20),
                  child: TextButton(
                    onPressed: () =>
                        ref.invalidate(commentsProvider(widget.catchId)),
                    child: const Text('gagal memuat. coba lagi'),
                  ),
                ),
                _ => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('comment-input'),
                          controller: _input,
                          maxLength: commentMaxLength,
                          minLines: 1,
                          maxLines: 3,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: 'tulis komentar…',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        key: const Key('comment-send'),
                        tooltip: 'kirim',
                        onPressed: _sending ? null : _send,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                  ErrorText(_error),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.onDelete});

  final FeedComment comment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatar(
          name: comment.displayName,
          avatarPath: comment.avatarPath,
          size: 32,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: comment.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(
                      text: '  ${relativeTime(comment.createdAt)}',
                      style: FurrealText.mono(fontSize: 11)
                          .copyWith(color: FurrealColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(comment.body),
            ],
          ),
        ),
        if (comment.isMine)
          IconButton(
            tooltip: 'hapus komentar',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 20),
          ),
      ],
    );
  }
}
