import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/navigation/open_user_profile.dart';
import 'package:map_routing/core/network/backend_urls.dart';
import 'package:map_routing/data/models/moment.dart';
import 'package:map_routing/features/home/presentation/home_ui.dart';
import 'package:map_routing/features/moments/presentation/post_moment_actions_menu.dart';
import 'package:map_routing/shared/utils/relative_time.dart';

class MomentFeedCard extends StatelessWidget {
  const MomentFeedCard({
    super.key,
    required this.moment,
    required this.onLikeTap,
    required this.onCommentTap,
    this.onDeleteTap,
    this.onEditTap,
    this.onClubTap,
    this.compact = false,
    this.edgeToEdge = false,
    this.showClubContext = true,
  });

  final MomentItem moment;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback? onDeleteTap;
  final VoidCallback? onEditTap;
  final VoidCallback? onClubTap;
  final bool compact;
  final bool edgeToEdge;
  final bool showClubContext;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = absoluteBackendUrl(moment.avatarUrl);
    final photoUrl = absoluteBackendUrl(moment.photoUrl);

    if (edgeToEdge) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (moment.isClubPost && showClubContext)
                  _ClubPostHeader(
                    title: moment.clubTitle ?? 'Клуб',
                    avatarUrl: absoluteBackendUrl(moment.clubAvatarUrl),
                    onTap: onClubTap,
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                  child: Row(
                    children: [
                      _Avatar(
                        url: avatarUrl,
                        name: moment.userName,
                        onTap: moment.isMe
                            ? null
                            : () => openUserProfile(context, moment.userId),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              moment.userName,
                              style: GoogleFonts.lexendDeca(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: HomeColors.title,
                              ),
                            ),
                            Text(
                              formatRelativeTimeRu(moment.createdAt),
                              style: homeSubtitleStyle(),
                            ),
                          ],
                        ),
                      ),
                      if (moment.isMe && (onEditTap != null || onDeleteTap != null))
                        PostMomentMenuButton(
                          onEditTap: onEditTap,
                          onDeleteTap: onDeleteTap,
                        ),
                    ],
                  ),
                ),
                if (moment.text != null && moment.text!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      moment.text!,
                      style: GoogleFonts.lexendDeca(
                        fontSize: 14,
                        height: 1.45,
                        color: HomeColors.title,
                      ),
                    ),
                  ),
                ],
                if (isLoadableNetworkUrl(photoUrl)) ...[
                  const SizedBox(height: 10),
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.network(
                      photoUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0xFFF0F0F0),
                        child: Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                  child: Row(
                    children: [
                      _ActionButton(
                        icon: moment.likedByMe
                            ? Icons.favorite
                            : Icons.favorite_border,
                        label: moment.likesCount > 0
                            ? '${moment.likesCount}'
                            : 'Нравится',
                        color: moment.likedByMe
                            ? const Color(0xFFE91E63)
                            : HomeColors.body,
                        onTap: onLikeTap,
                      ),
                      const SizedBox(width: 8),
                      _ActionButton(
                        icon: Icons.chat_bubble_outline,
                        label: _commentActionLabel(
                          moment.commentsCount,
                          compact: compact,
                        ),
                        color: HomeColors.body,
                        onTap: onCommentTap,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: HomeColors.sectionDivider),
        ],
      );
    }

    return Container(
      margin: EdgeInsets.only(bottom: compact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomeColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 0),
            child: Row(
              children: [
                _Avatar(
                  url: avatarUrl,
                  name: moment.userName,
                  onTap: moment.isMe
                      ? null
                      : () => openUserProfile(context, moment.userId),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        moment.userName,
                        style: GoogleFonts.lexendDeca(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: HomeColors.title,
                        ),
                      ),
                      Text(
                        formatRelativeTimeRu(moment.createdAt),
                        style: homeSubtitleStyle(),
                      ),
                    ],
                  ),
                ),
                if (moment.isMe && (onEditTap != null || onDeleteTap != null))
                  PostMomentMenuButton(
                    onEditTap: onEditTap,
                    onDeleteTap: onDeleteTap,
                  ),
              ],
            ),
          ),
          if (moment.text != null && moment.text!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                moment.text!,
                style: GoogleFonts.lexendDeca(
                  fontSize: 14,
                  height: 1.45,
                  color: HomeColors.title,
                ),
              ),
            ),
          ],
          if (isLoadableNetworkUrl(photoUrl)) ...[
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: compact ? 16 / 10 : 4 / 3,
              child: Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Color(0xFFF0F0F0),
                  child: Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Row(
              children: [
                _ActionButton(
                  icon: moment.likedByMe
                      ? Icons.favorite
                      : Icons.favorite_border,
                  label: moment.likesCount > 0 ? '${moment.likesCount}' : 'Нравится',
                  color: moment.likedByMe
                      ? const Color(0xFFE91E63)
                      : HomeColors.body,
                  onTap: onLikeTap,
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: _commentActionLabel(
                    moment.commentsCount,
                    compact: compact,
                  ),
                  color: HomeColors.body,
                  onTap: onCommentTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _commentActionLabel(int commentsCount, {required bool compact}) {
  if (commentsCount <= 0) return 'Комментарий';
  if (compact) return formatCommentsCountRu(commentsCount);
  return '$commentsCount';
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.name,
    this.onTap,
  });

  final String? url;
  final String name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    Widget avatar;
    if (isLoadableNetworkUrl(url)) {
      avatar = CircleAvatar(
        radius: 18,
        backgroundImage: NetworkImage(url!),
      );
    } else {
      avatar = CircleAvatar(
        radius: 18,
        backgroundColor: HomeColors.primaryGreen,
        child: Text(
          initial,
          style: GoogleFonts.lexendDeca(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    if (onTap == null) return avatar;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: avatar,
      ),
    );
  }
}

class _ClubPostHeader extends StatelessWidget {
  const _ClubPostHeader({
    required this.title,
    required this.avatarUrl,
    this.onTap,
  });

  final String title;
  final String? avatarUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7FAF8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: HomeColors.primaryGreen.withValues(alpha: 0.12),
                backgroundImage:
                    isLoadableNetworkUrl(avatarUrl) ? NetworkImage(avatarUrl!) : null,
                child: isLoadableNetworkUrl(avatarUrl)
                    ? null
                    : Text(
                        title.isNotEmpty ? title[0].toUpperCase() : 'К',
                        style: GoogleFonts.lexendDeca(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: HomeColors.primaryGreen,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.lexendDeca(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: HomeColors.title,
                  ),
                ),
              ),
              const Icon(
                Icons.groups_rounded,
                size: 16,
                color: HomeColors.primaryGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(label, style: homeSubtitleStyle(color: color)),
            ],
          ],
        ),
      ),
    );
  }
}
