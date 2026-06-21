import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/data/services/profile_statistics_service.dart';
import 'package:map_routing/features/profile/presentation/profile_ui.dart';

class StatisticsPeriodComparisonCard extends StatelessWidget {
  const StatisticsPeriodComparisonCard({
    super.key,
    required this.title,
    required this.comparison,
  });

  final String title;
  final ProfilePeriodComparison comparison;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: GoogleFonts.lexendDeca(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ProfileColors.title,
            ),
          ),
          const SizedBox(height: 10),
          _ComparisonRow(
            label: 'Дистанция',
            value:
                '${(comparison.current.distanceM / 1000).toStringAsFixed(1)} км',
            change: comparison.distanceChangePercent,
          ),
          _ComparisonRow(
            label: 'Тренировки',
            value: '${comparison.current.workoutCount}',
            change: comparison.workoutsChangePercent,
          ),
          _ComparisonRow(
            label: 'Время',
            value: ProfileStatisticsService.formatDurationLong(
              comparison.current.duration,
            ),
            change: comparison.durationChangePercent,
          ),
          if (comparison.current.calories > 0)
            _ComparisonRow(
              label: 'Ккал',
              value: '${comparison.current.calories}',
              change: comparison.caloriesChangePercent,
            ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.value,
    required this.change,
  });

  final String label;
  final String value;
  final double? change;

  @override
  Widget build(BuildContext context) {
    final changeValue = change;
    Color changeColor = ProfileColors.body;
    if (changeValue != null) {
      if (changeValue > 0) {
        changeColor = ProfileColors.primaryGreen;
      } else if (changeValue < 0) {
        changeColor = ProfileColors.orange;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: profileSubtitleStyle(),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: GoogleFonts.lexendDeca(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ProfileColors.title,
              ),
            ),
          ),
          if (changeValue != null) ...[
            const SizedBox(width: 6),
            SizedBox(
              width: 44,
              child: Text(
                ProfileStatisticsService.formatChangePercent(changeValue),
                maxLines: 1,
                textAlign: TextAlign.right,
                style: GoogleFonts.lexendDeca(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: changeColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class StatisticsRegularityRow extends StatelessWidget {
  const StatisticsRegularityRow({super.key, required this.stats});

  final ProfileRegularityStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RegularityTile(
          icon: Icons.local_fire_department_outlined,
          title: 'Текущая серия',
          value: stats.currentStreakDays > 0
              ? '${stats.currentStreakDays} ${_daysLabel(stats.currentStreakDays)}'
              : '—',
          hint: stats.longestStreakDays > 0
              ? 'Рекорд: ${stats.longestStreakDays} ${_daysLabel(stats.longestStreakDays)} подряд'
              : 'Дней тренировок подряд без пропуска',
        ),
        const SizedBox(height: 8),
        _RegularityTile(
          icon: Icons.calendar_today_outlined,
          title: 'Активность за месяц',
          value: '${stats.activeDaysThisMonth} из ${stats.daysInCurrentMonth}',
          hint:
              'Дней с тренировкой в ${stats.currentMonthLabel.toLowerCase()} '
              '(из ${stats.daysInCurrentMonth} дней месяца)',
        ),
        const SizedBox(height: 8),
        _RegularityTile(
          icon: Icons.speed_outlined,
          title: 'Средний объём',
          value: stats.avgKmPerWeekThisMonth > 0
              ? '${stats.avgKmPerWeekThisMonth.toStringAsFixed(1)} км/нед'
              : '—',
          hint: 'Средняя дистанция в неделю за текущий месяц',
        ),
      ],
    );
  }

  static String _daysLabel(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'дней';
    if (mod10 == 1) return 'день';
    if (mod10 >= 2 && mod10 <= 4) return 'дня';
    return 'дней';
  }
}

class _RegularityTile extends StatelessWidget {
  const _RegularityTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.hint,
  });

  final IconData icon;
  final String title;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ProfileColors.primaryGreen.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ProfileColors.primaryGreen.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ProfileColors.primaryGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: ProfileColors.primaryGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.lexendDeca(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ProfileColors.title,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: profileSubtitleStyle().copyWith(fontSize: 11, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 96),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: GoogleFonts.lexendDeca(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: ProfileColors.primaryGreen,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StatisticsActivityHeatmap extends StatelessWidget {
  const StatisticsActivityHeatmap({super.key, required this.days});

  final List<ActivityHeatmapDay> days;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();

    final maxDistance = days.fold<double>(
      0,
      (max, day) => day.distanceM > max ? day.distanceM : max,
    );

    const columns = 7;
    final rows = (days.length / columns).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ProfileActivityPatterns.weekdayLabels
              .map(
                (label) => SizedBox(
                  width: 14,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: profileSubtitleStyle().copyWith(fontSize: 9),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        for (var row = 0; row < rows; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: List.generate(columns, (col) {
                final index = row * columns + col;
                if (index >= days.length) {
                  return const Expanded(child: SizedBox(height: 14));
                }
                final day = days[index];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Tooltip(
                      message: day.workoutCount == 0
                          ? _formatDay(day.date)
                          : '${_formatDay(day.date)}\n${day.distanceKm.toStringAsFixed(1)} км · ${day.workoutCount} трен.',
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: _heatColor(day.distanceM, maxDistance),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Color _heatColor(double distanceM, double maxDistance) {
    if (distanceM <= 0) return const Color(0xFFEDF1F3);
    if (maxDistance <= 0) {
      return ProfileColors.primaryGreen.withValues(alpha: 0.35);
    }
    final t = (distanceM / maxDistance).clamp(0.15, 1.0);
    return ProfileColors.primaryGreen.withValues(alpha: 0.15 + t * 0.65);
  }

  String _formatDay(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
}

class StatisticsPatternBars extends StatelessWidget {
  const StatisticsPatternBars({
    super.key,
    required this.title,
    required this.labels,
    required this.values,
    this.valueFormatter,
  });

  final String title;
  final List<String> labels;
  final List<double> values;
  final String Function(double value)? valueFormatter;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<double>(0, math.max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: GoogleFonts.lexendDeca(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: ProfileColors.body,
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 42,
                  child: Text(
                    labels[i],
                    style: profileSubtitleStyle().copyWith(fontSize: 11),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxValue > 0 ? values[i] / maxValue : 0,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFEDF1F3),
                      color: ProfileColors.primaryGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 52,
                  child: Text(
                    valueFormatter?.call(values[i]) ??
                        values[i].toStringAsFixed(1),
                    textAlign: TextAlign.right,
                    style: GoogleFonts.lexendDeca(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ProfileColors.title,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class StatisticsActivityShareRow extends StatelessWidget {
  const StatisticsActivityShareRow({super.key, required this.shares});

  final List<ActivityTypeShare> shares;

  @override
  Widget build(BuildContext context) {
    if (shares.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: shares.map((share) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE3E8EE)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                share.activity.icon,
                size: 16,
                color: ProfileColors.primaryGreen,
              ),
              const SizedBox(width: 6),
              Text(
                share.activity.labelRu,
                style: GoogleFonts.lexendDeca(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ProfileColors.title,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${share.percent.round()}%',
                style: GoogleFonts.lexendDeca(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: ProfileColors.body,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class StatisticsInsightStrip extends StatelessWidget {
  const StatisticsInsightStrip({super.key, required this.totals});

  final ProfileTotals totals;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ProfileColors.orange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ProfileColors.orange.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _InsightItem(
              label: 'Ср. темп',
              value: ProfileStatisticsService.formatPaceMinPerKm(
                totals.avgPaceMinPerKm,
              ),
            ),
          ),
          Container(
            width: 1,
            height: 28,
            color: ProfileColors.orange.withValues(alpha: 0.15),
          ),
          Expanded(
            child: _InsightItem(
              label: 'Ср. время',
              value: ProfileStatisticsService.formatDurationLong(
                totals.avgWorkoutDuration,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightItem extends StatelessWidget {
  const _InsightItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: profileSubtitleStyle().copyWith(fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: GoogleFonts.lexendDeca(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ProfileColors.title,
          ),
        ),
      ],
    );
  }
}
