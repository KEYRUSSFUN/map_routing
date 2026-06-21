import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/data/models/workout_activity_type.dart';
import 'package:map_routing/data/models/workout_summary.dart';
import 'package:map_routing/data/services/profile_statistics_service.dart';
import 'package:map_routing/features/profile/presentation/profile_ui.dart';

class ProfileStatisticsChartPage extends StatefulWidget {
  const ProfileStatisticsChartPage({
    super.key,
    required this.metric,
    required this.workouts,
    this.activityFilter,
  });

  final ProfileStatMetric metric;
  final List<WorkoutSummary> workouts;
  final WorkoutActivityType? activityFilter;

  @override
  State<ProfileStatisticsChartPage> createState() =>
      _ProfileStatisticsChartPageState();
}

class _ProfileStatisticsChartPageState extends State<ProfileStatisticsChartPage> {
  ProfileStatPeriod _period = ProfileStatPeriod.month;
  late DateTime _anchor;

  @override
  void initState() {
    super.initState();
    _anchor = DateTime.now();
  }

  List<WorkoutSummary> get _filtered =>
      ProfileStatisticsService.filterByActivity(
        widget.workouts,
        widget.activityFilter,
      );

  List<StatTrendPoint> get _trend => ProfileStatisticsService.buildTrend(
        workouts: _filtered,
        metric: widget.metric,
        period: _period,
        anchor: _anchor,
      );

  void _onPeriodChanged(ProfileStatPeriod period) {
    setState(() {
      _period = period;
      _anchor = DateTime.now();
    });
  }

  void _shiftAnchor(int delta) {
    setState(() {
      _anchor = ProfileStatisticsService.shiftAnchor(
        _period,
        _anchor,
        delta,
      );
    });
  }

  bool _canShift(int delta) => ProfileStatisticsService.canShiftAnchor(
        period: _period,
        anchor: _anchor,
        delta: delta,
        workouts: _filtered,
      );

  int _labelInterval(int pointCount) {
    if (_period == ProfileStatPeriod.week) return 1;
    if (_period == ProfileStatPeriod.year) return 1;
    if (_period == ProfileStatPeriod.allTime) {
      return pointCount > 12 ? 2 : 1;
    }
    if (pointCount <= 10) return 1;
    if (pointCount <= 20) return 2;
    if (pointCount <= 28) return 4;
    return 5;
  }

  bool _shouldShowLabel(int index, int total, int interval) {
    if (index == 0 || index == total - 1) return true;
    return index % interval == 0;
  }

  @override
  Widget build(BuildContext context) {
    final trend = _trend;
    final maxY = trend.isEmpty
        ? 1.0
        : trend.map((p) => p.value).reduce((a, b) => a > b ? a : b) * 1.15;
    final labelInterval = _labelInterval(trend.length);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F7),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: Colors.black,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.metric.title,
          style: GoogleFonts.lexendDeca(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: ProfileColors.title,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PeriodSelector(
              selected: _period,
              onChanged: _onPeriodChanged,
            ),
            if (_period != ProfileStatPeriod.allTime) ...[
              const SizedBox(height: 12),
              _PeriodNavigator(
                label: ProfileStatisticsService.formatAnchorLabel(
                  _period,
                  _anchor,
                ),
                canGoBack: _canShift(-1),
                canGoForward: _canShift(1),
                onBack: () => _shiftAnchor(-1),
                onForward: () => _shiftAnchor(1),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: trend.isEmpty
                  ? Center(
                      child: Text(
                        'Нет данных за выбранный период',
                        style: profileSubtitleStyle(),
                      ),
                    )
                  : ProfileCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _periodDescription(),
                            style: profileSubtitleStyle(),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: BarChart(
                              BarChartData(
                                maxY: maxY < 0.01 ? 1 : maxY,
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  getDrawingHorizontalLine: (_) => FlLine(
                                    color: Colors.grey.shade200,
                                    strokeWidth: 1,
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                barTouchData: BarTouchData(
                                  touchTooltipData: BarTouchTooltipData(
                                    getTooltipItem:
                                        (group, groupIndex, rod, rodIndex) {
                                      return BarTooltipItem(
                                        _barTooltipLabel(rod.toY),
                                        GoogleFonts.lexendDeca(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                titlesData: FlTitlesData(
                                  leftTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 32,
                                      getTitlesWidget: (value, meta) {
                                        final index = value.toInt();
                                        if (index < 0 || index >= trend.length) {
                                          return const SizedBox.shrink();
                                        }
                                        if (!_shouldShowLabel(
                                          index,
                                          trend.length,
                                          labelInterval,
                                        )) {
                                          return const SizedBox.shrink();
                                        }
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Text(
                                            trend[index].label,
                                            style: GoogleFonts.lexendDeca(
                                              fontSize: _period ==
                                                      ProfileStatPeriod.month
                                                  ? 9
                                                  : 11,
                                              fontWeight: FontWeight.w500,
                                              color: ProfileColors.body,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                barGroups: List.generate(trend.length, (i) {
                                  return BarChartGroupData(
                                    x: i,
                                    barRods: [
                                      BarChartRodData(
                                        toY: trend[i].value,
                                        width: _barWidth(trend.length),
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
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            if (trend.isNotEmpty)
              Text(
                'Сумма за период: ${_sumLabel(trend)}',
                textAlign: TextAlign.center,
                style: GoogleFonts.lexendDeca(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ProfileColors.title,
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _barWidth(int count) {
    if (count <= 7) return 18;
    if (count <= 12) return 14;
    if (count <= 20) return 10;
    return 6;
  }

  String _barTooltipLabel(double value) {
    switch (widget.metric) {
      case ProfileStatMetric.workouts:
        return value.round().toString();
      case ProfileStatMetric.distance:
        return '${value.toStringAsFixed(2)} км';
      case ProfileStatMetric.duration:
        final totalMinutes = (value * 60).round();
        final h = totalMinutes ~/ 60;
        final m = totalMinutes % 60;
        if (h > 0) return '$h ч $m м';
        return '$m м';
      case ProfileStatMetric.elevation:
        return '${value.toStringAsFixed(2)} м';
      case ProfileStatMetric.calories:
        return '${value.round()} ккал';
    }
  }

  String _periodDescription() {
    return switch (_period) {
      ProfileStatPeriod.week => 'По дням недели',
      ProfileStatPeriod.month => 'По дням месяца',
      ProfileStatPeriod.year => 'По месяцам года',
      ProfileStatPeriod.allTime => 'За всё время',
    };
  }

  String _sumLabel(List<StatTrendPoint> trend) {
    final sum = trend.fold<double>(0, (s, p) => s + p.value);
    return ProfileStatisticsService.formatTrendValue(widget.metric, sum);
  }
}

class _PeriodNavigator extends StatelessWidget {
  const _PeriodNavigator({
    required this.label,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
  });

  final String label;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: profileElevatedDecoration(radius: 14),
      child: Row(
        children: [
          IconButton(
            onPressed: canGoBack ? onBack : null,
            icon: const Icon(Icons.chevron_left_rounded),
            color: ProfileColors.title,
            disabledColor: ProfileColors.body.withValues(alpha: 0.35),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.lexendDeca(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ProfileColors.title,
              ),
            ),
          ),
          IconButton(
            onPressed: canGoForward ? onForward : null,
            icon: const Icon(Icons.chevron_right_rounded),
            color: ProfileColors.title,
            disabledColor: ProfileColors.body.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selected,
    required this.onChanged,
  });

  final ProfileStatPeriod selected;
  final ValueChanged<ProfileStatPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: profileElevatedDecoration(radius: 14),
      child: Row(
        children: ProfileStatPeriod.values.map((period) {
          final isActive = period == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(period),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive
                      ? ProfileColors.tabActive
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  period.label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lexendDeca(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive
                        ? ProfileColors.title
                        : ProfileColors.body,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
