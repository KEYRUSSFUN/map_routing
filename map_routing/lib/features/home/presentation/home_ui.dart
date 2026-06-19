import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/network/backend_urls.dart';

abstract final class HomeColors {
  static const primaryGreen = Color(0xFF00E676);
  static const title = Color(0xFF212121);
  static const body = Color(0xFF757575);
  static const challengeCard = Color(0xFF1C1C1E);
  static const challengeMuted = Color(0xFF9E9E9E);
  static const daysLeft = Color(0xFFFF9800);
  static const cardBorder = Color(0xFFEEEEEE);
}

TextStyle homeSectionTitleStyle() => GoogleFonts.lexendDeca(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: HomeColors.title,
    );

TextStyle homeLinkStyle() => GoogleFonts.lexendDeca(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: HomeColors.primaryGreen,
    );

TextStyle homeSubtitleStyle({Color? color}) => GoogleFonts.lexendDeca(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: color ?? HomeColors.body,
    );

class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    this.trailingLabel,
    this.onTrailingTap,
  });

  final String title;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: homeSectionTitleStyle())),
        if (trailingLabel != null)
          GestureDetector(
            onTap: onTrailingTap,
            child: Text(trailingLabel!, style: homeLinkStyle()),
          ),
      ],
    );
  }
}

class HomeStoryAvatar extends StatelessWidget {
  const HomeStoryAvatar({
    super.key,
    required this.label,
    required this.initial,
    required this.color,
    this.avatarUrl,
    this.hasStoryRing = false,
    this.showAddBadge = false,
    this.isOnline = false,
    this.onTap,
    this.onAddTap,
    this.onAvatarTap,
  });

  final String label;
  final String initial;
  final Color color;
  final String? avatarUrl;
  final bool hasStoryRing;
  final bool showAddBadge;
  final bool isOnline;
  final VoidCallback? onTap;
  final VoidCallback? onAddTap;
  final VoidCallback? onAvatarTap;

  static const _avatarSize = 52.0;
  static const _ringPadding = 2.5;
  static const _avatarSlotSize = _avatarSize + _ringPadding * 2;
  static const _onlineDotSize = 12.0;

  static const friendPalette = [
    Color(0xFF2196F3),
    Color(0xFFE91E63),
    Color(0xFF00BCD4),
    Color(0xFF9C27B0),
  ];

  static Color colorForFriend(int index) =>
      friendPalette[index % friendPalette.length];

  static String initialFromName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  String? get _resolvedAvatarUrl {
    final resolved = absoluteBackendUrl(avatarUrl);
    if (!isLoadableNetworkUrl(resolved)) return null;
    return resolved;
  }

  Widget _buildAvatarContent(BuildContext context) {
    final url = _resolvedAvatarUrl;
    if (url != null) {
      final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
      final cacheSize = (_avatarSize * devicePixelRatio).round();
      return ClipOval(
        child: Image.network(
          url,
          width: _avatarSize,
          height: _avatarSize,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          cacheWidth: cacheSize,
          cacheHeight: cacheSize,
          errorBuilder: (_, __, ___) => _initialAvatar(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _initialAvatar(showLoader: true);
          },
        ),
      );
    }
    return _initialAvatar();
  }

  Widget _initialAvatar({bool showLoader = false}) {
    return Container(
      width: _avatarSize,
      height: _avatarSize,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: showLoader
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              initial,
              style: GoogleFonts.lexendDeca(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _avatarSlotSize,
            height: _avatarSlotSize,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: EdgeInsets.all(hasStoryRing ? _ringPadding : 0),
                    decoration: hasStoryRing
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: HomeColors.primaryGreen,
                              width: _ringPadding,
                            ),
                          )
                        : null,
                    child: onAvatarTap == null
                        ? _buildAvatarContent(context)
                        : GestureDetector(
                            onTap: onAvatarTap,
                            child: _buildAvatarContent(context),
                          ),
                  ),
                ),
                if (showAddBadge)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: GestureDetector(
                      onTap: onAddTap ?? onTap,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: HomeColors.primaryGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child:
                            const Icon(Icons.add, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                if (!showAddBadge)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: _onlineDotSize,
                      height: _onlineDotSize,
                      decoration: BoxDecoration(
                        color: isOnline
                            ? HomeColors.primaryGreen
                            : const Color(0xFFBDBDBD),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 16,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: homeSubtitleStyle(color: HomeColors.title),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeChallengeCard extends StatelessWidget {
  const HomeChallengeCard({
    super.key,
    required this.title,
    required this.participantsLabel,
    required this.daysLeftLabel,
    required this.progress,
    this.onTap,
  });

  final String title;
  final String participantsLabel;
  final String daysLeftLabel;
  final double progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomeColors.challengeCard,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FaIcon(
            FontAwesomeIcons.trophy,
            size: 16,
            color: HomeColors.primaryGreen,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.lexendDeca(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            participantsLabel,
            style: homeSubtitleStyle(color: HomeColors.challengeMuted),
          ),
          const Spacer(),
          Text(
            daysLeftLabel,
            style: GoogleFonts.lexendDeca(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: HomeColors.daysLeft,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: const Color(0xFF3A3A3C),
              color: HomeColors.primaryGreen,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;

    return GestureDetector(onTap: onTap, child: card);
  }
}

class HomeActivityCard extends StatelessWidget {
  const HomeActivityCard({
    super.key,
    required this.userName,
    required this.timeAgo,
    required this.title,
    required this.distance,
    required this.pace,
    required this.elevation,
    required this.activityLabel,
  });

  final String userName;
  final String timeAgo;
  final String title;
  final String distance;
  final String pace;
  final String elevation;
  final String activityLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: HomeColors.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Я',
                        style: GoogleFonts.lexendDeca(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: GoogleFonts.lexendDeca(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: HomeColors.title,
                            ),
                          ),
                          Text(timeAgo, style: homeSubtitleStyle()),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.more_horiz, color: HomeColors.body),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: GoogleFonts.lexendDeca(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: HomeColors.title,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatColumn(
                        value: distance,
                        label: 'Дистанция',
                        valueColor: HomeColors.primaryGreen,
                      ),
                    ),
                    Expanded(
                      child: _StatColumn(value: pace, label: 'Средний темп'),
                    ),
                    Expanded(
                      child: _StatColumn(value: elevation, label: 'Набор высоты'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FaIcon(
                          FontAwesomeIcons.personRunning,
                          size: 12,
                          color: HomeColors.body,
                        ),
                        const SizedBox(width: 6),
                        Text(activityLabel, style: homeSubtitleStyle()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _RoutePreviewStub(),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.lexendDeca(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: valueColor ?? HomeColors.title,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: homeSubtitleStyle()),
      ],
    );
  }
}

class _RoutePreviewStub extends StatelessWidget {
  const _RoutePreviewStub();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF8F8F8), Color(0xFFEFEFEF)],
              ),
            ),
          ),
          CustomPaint(painter: _RoutePreviewPainter()),
        ],
      ),
    );
  }
}

class _RoutePreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.22,
        size.height * 0.35,
        size.width * 0.38,
        size.height * 0.55,
      )
      ..quadraticBezierTo(
        size.width * 0.52,
        size.height * 0.74,
        size.width * 0.66,
        size.height * 0.42,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.18,
        size.width * 0.94,
        size.height * 0.38,
      );

    final shadowPaint = Paint()
      ..color = HomeColors.primaryGreen.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final linePaint = Paint()
      ..color = HomeColors.primaryGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, linePaint);

    final start = Offset(size.width * 0.08, size.height * 0.72);
    final end = Offset(size.width * 0.94, size.height * 0.38);
    canvas.drawCircle(start, 5, Paint()..color = HomeColors.primaryGreen);
    canvas.drawCircle(end, 5, Paint()..color = HomeColors.primaryGreen);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
