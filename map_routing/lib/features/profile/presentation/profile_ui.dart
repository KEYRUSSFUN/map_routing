import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/network/backend_urls.dart';
import 'package:map_routing/data/models/challenge.dart';
import 'package:map_routing/data/models/moment.dart';
import 'package:map_routing/data/models/story.dart';
import 'package:map_routing/features/moments/presentation/moment_feed_card.dart';

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

enum ProfileTab { statistics, achievements, history }

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
    this.onAvatarTap,
    this.onBack,
    this.onSettings,
    this.statPills = const [],
  });

  final String name;
  final String location;
  final String subtitle;
  final String? avatarUrl;
  final VoidCallback? onAvatarTap;
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/profile/cover.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.2),
                          Colors.black.withValues(alpha: 0.05),
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white,
                        ],
                        stops: const [0.0, 0.45, 0.78, 1.0],
                      ),
                    ),
                  ),
                ],
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

  static const _labels = {
    ProfileTab.statistics: 'Статистика',
    ProfileTab.achievements: 'Достижения',
    ProfileTab.history: 'История',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: profileElevatedDecoration(
          backgroundColor: ProfileColors.cardBg,
          radius: 14,
        ),
        child: Row(
          children: [
            for (var i = 0; i < ProfileTab.values.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: _ProfileTabItem(
                  label: _labels[ProfileTab.values[i]]!,
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
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? ProfileColors.tabActive : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.lexendDeca(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? ProfileColors.title : ProfileColors.body,
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
    this.highlighted = false,
  });

  final String label;
  final IconData icon;
  final bool locked;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: locked ? Colors.grey.shade200 : Colors.white,
            border: Border.all(
              color: locked
                  ? Colors.grey.shade300
                  : (highlighted
                        ? ProfileColors.orange
                        : ProfileColors.orangeBorder),
              width: highlighted ? 2.5 : 1.5,
            ),
          ),
          child: Icon(
            locked ? Icons.lock_outline : icon,
            color: locked ? ProfileColors.body : ProfileColors.orange,
            size: 26,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 72,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.lexendDeca(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: ProfileColors.body,
              height: 1.2,
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

  @override
  Widget build(BuildContext context) {
    final cardTap = selectionMode
        ? () => onSelectedChanged?.call(!selected)
        : onTap;

    return ProfileCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectionMode) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 4),
                  child: Checkbox(
                    value: selected,
                    activeColor: ProfileColors.primaryGreen,
                    onChanged: (value) =>
                        onSelectedChanged?.call(value ?? false),
                  ),
                ),
              ],
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: cardTap,
                  onLongPress: selectionMode ? null : onLongPress,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: ProfileColors.primaryGreen,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: profileTitleStyle(size: 16)),
                            const SizedBox(height: 2),
                            Text(subtitle, style: profileSubtitleStyle()),
                            if (detailLine != null &&
                                detailLine!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                detailLine!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: profileSubtitleStyle(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!selectionMode && onShowOnMap != null) ...[
                const SizedBox(width: 4),
                Material(
                  color: ProfileColors.primaryGreen,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onShowOnMap,
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.map_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  for (var i = 0; i < stats.length; i++)
                    Expanded(
                      child: _ActivityStatItem(
                        stat: stats[i],
                        alignment: _statAlignment(i, stats.length),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
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
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ProfileColors.title,
            ),
          ),
          Text(stat.label, style: profileSubtitleStyle()),
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

    return RepaintBoundary(
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

  @override
  Widget build(BuildContext context) {
    final progressValue = challenge.myProgress ?? 0;

    return ProfileCard(
      padding: const EdgeInsets.all(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ProfileColors.primaryGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: FaIcon(
                      challenge.icon,
                      size: 18,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: profileTitleStyle(size: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        challenge.statusLabel,
                        style: profileSubtitleStyle(),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: ProfileColors.body),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: challenge.progressPercent,
                minHeight: 6,
                backgroundColor: const Color(0xFFECECEC),
                color: ProfileColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${challenge.formatProgress(progressValue)} / ${challenge.targetLabel}',
                  style: profileSubtitleStyle(
                    color: ProfileColors.title,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '${(challenge.progressPercent * 100).round()}%',
                  style: profileSubtitleStyle(),
                ),
              ],
            ),
          ],
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
    required this.onAddTap,
    required this.onStoryTap,
  });

  final List<StoryItem> stories;
  final bool isLoading;
  final VoidCallback onAddTap;
  final ValueChanged<StoryItem> onStoryTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileSectionHeader(
            title: 'Мои истории',
            trailing: 'Добавить',
            onTrailingTap: onAddTap,
          ),
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
                'Опубликуйте историю — друзья увидят её на главной.',
                style: profileSubtitleStyle(),
              ),
            )
          else
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: stories.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Align(
                      alignment: Alignment.center,
                      child: _ProfileAddStoryTile(onTap: onAddTap),
                    );
                  }
                  final story = stories[index - 1];
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
    required this.onAddTap,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onDeleteTap,
  });

  final List<MomentItem> moments;
  final bool isLoading;
  final VoidCallback onAddTap;
  final ValueChanged<int> onLikeTap;
  final ValueChanged<int> onCommentTap;
  final ValueChanged<int> onDeleteTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileSectionHeader(
            title: 'Моменты',
            trailing: 'Добавить',
            onTrailingTap: onAddTap,
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
                'Поделитесь фото и мыслями — моменты появятся в ленте на главной.',
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
                    onDeleteTap: moments[i].isMe ? () => onDeleteTap(i) : null,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
