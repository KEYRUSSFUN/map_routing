import 'package:flutter/material.dart';
import 'package:map_routing/features/home/presentation/home_models.dart';
import 'package:map_routing/features/home/presentation/home_ui.dart';

/// Карточка записи в ленте «Недавняя активность».
///
/// Поддерживает три типа: своя тренировка, тренировка друга, пост клуба.
/// Лайки, комментарии и «Поделиться» работают локально (без бэкенда).
class HomeFeedCard extends StatelessWidget {
  const HomeFeedCard({
    super.key,
    required this.post,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onShareTap,
    required this.onMenuTap,
  });

  final HomeFeedPost post;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onShareTap;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: homeCardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FeedHeader(
              post: post,
              onMenuTap: onMenuTap,
            ),
            const SizedBox(height: 10),
            Text(
              post.title,
              style: homeCardTitleStyle(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            _FeedMetricsRow(post: post),
            const SizedBox(height: 12),
            _FeedMapPreview(post: post),
            const SizedBox(height: 12),
            _FeedActionsRow(
              post: post,
              onLikeTap: onLikeTap,
              onCommentTap: onCommentTap,
              onShareTap: onShareTap,
            ),
          ],
        ),
      ),
    );
  }
}

/// Шапка карточки: аватар, имя, время, меню «⋯».
class _FeedHeader extends StatelessWidget {
  const _FeedHeader({
    required this.post,
    required this.onMenuTap,
  });

  final HomeFeedPost post;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    // Для постов клуба показываем название сообщества под именем автора.
    final subtitle = switch (post.kind) {
      HomeFeedPostKind.clubPost =>
        '${post.clubName ?? post.authorName} · ${post.timeAgo}',
      HomeFeedPostKind.ownWorkout => post.timeAgo,
      HomeFeedPostKind.friendWorkout => post.timeAgo,
    };

    final titlePrefix = switch (post.kind) {
      HomeFeedPostKind.clubPost => post.authorName,
      HomeFeedPostKind.ownWorkout => post.authorName,
      HomeFeedPostKind.friendWorkout => post.authorName,
    };

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: post.avatarColor ?? HomeColors.primaryGreen,
          child: Text(
            post.avatarLabel ?? '?',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(titlePrefix, style: homeCardTitleStyle()),
                  if (post.kind == HomeFeedPostKind.clubPost) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.groups_rounded,
                      size: 14,
                      color: HomeColors.body,
                    ),
                  ],
                ],
              ),
              Text(subtitle, style: homeCardSubtitleStyle()),
            ],
          ),
        ),
        IconButton(
          onPressed: onMenuTap,
          icon: const Icon(Icons.more_horiz_rounded, color: HomeColors.body),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }
}

/// Три метрики: дистанция, темп, набор высоты.
class _FeedMetricsRow extends StatelessWidget {
  const _FeedMetricsRow({required this.post});

  final HomeFeedPost post;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCell(
            value: '${post.distanceKm.toStringAsFixed(1)} км',
            label: 'Дистанция',
            valueColor: HomeColors.primaryGreen,
          ),
        ),
        Expanded(
          child: _MetricCell(
            value: post.pace,
            label: 'Средний темп',
          ),
        ),
        Expanded(
          child: _MetricCell(
            value: '${post.elevationM.round()} м',
            label: 'Набор высоты',
          ),
        ),
      ],
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.value,
    required this.label,
    this.valueColor,
  });

  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: homeMetricValueStyle(color: valueColor)),
        const SizedBox(height: 2),
        Text(label, style: homeMetricLabelStyle()),
      ],
    );
  }
}

/// Превью маршрута на карте (пока заглушка с градиентом и линией трека).
class _FeedMapPreview extends StatelessWidget {
  const _FeedMapPreview({required this.post});

  final HomeFeedPost post;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          Container(
            height: 160,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  HomeColors.mapGradientStart,
                  HomeColors.mapGradientEnd,
                ],
              ),
            ),
            child: CustomPaint(
              painter: _RouteLinePainter(seed: post.id.hashCode),
            ),
          ),
          // Бейдж типа активности в правом верхнем углу.
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(post.activityIcon, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    post.activityTypeLabel,
                    style: homeMetricLabelStyle().copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Простая декоративная линия маршрута для превью карты.
class _RouteLinePainter extends CustomPainter {
  _RouteLinePainter({required this.seed});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = HomeColors.primaryGreen
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final offset = (seed % 20) / 100.0;
    path.moveTo(size.width * 0.1, size.height * (0.7 - offset));
    path.quadraticBezierTo(
      size.width * 0.35,
      size.height * 0.2,
      size.width * 0.55,
      size.height * 0.45,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.75,
      size.width * 0.9,
      size.height * 0.35,
    );
    canvas.drawPath(path, paint);

    // Стартовая и финишная точки.
    final dotPaint = Paint()..color = HomeColors.primaryGreen;
    canvas.drawCircle(Offset(size.width * 0.1, size.height * (0.7 - offset)), 5, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.35), 5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Панель действий: лайк, комментарий, поделиться.
class _FeedActionsRow extends StatelessWidget {
  const _FeedActionsRow({
    required this.post,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onShareTap,
  });

  final HomeFeedPost post;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onShareTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionButton(
          icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
          iconColor: post.isLiked ? HomeColors.likeActive : HomeColors.body,
          count: post.likesCount,
          onTap: onLikeTap,
        ),
        const SizedBox(width: 20),
        _ActionButton(
          icon: Icons.chat_bubble_outline_rounded,
          count: post.commentsCount,
          onTap: onCommentTap,
        ),
        const Spacer(),
        IconButton(
          onPressed: onShareTap,
          icon: const Icon(Icons.share_outlined, color: HomeColors.body),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.count,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final int count;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor ?? HomeColors.body),
            const SizedBox(width: 4),
            Text('$count', style: homeCardSubtitleStyle()),
          ],
        ),
      ),
    );
  }
}

/// Нижний лист с формой комментария (визуал, без отправки на сервер).
class HomeCommentsSheet extends StatefulWidget {
  const HomeCommentsSheet({
    super.key,
    required this.postTitle,
    required this.initialCommentsCount,
    required this.onCommentAdded,
  });

  final String postTitle;
  final int initialCommentsCount;
  final VoidCallback onCommentAdded;

  @override
  State<HomeCommentsSheet> createState() => _HomeCommentsSheetState();
}

class _HomeCommentsSheetState extends State<HomeCommentsSheet> {
  final _controller = TextEditingController();

  // Локальный список комментариев-заглушек.
  final List<String> _comments = [
    'Отличный темп!',
    'Красивый маршрут 👍',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addComment() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _comments.add(text);
      _controller.clear();
    });
    widget.onCommentAdded();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Комментарии · ${widget.postTitle}',
              style: homeSectionTitleStyle().copyWith(fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.35,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _comments.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_comments[i], style: homeCardSubtitleStyle()),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Написать комментарий…',
                      hintStyle: homeCardSubtitleStyle(),
                      filled: true,
                      fillColor: HomeColors.scaffoldBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _addComment(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addComment,
                  icon: const Icon(Icons.send_rounded,
                      color: HomeColors.primaryGreen),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Диалог «Поделиться» — визуальная заглушка.
void showHomeShareSheet(BuildContext context, HomeFeedPost post) {
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Поделиться', style: homeSectionTitleStyle()),
            const SizedBox(height: 8),
            Text(
              '«${post.title}»',
              style: homeCardSubtitleStyle(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                _ShareOption(
                  icon: Icons.link_rounded,
                  label: 'Ссылка',
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ссылка скопирована (демо)')),
                    );
                  },
                ),
                _ShareOption(
                  icon: Icons.chat_rounded,
                  label: 'Сообщение',
                  onTap: () => Navigator.pop(ctx),
                ),
                _ShareOption(
                  icon: Icons.groups_rounded,
                  label: 'Клуб',
                  onTap: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: HomeColors.scaffoldBg,
              child: Icon(icon, color: HomeColors.title),
            ),
            const SizedBox(height: 6),
            Text(label, style: homeStoryNameStyle(), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
