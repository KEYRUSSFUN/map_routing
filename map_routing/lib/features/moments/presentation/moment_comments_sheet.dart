import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/navigation/open_user_profile.dart';
import 'package:map_routing/core/network/backend_urls.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:map_routing/core/widgets/user_avatar.dart';
import 'package:map_routing/data/models/moment.dart';
import 'package:map_routing/data/services/moment_service.dart';
import 'package:map_routing/features/home/presentation/home_ui.dart';
import 'package:map_routing/shared/utils/relative_time.dart';

Future<int?> showMomentCommentsSheet(
  BuildContext context, {
  required MomentService momentService,
  required MomentItem moment,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => MomentCommentsSheet(
      momentService: momentService,
      moment: moment,
    ),
  );
}

class MomentCommentsSheet extends StatefulWidget {
  const MomentCommentsSheet({
    super.key,
    required this.momentService,
    required this.moment,
  });

  final MomentService momentService;
  final MomentItem moment;

  @override
  State<MomentCommentsSheet> createState() => _MomentCommentsSheetState();
}

class _MomentCommentsSheetState extends State<MomentCommentsSheet> {
  final _controller = TextEditingController();
  List<MomentCommentItem> _comments = [];
  int _commentsCount = 0;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _commentsCount = widget.moment.commentsCount;
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    try {
      final comments =
          await widget.momentService.fetchComments(widget.moment.id);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppSnackBar.show(context, 'Не удалось загрузить комментарии');
    }
  }

  Future<void> _sendComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final result =
          await widget.momentService.addComment(widget.moment.id, text);
      if (!mounted) return;
      setState(() {
        _comments = [..._comments, result.comment];
        _commentsCount = result.commentsCount;
        _controller.clear();
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      AppSnackBar.show(context, 'Не удалось отправить комментарий');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop(_commentsCount);
        }
      },
      child: SizedBox(
        height: maxHeight,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Комментарии',
                style: GoogleFonts.lexendDeca(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: HomeColors.title,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                      ? Center(
                          child: Text(
                            'Пока нет комментариев',
                            style: homeSubtitleStyle(),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _comments.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _CommentTile(comment: _comments[index]);
                          },
                        ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLength: 1000,
                      decoration: InputDecoration(
                        hintText: 'Написать комментарий...',
                        counterText: '',
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _sendComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _sendComment,
                    style: IconButton.styleFrom(
                      backgroundColor: HomeColors.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final MomentCommentItem comment;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = absoluteBackendUrl(comment.avatarUrl);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatar(
          name: comment.userName,
          avatarUrl: avatarUrl,
          radius: 16,
          onTap: comment.isMe
              ? null
              : () => openUserProfile(context, comment.userId),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      comment.userName,
                      style: GoogleFonts.lexendDeca(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: HomeColors.title,
                      ),
                    ),
                  ),
                  Text(
                    formatRelativeTimeRu(comment.createdAt),
                    style: homeSubtitleStyle(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                comment.text,
                style: GoogleFonts.lexendDeca(
                  fontSize: 14,
                  height: 1.4,
                  color: HomeColors.title,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
