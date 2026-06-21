import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/network/backend_urls.dart';
import 'package:map_routing/core/widgets/user_avatar.dart';
import 'package:map_routing/data/models/challenge.dart';
import 'package:map_routing/data/models/moment.dart';
import 'package:map_routing/data/models/story.dart';
import 'package:map_routing/features/moments/presentation/moment_feed_card.dart';
import 'package:map_routing/features/profile/presentation/profile_cover_background.dart';

abstract final class ProfileColors {
  static const primaryGreen = Color(0xFF00E676);
  static const greenBorder = Color(0xFF21FBCC);
  static const title = Color(0xFF212121);
  static const body = Color(0xFF757575);
  static const orange = Color(0xFFFF9800);
  static const orangeBorder = Color(0xFFFDA700);
  static const tabActive = Color(0xFFFFEACC);
  static const cardBg = Color(0xFFFDFDFD);
  static const scaffoldBg = Colors.white;
}

TextStyle profileTitleStyle({double size = 22}) => GoogleFonts.lexendDeca(
  fontSize: size,
  fontWeight: FontWeight.w700,
  color: ProfileColors.title,
);

TextStyle profileSubtitleStyle({Color? color}) => GoogleFonts.lexendDeca(
  fontSize: 13,
  fontWeight: FontWeight.w500,
  color: color ?? ProfileColors.body,
);

TextStyle profileSectionTitleStyle() => GoogleFonts.lexendDeca(
  fontSize: 18,
  fontWeight: FontWeight.w700,
  color: ProfileColors.title,
);

TextStyle profileLinkStyle() => GoogleFonts.lexendDeca(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: ProfileColors.primaryGreen,
);

enum ProfileTab { events, statistics, achievements, history }

BoxDecoration profileElevatedDecoration({
  Color backgroundColor = Colors.white,
  Color borderColor = const Color(0xFFE8E8E8),
  double radius = 16,
}) {
  return BoxDecoration(
    color: backgroundColor,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor),
    boxShadow: const [
      BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 4)),
    ],
  );
}

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.name,
    required this.location,
    this.subtitle = 'Спортсмен',
    this.avatarUrl,
    this.coverUrl,
    this.coverPresetId,
    this.onAvatarTap,
    this.onCoverTap,
    this.onBack,
    this.onSettings,
    this.statPills = const [],
  });

  final String name;
  final String location;
  final String subtitle;
  final String? avatarUrl;
  final String? coverUrl;
  final String? coverPresetId;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onCoverTap;
  final VoidCallback? onBack;
  final VoidCallback? onSettings;
  final List<ProfileStatPillData> statPills;

  static const _coverHeight = 200.0;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              height: _coverHeight,
              width: double.infinity,
              child: GestureDetector(
                onTap: onCoverTap,
                child: ProfileCoverBackground(
                  coverUrl: coverUrl,
                  coverPresetId: coverPresetId,
                  height: _coverHeight,
                ),
              ),
            ),
            if (onBack != null)
              Positioned(
                top: topInset + 12,
                left: 16,
                child: _HeaderIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: onBack!,
                ),
              ),
            if (onSettings != null)
              Positioned(
                top: topInset + 12,
                right: 16,
                child: _HeaderIconButton(
                  icon: Icons.settings_outlined,
                  onTap: onSettings!,
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: -40,
              child: Center(
                child: GestureDetector(
                  onTap: onAvatarTap,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: () {
                        final resolved = absoluteBackendUrl(avatarUrl);
                        if (isLoadableNetworkUrl(resolved)) {
                          return NetworkImage(resolved!);
                        }
                        return const AssetImage('assets/images/profile.png')
                            as ImageProvider;
                      }(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
        Text(name, style: profileTitleStyle()),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(subtitle, style: profileSubtitleStyle()),
            if (location.isNotEmpty) ...[
              const SizedBox(width: 12),
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: ProfileColors.body,
              ),
              const SizedBox(width: 4),
              Text(location, style: profileSubtitleStyle()),
            ],
          ],
        ),
        const SizedBox(height: 16),
        if (statPills.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (var i = 0; i < statPills.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: ProfileStatPill(data: statPills[i])),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: ProfileColors.title),
        ),
      ),
    );
  }
}

class ProfileStatPillData {
  const ProfileStatPillData({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class ProfileStatPill extends StatelessWidget {
  const ProfileStatPill({super.key, required this.data});

  final ProfileStatPillData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ProfileColors.primaryGreen,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ProfileColors.greenBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A00E676),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            data.icon,
            size: 16,
            color: const Color.fromARGB(255, 255, 255, 255),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              data.label,
              style: profileSubtitleStyle(
                color: const Color.fromARGB(255, 255, 255, 255),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileTabBar extends StatelessWidget {
  const ProfileTabBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final ProfileTab selected;
  final ValueChanged<ProfileTab> onChanged;

  static const _tabMeta = {
    ProfileTab.events: (Icons.auto_awesome_outlined, 'События'),
    ProfileTab.statistics: (Icons.insights_outlined, 'Статистика'),
    ProfileTab.achievements: (Icons.emoji_events_outlined, 'Достижения'),
    ProfileTab.history: (Icons.directions_run_outlined, 'Тренировки'),
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE3E8EE)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < ProfileTab.values.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: _ProfileTabItem(
                  icon: _tabMeta[ProfileTab.values[i]]!.$1,
                  label: _tabMeta[ProfileTab.values[i]]!.$2,
                  isActive: ProfileTab.values[i] == selected,
                  onTap: () => onChanged(ProfileTab.values[i]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileTabItem extends StatelessWidget {
  const _ProfileTabItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isActive
                ? ProfileColors.primaryGreen.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: isActive
                ? Border.all(
                    color: ProfileColors.primaryGreen.withValues(alpha: 0.28),
                  )
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive ? ProfileColors.primaryGreen : ProfileColors.body,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.lexendDeca(
                  fontSize: 10.5,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? ProfileColors.title : ProfileColors.body,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileSectionHeader extends StatelessWidget {
  const ProfileSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailingTap,
  });

  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: profileSectionTitleStyle())),
        if (trailing != null)
          GestureDetector(
            onTap: onTrailingTap,
            child: Text(trailing!, style: profileLinkStyle()),
          ),
      ],
    );
  }
}

class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: profileElevatedDecoration(
        backgroundColor: ProfileColors.cardBg,
        radius: 14,
      ),
      child: child,
    );
  }
}

class PersonalRecordCard extends StatelessWidget {
  const PersonalRecordCard({
    super.key,
    required this.title,
    required this.value,
    this.badge,
    this.subtitle,
  });

  final String title;
  final String value;
  final String? badge;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: profileElevatedDecoration(
        backgroundColor: const Color(0xFFFBFBFB),
        borderColor: ProfileColors.orangeBorder,
        radius: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: profileSubtitleStyle()),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.lexendDeca(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: badge != null
                  ? ProfileColors.orange
                  : ProfileColors.primaryGreen,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(height: 4),
            Text(
              badge!,
              style: GoogleFonts.lexendDeca(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ProfileColors.orange,
              ),
            ),
          ] else if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: profileSubtitleStyle()),
          ],
        ],
      ),
    );
  }
}

class AchievementBadge extends StatelessWidget {
  const AchievementBadge({
    super.key,
    required this.label,
    required this.icon,
    this.locked = false,
    this.showNewDot = false,
    this.size = 64,
    this.showLabel = true,
  });

  final String label;
  final IconData icon;
  final bool locked;
  final bool showNewDot;
  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AchievementMedallion(
          icon: icon,
          locked: locked,
          showNewDot: showNewDot,
          size: size,
        ),
        if (showLabel) ...[
          SizedBox(height: size >= 80 ? 10 : 6),
          SizedBox(
            width: size + 8,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.lexendDeca(
                fontSize: size >= 80 ? 12 : 11,
                fontWeight: locked ? FontWeight.w500 : FontWeight.w600,
                color: locked ? ProfileColors.body : ProfileColors.title,
                height: 1.2,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class AchievementMedallion extends StatelessWidget {
  const AchievementMedallion({
    super.key,
    required this.icon,
    this.locked = false,
    this.showNewDot = false,
    this.size = 64,
  });

  final IconData icon;
  final bool locked;
  final bool showNewDot;
  final double size;

  @override
  Widget build(BuildContext context) {
    final iconSize = size * 0.36;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: locked ? const Color(0xFFF7F9FA) : null,
            gradient: locked
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ProfileColors.orange.withValues(alpha: 0.22),
                      ProfileColors.orange.withValues(alpha: 0.07),
                    ],
                  ),
            border: Border.all(
              color: locked
                  ? const Color(0xFFE3E8EE)
                  : ProfileColors.orange.withValues(alpha: 0.32),
              width: 1.5,
            ),
          ),
          child: Icon(
            locked ? Icons.lock_outline_rounded : icon,
            color: locked
                ? const Color(0xFFB0B8C1)
                : ProfileColors.orange,
            size: iconSize,
          ),
        ),
        if (showNewDot && !locked)
          Positioned(
            top: 1,
            right: -3,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: ProfileColors.orange,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.stats,
    this.icon = Icons.directions_run,
    this.detailLine,
    this.onTap,
    this.onShowOnMap,
    this.onLongPress,
    this.selectionMode = false,
    this.selected = false,
    this.onSelectedChanged,
    this.ownerName,
    this.ownerAvatarUrl,
  });

  final String title;
  final String subtitle;
  final List<ActivityStat> stats;
  final IconData icon;
  final String? detailLine;
  final VoidCallback? onTap;
  final VoidCallback? onShowOnMap;
  final VoidCallback? onLongPress;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<bool>? onSelectedChanged;
  final String? ownerName;
  final String? ownerAvatarUrl;

  @override
  Widget build(BuildContext context) {
    final cardTap = selectionMode
        ? () => onSelectedChanged?.call(!selected)
        : onTap;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: cardTap,
        onLongPress: selectionMode ? null : onLongPress,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selectionMode && selected
                ? ProfileColors.primaryGreen.withValues(alpha: 0.06)
                : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selectionMode && selected
                  ? ProfileColors.primaryGreen.withValues(alpha: 0.35)
                  : const Color(0xFFE3E8EE),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (ownerName != null && ownerName!.trim().isNotEmpty) ...[
                Row(
                  children: [
                    UserAvatar(
                      name: ownerName!,
                      avatarUrl: ownerAvatarUrl,
                      radius: 14,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ownerName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: profileSubtitleStyle().copyWith(
                          fontWeight: FontWeight.w600,
                          color: ProfileColors.title,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectionMode) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 10, right: 4),
                      child: Checkbox(
                        value: selected,
                        activeColor: ProfileColors.primaryGreen,
                        onChanged: (value) =>
                            onSelectedChanged?.call(value ?? false),
                      ),
                    ),
                  ],
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          ProfileColors.primaryGreen,
                          Color(0xFF00C853),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ProfileColors.primaryGreen.withValues(
                            alpha: 0.22,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: profileTitleStyle(size: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: profileSubtitleStyle(),
                        ),
                        if (detailLine != null && detailLine!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            detailLine!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: profileSubtitleStyle().copyWith(
                              color: ProfileColors.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!selectionMode && onShowOnMap != null) ...[
                    const SizedBox(width: 8),
                    Material(
                      color: ProfileColors.primaryGreen.withValues(alpha: 0.12),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onShowOnMap,
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(
                            Icons.map_outlined,
                            color: ProfileColors.primaryGreen,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (stats.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < stats.length; i++) ...[
                        if (i > 0)
                          Container(
                            width: 1,
                            height: 28,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            color: const Color(0xFFE3E8EE),
                          ),
                        Expanded(
                          child: _ActivityStatItem(
                            stat: stats[i],
                            alignment: _statAlignment(i, stats.length),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Alignment _statAlignment(int index, int count) {
    if (count <= 1) return Alignment.center;
    if (index == 0) return Alignment.centerLeft;
    if (index == count - 1) return Alignment.centerRight;
    return Alignment.center;
  }
}

class ActivityStat {
  const ActivityStat({required this.value, required this.label});

  final String value;
  final String label;
}

class _ActivityStatItem extends StatelessWidget {
  const _ActivityStatItem({
    required this.stat,
    this.alignment = Alignment.centerLeft,
  });

  final ActivityStat stat;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final crossAxisAlignment = switch (alignment) {
      Alignment.centerRight => CrossAxisAlignment.end,
      Alignment.center => CrossAxisAlignment.center,
      _ => CrossAxisAlignment.start,
    };

    return Align(
      alignment: alignment,
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            stat.value,
            style: GoogleFonts.lexendDeca(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: ProfileColors.title,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            stat.label,
            style: profileSubtitleStyle().copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class WeeklyActivityBarChart extends StatelessWidget {
  const WeeklyActivityBarChart({
    super.key,
    this.weeklyData,
    this.isLoading = false,
    this.totalLabel,
    this.changeLabel,
  });

  final List<double>? weeklyData;
  final bool isLoading;
  final String? totalLabel;
  final String? changeLabel;

  double _getMaxY(List<double> data) {
    if (data.isEmpty) return 1.0;
    final max = data.reduce((a, b) => a > b ? a : b);
    return (max < 1.0) ? 1.0 : (max * 1.2).ceilToDouble();
  }

  List<String> _getDayLabels() {
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 6));
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return List.generate(7, (index) {
      final date = startDate.add(Duration(days: index));
      return days[date.weekday - 1];
    });
  }

  String _formatDateRange() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 6));
    const months = [
      'янв.',
      'фев.',
      'мар.',
      'апр.',
      'май',
      'июн.',
      'июл.',
      'авг.',
      'сен.',
      'окт.',
      'нояб.',
      'дек.',
    ];
    return '${start.day} – ${now.day} ${months[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && weeklyData == null) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final resolvedData =
        weeklyData ?? const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    final maxY = _getMaxY(resolvedData);
    final dayLabels = _getDayLabels();
    final chartKey = ValueKey(resolvedData.map((v) => v.toStringAsFixed(1)).join('|'));

    return RepaintBoundary(
      key: chartKey,
      child: ProfileCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Еженедельная активность',
                    style: profileSectionTitleStyle(),
                  ),
                ),
                Text(_formatDateRange(), style: profileSubtitleStyle()),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: BarChart(
                key: chartKey,
                BarChartData(
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 2,
                    getDrawingHorizontalLine: (value) =>
                        FlLine(color: Colors.grey.shade300, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${(rod.toY / 1000).toStringAsFixed(2)} км',
                          profileSubtitleStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < dayLabels.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                dayLabels[index],
                                style: profileSubtitleStyle(),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(resolvedData.length, (index) {
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: resolvedData[index],
                          width: 14,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                          color: ProfileColors.primaryGreen,
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    totalLabel ?? 'Всего: -- км',
                    style: profileSubtitleStyle(color: ProfileColors.title),
                  ),
                ),
                if (changeLabel != null)
                  Text(changeLabel!, style: profileLinkStyle()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FriendRequestTile extends StatelessWidget {
  const FriendRequestTile({
    super.key,
    required this.userName,
    required this.onAccept,
    required this.onReject,
  });

  final String userName;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return ProfileCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundImage: AssetImage('assets/images/profile.png'),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(userName, style: profileTitleStyle(size: 15))),
          IconButton(
            icon: const Icon(
              Icons.check_circle_outline,
              color: ProfileColors.primaryGreen,
            ),
            onPressed: onAccept,
          ),
          IconButton(
            icon: Icon(Icons.cancel_outlined, color: Colors.grey.shade500),
            onPressed: onReject,
          ),
        ],
      ),
    );
  }
}

class ProfileMenuTile extends StatelessWidget {
  const ProfileMenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ProfileCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: ProfileColors.primaryGreen),
        title: Text(title, style: profileTitleStyle(size: 16)),
        trailing: const Icon(Icons.chevron_right, color: ProfileColors.body),
        onTap: onTap,
      ),
    );
  }
}

class ProfileChallengeProgressCard extends StatelessWidget {
  const ProfileChallengeProgressCard({
    super.key,
    required this.challenge,
    this.onTap,
  });

  final ChallengeSummary challenge;
  final VoidCallback? onTap;

  static const _cardBlack = Color(0xFF17171A);
  static const _daysLeft = Color(0xFFFFD166);

  @override
  Widget build(BuildContext context) {
    final progressValue = challenge.myProgress ?? 0;
    final progress = challenge.progressPercent;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [
                _cardBlack.withValues(alpha: 0.92),
                _cardBlack.withValues(alpha: 0.78),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _cardBlack.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -16,
                top: -16,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        ProfileColors.primaryGreen.withValues(alpha: 0.24),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: ProfileColors.primaryGreen
                                .withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: ProfileColors.primaryGreen
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                          child: Center(
                            child: FaIcon(
                              challenge.icon,
                              size: 20,
                              color: ProfileColors.primaryGreen,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                challenge.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.lexendDeca(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                challenge.daysLeftLabel,
                                style: GoogleFonts.lexendDeca(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _daysLeft,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                challenge.participantsLabel,
                                style: GoogleFonts.lexendDeca(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: ProfileColors.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF9CA3AF),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        color: ProfileColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${challenge.formatProgress(progressValue)} / ${challenge.targetLabel}',
                            style: GoogleFonts.lexendDeca(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                          ),
                        ),
                        Text(
                          '${(progress * 100).round()}%',
                          style: GoogleFonts.lexendDeca(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: ProfileColors.primaryGreen,
                          ),
                        ),
                      ],
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

class ProfileStoriesSection extends StatelessWidget {
  const ProfileStoriesSection({
    super.key,
    required this.stories,
    required this.isLoading,
    required this.onStoryTap,
    this.onAddTap,
    this.readOnly = false,
    this.sectionTitle = 'Мои истории',
  });

  final List<StoryItem> stories;
  final bool isLoading;
  final VoidCallback? onAddTap;
  final ValueChanged<StoryItem> onStoryTap;
  final bool readOnly;
  final String sectionTitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileSectionHeader(title: sectionTitle),
          const SizedBox(height: 12),
          if (isLoading && stories.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              ),
            )
          else if (stories.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                readOnly ? 'У пользователя пока нет историй.' : 'Добавьте первую историю.',
                style: profileSubtitleStyle(),
              ),
            )
          else
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: readOnly ? stories.length : stories.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  if (!readOnly && index == 0) {
                    return Align(
                      alignment: Alignment.center,
                      child: _ProfileAddStoryTile(onTap: onAddTap ?? () {}),
                    );
                  }
                  final story = stories[readOnly ? index : index - 1];
                  return Align(
                    alignment: Alignment.center,
                    child: _ProfileStoryTile(
                      story: story,
                      onTap: () => onStoryTap(story),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileAddStoryTile extends StatelessWidget {
  const _ProfileAddStoryTile({required this.onTap});

  static const _tileWidth = 72.0;
  static const _tileHeight = 96.0;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _tileWidth,
        height: _tileHeight,
        decoration: profileElevatedDecoration(radius: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: ProfileColors.primaryGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: ProfileColors.primaryGreen),
            ),
            const SizedBox(height: 8),
            Text('Новая', style: profileSubtitleStyle()),
          ],
        ),
      ),
    );
  }
}

class _ProfileStoryTile extends StatelessWidget {
  const _ProfileStoryTile({required this.story, required this.onTap});

  static const _tileWidth = 72.0;
  static const _tileHeight = 96.0;
  static const _radius = 14.0;
  static const _borderWidth = 2.0;

  final StoryItem story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const innerRadius = _radius - _borderWidth;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _tileWidth,
        height: _tileHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(
            color: ProfileColors.primaryGreen,
            width: _borderWidth,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(innerRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                story.mediaUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: ProfileColors.primaryGreen.withValues(alpha: 0.12),
                  child: const Icon(Icons.image_not_supported_outlined),
                ),
              ),
              if (story.caption != null && story.caption!.isNotEmpty)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    color: Colors.black45,
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      story.caption!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: profileSubtitleStyle(color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileMomentsSection extends StatelessWidget {
  const ProfileMomentsSection({
    super.key,
    required this.moments,
    required this.isLoading,
    required this.onLikeTap,
    required this.onCommentTap,
    this.onAddTap,
    this.onEditTap,
    this.onDeleteTap,
    this.readOnly = false,
    this.sectionTitle = 'Моменты',
    this.emptyMessage =
        'Поделитесь фото и мыслями — моменты появятся в ленте на главной.',
  });

  final List<MomentItem> moments;
  final bool isLoading;
  final VoidCallback? onAddTap;
  final ValueChanged<int> onLikeTap;
  final ValueChanged<int> onCommentTap;
  final ValueChanged<int>? onEditTap;
  final ValueChanged<int>? onDeleteTap;
  final bool readOnly;
  final String sectionTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileSectionHeader(
            title: sectionTitle,
            trailing: readOnly ? null : 'Добавить',
            onTrailingTap: readOnly ? null : onAddTap,
          ),
          const SizedBox(height: 12),
          if (isLoading && moments.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              ),
            )
          else if (moments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                emptyMessage,
                style: profileSubtitleStyle(),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < moments.length; i++)
                  MomentFeedCard(
                    moment: moments[i],
                    compact: true,
                    onLikeTap: () => onLikeTap(i),
                    onCommentTap: () => onCommentTap(i),
                    onEditTap: !readOnly && moments[i].isMe && onEditTap != null
                        ? () => onEditTap!(i)
                        : null,
                    onDeleteTap:
                        !readOnly && moments[i].isMe && onDeleteTap != null
                            ? () => onDeleteTap!(i)
                            : null,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
