import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/data/models/workout_activity_type.dart';
import 'package:map_routing/data/models/workout_summary.dart';
import 'package:map_routing/data/services/gpx_workout_service.dart';
import 'package:map_routing/data/services/profile_statistics_service.dart';
import 'package:map_routing/features/profile/presentation/profile_statistics_chart_page.dart';
import 'package:map_routing/features/profile/presentation/profile_ui.dart';
import 'package:map_routing/features/profile/presentation/widgets/profile_statistics_widgets.dart';
import 'package:map_routing/features/profile/presentation/workout_detail_page.dart';

class ProfileStatisticsTab extends StatefulWidget {
  const ProfileStatisticsTab({
    super.key,
    required this.workouts,
    required this.isLoading,
  });

  final List<WorkoutSummary> workouts;
  final bool isLoading;

  @override
  State<ProfileStatisticsTab> createState() => _ProfileStatisticsTabState();
}

class _ProfileStatisticsTabState extends State<ProfileStatisticsTab> {
  WorkoutActivityType? _activityFilter;

  List<WorkoutSummary> get _ownWorkouts =>
      ProfileStatisticsService.filterOwnWorkouts(widget.workouts);

  List<WorkoutSummary> get _filtered =>
      ProfileStatisticsService.filterByActivity(
        _ownWorkouts,
        _activityFilter,
      );

  void _openChart(ProfileStatMetric metric) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileStatisticsChartPage(
          metric: metric,
          workouts: _ownWorkouts,
          activityFilter: _activityFilter,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading && _ownWorkouts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_ownWorkouts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Завершите тренировку на карте — статистика появится здесь.',
          style: profileSubtitleStyle(),
        ),
      );
    }

    final totals = ProfileStatisticsService.computeTotals(_filtered);
    final records = ProfileStatisticsService.computeRecords(_filtered);
    final weekComparison =
        ProfileStatisticsService.computeWeekComparison(_filtered);
    final monthComparison =
        ProfileStatisticsService.computeMonthComparison(_filtered);
    final regularity = ProfileStatisticsService.computeRegularity(_filtered);
    final heatmap = ProfileStatisticsService.buildActivityHeatmap(_filtered);
    final patterns = ProfileStatisticsService.computeActivityPatterns(_filtered);

    return ProfileCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ProfileColors.primaryGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    size: 20,
                    color: ProfileColors.primaryGreen,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Статистика тренировок',
                  style: GoogleFonts.lexendDeca(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: ProfileColors.title,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SubsectionLabel(title: 'Тип тренировки'),
                const SizedBox(height: 10),
                _ActivityFilterBar(
                  selected: _activityFilter,
                  onChanged: (v) => setState(() => _activityFilter = v),
                ),
                const _StatisticsDivider(),
                const _SubsectionLabel(title: 'Сравнение периодов'),
                const SizedBox(height: 12),
                StatisticsPeriodComparisonCard(
                  title: weekComparison.currentLabel,
                  comparison: weekComparison,
                ),
                const SizedBox(height: 10),
                StatisticsPeriodComparisonCard(
                  title: monthComparison.currentLabel,
                  comparison: monthComparison,
                ),
                const _StatisticsDivider(),
                const _SubsectionLabel(title: 'Регулярность'),
                const SizedBox(height: 12),
                StatisticsRegularityRow(stats: regularity),
                const _StatisticsDivider(),
                const _SubsectionLabel(title: 'За всё время'),
                const SizedBox(height: 12),
                _TotalsGrid(totals: totals, onTap: _openChart),
                const SizedBox(height: 10),
                StatisticsInsightStrip(totals: totals),
                const _StatisticsDivider(),
                const _SubsectionLabel(title: 'Активность за 12 недель'),
                const SizedBox(height: 12),
                StatisticsActivityHeatmap(days: heatmap),
                const _StatisticsDivider(),
                const _SubsectionLabel(title: 'Паттерны'),
                const SizedBox(height: 12),
                StatisticsPatternBars(
                  title: 'Дистанция по дням недели, км',
                  labels: ProfileActivityPatterns.weekdayLabels,
                  values: patterns.distanceByWeekday
                      .map((m) => m / 1000)
                      .toList(),
                  valueFormatter: (v) => '${v.toStringAsFixed(1)} км',
                ),
                const SizedBox(height: 14),
                StatisticsPatternBars(
                  title: 'Тренировки по времени суток',
                  labels: ProfileActivityPatterns.timeBucketLabels,
                  values: patterns.workoutsByTimeBucket
                      .map((c) => c.toDouble())
                      .toList(),
                  valueFormatter: (v) => v.round().toString(),
                ),
                if (patterns.activityShares.length > 1) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Типы активности',
                    style: GoogleFonts.lexendDeca(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ProfileColors.body,
                    ),
                  ),
                  const SizedBox(height: 10),
                  StatisticsActivityShareRow(shares: patterns.activityShares),
                ],
                const _StatisticsDivider(),
                const _SubsectionLabel(title: 'Личные рекорды'),
                const SizedBox(height: 12),
                _ProfileRecordCard(
                  icon: Icons.straighten_rounded,
                  title: 'Самый длинный забег',
                  value: records.longestWorkout != null
                      ? WorkoutFormatters.formatDistanceKm(
                          records.longestWorkout!.distanceMeters,
                        )
                      : '—',
                  subtitle: records.longestWorkout?.title,
                  accent: ProfileColors.primaryGreen,
                  onTap: records.longestWorkout != null
                      ? () => _openWorkout(records.longestWorkout!)
                      : null,
                ),
                const SizedBox(height: 10),
                _RecordCardRow(
                  children: [
                    _ProfileRecordCard(
                      icon: Icons.timer_outlined,
                      title: 'По времени',
                      value: records.longestDurationWorkout?.duration != null
                          ? WorkoutFormatters.formatDurationLong(
                              records.longestDurationWorkout!.duration,
                            )
                          : '—',
                      subtitle: records.longestDurationWorkout?.title,
                      compact: true,
                      accent: const Color(0xFF3949AB),
                      onTap: records.longestDurationWorkout != null
                          ? () =>
                                _openWorkout(records.longestDurationWorkout!)
                          : null,
                    ),
                    _ProfileRecordCard(
                      icon: Icons.speed_outlined,
                      title: 'Лучший темп',
                      value: ProfileStatisticsService.formatPaceMinPerKm(
                        records.bestPaceMinPerKm,
                      ),
                      subtitle: records.bestPaceWorkout?.title,
                      compact: true,
                      accent: ProfileColors.orange,
                      onTap: records.bestPaceWorkout != null
                          ? () => _openWorkout(records.bestPaceWorkout!)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _RecordCardRow(
                  children: [
                    _ProfileRecordCard(
                      icon: Icons.calendar_view_week_outlined,
                      title: 'Лучшая неделя',
                      value: records.bestWeekDistanceKm > 0
                          ? '${records.bestWeekDistanceKm.toStringAsFixed(1)} км'
                          : '—',
                      subtitle: records.bestWeekLabel,
                      compact: true,
                      accent: const Color(0xFF00897B),
                    ),
                    _ProfileRecordCard(
                      icon: Icons.calendar_month_outlined,
                      title: 'Лучший месяц',
                      value: records.bestMonthDistanceKm > 0
                          ? '${records.bestMonthDistanceKm.toStringAsFixed(1)} км'
                          : '—',
                      subtitle: records.bestMonthLabel,
                      compact: true,
                      accent: const Color(0xFF6A1B9A),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _RecordCardRow(
                  children: [
                    _ProfileRecordCard(
                      icon: Icons.terrain_rounded,
                      title: 'Подъём',
                      value: records.biggestClimbM > 0
                          ? '${records.biggestClimbM.round()} м'
                          : '—',
                      subtitle: records.biggestClimbWorkout?.title,
                      compact: true,
                      accent: const Color(0xFF5C6BC0),
                      onTap: records.biggestClimbWorkout != null
                          ? () => _openWorkout(records.biggestClimbWorkout!)
                          : null,
                    ),
                    _ProfileRecordCard(
                      icon: Icons.trending_up_rounded,
                      title: 'Набор без спада',
                      value: records.sustainedAscentM > 0
                          ? '${records.sustainedAscentM.round()} м'
                          : '—',
                      subtitle: records.sustainedAscentWorkout?.title,
                      compact: true,
                      accent: const Color(0xFF00897B),
                      onTap: records.sustainedAscentWorkout != null
                          ? () => _openWorkout(records.sustainedAscentWorkout!)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Лучшее время на дистанции',
                  style: GoogleFonts.lexendDeca(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ProfileColors.body,
                  ),
                ),
                const SizedBox(height: 10),
                ...records.distanceRecords.map(
                  (record) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ProfileRecordCard(
                      icon: Icons.timer_outlined,
                      title: record.label,
                      value: ProfileStatisticsService.formatSplitDuration(
                        record.bestDuration,
                      ),
                      subtitle: record.workout?.title,
                      compact: true,
                      showOpenAction: false,
                      accent: ProfileColors.orange,
                      onTap: record.workout != null
                          ? () => _openWorkout(record.workout!)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openWorkout(WorkoutSummary workout) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WorkoutDetailPage(workout: workout)),
    );
  }
}

class _SubsectionLabel extends StatelessWidget {
  const _SubsectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.lexendDeca(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: ProfileColors.title,
      ),
    );
  }
}

class _StatisticsDivider extends StatelessWidget {
  const _StatisticsDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Divider(
        height: 1,
        thickness: 1,
        color: ProfileColors.body.withValues(alpha: 0.12),
      ),
    );
  }
}

class _ActivityFilterBar extends StatelessWidget {
  const _ActivityFilterBar({required this.selected, required this.onChanged});

  final WorkoutActivityType? selected;
  final ValueChanged<WorkoutActivityType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'Все',
            icon: Icons.grid_view_rounded,
            selected: selected == null,
            onTap: () => onChanged(null),
          ),
          ...WorkoutActivityType.values.map(
            (type) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _FilterChip(
                label: type.labelRu,
                icon: type.icon,
                selected: selected == type,
                onTap: () => onChanged(type),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: selected ? ProfileColors.title : ProfileColors.body,
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: ProfileColors.primaryGreen.withValues(alpha: 0.2),
      checkmarkColor: ProfileColors.primaryGreen,
      labelStyle: GoogleFonts.lexendDeca(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: ProfileColors.title,
      ),
      side: BorderSide(
        color: selected ? ProfileColors.primaryGreen : const Color(0xFFE0E0E0),
      ),
    );
  }
}

class _TotalsGrid extends StatelessWidget {
  const _TotalsGrid({required this.totals, required this.onTap});

  final ProfileTotals totals;
  final ValueChanged<ProfileStatMetric> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _TotalCard(
                icon: Icons.fitness_center_outlined,
                label: 'Тренировки',
                value: ProfileStatisticsService.formatTotalValue(
                  ProfileStatMetric.workouts,
                  totals,
                ),
                onTap: () => onTap(ProfileStatMetric.workouts),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TotalCard(
                icon: Icons.straighten,
                label: 'Дистанция',
                value: ProfileStatisticsService.formatTotalValue(
                  ProfileStatMetric.distance,
                  totals,
                ),
                onTap: () => onTap(ProfileStatMetric.distance),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _TotalCard(
                icon: Icons.timer_outlined,
                label: 'Время',
                value: ProfileStatisticsService.formatTotalValue(
                  ProfileStatMetric.duration,
                  totals,
                ),
                onTap: () => onTap(ProfileStatMetric.duration),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TotalCard(
                icon: Icons.terrain,
                label: 'Набор высоты',
                value: ProfileStatisticsService.formatTotalValue(
                  ProfileStatMetric.elevation,
                  totals,
                ),
                onTap: () => onTap(ProfileStatMetric.elevation),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _TotalCard(
                icon: Icons.local_fire_department_outlined,
                label: 'Ккал',
                value: ProfileStatisticsService.formatTotalValue(
                  ProfileStatMetric.calories,
                  totals,
                ),
                onTap: () => onTap(ProfileStatMetric.calories),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TotalCard(
                icon: Icons.calendar_month_outlined,
                label: 'Активных дней',
                value: '${totals.activeDays}',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RecordCardRow extends StatelessWidget {
  const _RecordCardRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Ink(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: ProfileColors.primaryGreen),
              const Spacer(),
              if (onTap != null)
                Icon(
                  Icons.bar_chart_rounded,
                  size: 16,
                  color: ProfileColors.body.withValues(alpha: 0.7),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.lexendDeca(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: ProfileColors.body,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: GoogleFonts.lexendDeca(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: ProfileColors.title,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return Material(
        color: const Color(0xFFFBFBFB),
        borderRadius: BorderRadius.circular(14),
        child: content,
      );
    }

    return Material(
      color: const Color(0xFFFBFBFB),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: content,
      ),
    );
  }
}

class _ProfileRecordCard extends StatelessWidget {
  const _ProfileRecordCard({
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
    this.onTap,
    this.compact = false,
    this.showOpenAction = true,
    this.accent = ProfileColors.primaryGreen,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool compact;
  final bool showOpenAction;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final valueFontSize = compact ? 20.0 : 26.0;
    final padding = compact
        ? const EdgeInsets.all(14)
        : const EdgeInsets.symmetric(horizontal: 18, vertical: 20);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent.withValues(alpha: 0.08), const Color(0xFFFBFBFB)],
            ),
            border: Border.all(
              color: accent.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: compact ? 148 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.lexendDeca(
                              fontSize: compact ? 12 : 13,
                              fontWeight: FontWeight.w600,
                              color: ProfileColors.body,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: compact ? 32 : 38,
                          height: compact ? 32 : 38,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(compact ? 10 : 12),
                          ),
                          child: Icon(
                            icon,
                            color: accent,
                            size: compact ? 17 : 20,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 10 : 14),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        maxLines: 1,
                        style: GoogleFonts.lexendDeca(
                          fontSize: valueFontSize,
                          fontWeight: FontWeight.w800,
                          color: accent,
                          height: 1.05,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: compact ? 30 : 18,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          subtitle ?? '',
                          maxLines: compact ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.lexendDeca(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: ProfileColors.body.withValues(alpha: 0.85),
                            height: 1.25,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 22,
                  child: onTap != null && showOpenAction
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Открыть',
                              style: GoogleFonts.lexendDeca(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: accent,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: accent,
                            ),
                          ],
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
