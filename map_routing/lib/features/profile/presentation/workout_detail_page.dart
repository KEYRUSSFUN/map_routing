import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/data/models/track_point.dart';
import 'package:map_routing/data/models/workout_activity_type.dart';
import 'package:map_routing/data/models/workout_summary.dart';
import 'package:map_routing/data/services/gpx_workout_service.dart';
import 'package:map_routing/features/profile/presentation/profile_ui.dart';

class WorkoutDetailPage extends StatelessWidget {
  const WorkoutDetailPage({super.key, required this.workout});

  final WorkoutSummary workout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RoutePreviewCard(
                      points: workout.points,
                      activityType: workout.activityType,
                    ),
                    const SizedBox(height: 16),
                    _MetricsGrid(workout: workout),
                    const SizedBox(height: 16),
                    _PerformanceCard(workout: workout),
                    const SizedBox(height: 16),
                    _SecondaryMetricsRow(workout: workout),
                    if (_hasWorkoutDetails(workout)) ...[
                      const SizedBox(height: 16),
                      _WorkoutDetailsCard(workout: workout),
                    ],
                    const SizedBox(height: 20),
                    _buildActions(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          Expanded(
            child: Text(
              workout.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.lexendDeca(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ProfileColors.title,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Редактирование скоро будет доступно')),
              );
            },
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    const height = 48.0;
    final labelStyle = GoogleFonts.lexendDeca(
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: height,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Поделиться: скоро')),
                );
              },
              icon: const Icon(Icons.share_outlined, size: 20, color: Colors.black87),
              label: Text('Поделиться', style: labelStyle.copyWith(color: Colors.black87)),
              style: ElevatedButton.styleFrom(
                backgroundColor: ProfileColors.primaryGreen,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: height,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Маршрут сохранён: ${workout.title}')),
                );
              },
              icon: const Icon(Icons.bookmark_border, size: 20),
              label: Text('Сохранить маршрут', style: labelStyle),
              style: OutlinedButton.styleFrom(
                foregroundColor: ProfileColors.title,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                side: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoutePreviewCard extends StatelessWidget {
  const _RoutePreviewCard({
    required this.points,
    this.activityType,
  });

  final List<TrackPoint> points;
  final WorkoutActivityType? activityType;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFDCEFE2), Color(0xFFF4F8F5)],
            ),
            border: Border.all(color: const Color(0xFFE6E6E6)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CustomPaint(
              painter: _RoutePainter(points),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: -18,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: ProfileColors.primaryGreen,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    activityType?.icon ?? Icons.directions_run,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    (activityType?.labelRu ?? 'БЕГ').toUpperCase(),
                    style: GoogleFonts.lexendDeca(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.points);

  final List points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final lats = points.map((p) => p.latitude).toList();
    final lons = points.map((p) => p.longitude).toList();
    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLon = lons.reduce((a, b) => a < b ? a : b);
    final maxLon = lons.reduce((a, b) => a > b ? a : b);

    final latRange = (maxLat - minLat).abs() < 1e-6 ? 1e-6 : maxLat - minLat;
    final lonRange = (maxLon - minLon).abs() < 1e-6 ? 1e-6 : maxLon - minLon;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = ((points[i].longitude - minLon) / lonRange) * (size.width - 40) + 20;
      final y = (1 - (points[i].latitude - minLat) / latRange) * (size.height - 40) + 20;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = ProfileColors.primaryGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.workout});

  final WorkoutSummary workout;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                icon: Icons.straighten,
                label: 'ДИСТАНЦИЯ',
                value: WorkoutFormatters.formatDistanceKm(workout.distanceMeters),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                icon: Icons.timer_outlined,
                label: 'ДЛИТЕЛЬНОСТЬ',
                value: WorkoutFormatters.formatDuration(workout.duration),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                icon: Icons.speed_outlined,
                label: 'СРЕДНЯЯ СКОРОСТЬ',
                value: WorkoutFormatters.formatSpeed(workout.avgSpeedKmh),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                icon: Icons.terrain,
                label: 'НАБОР ВЫСОТЫ',
                value: '${workout.elevationGainM.round()} м',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: profileElevatedDecoration(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: ProfileColors.body),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.lexendDeca(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: ProfileColors.body,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.lexendDeca(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: ProfileColors.title,
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({required this.workout});

  final WorkoutSummary workout;

  @override
  Widget build(BuildContext context) {
    final chart = workout.chartPoints;
    if (chart.isEmpty) return const SizedBox.shrink();

    final paceSpots = chart
        .map((p) => FlSpot(p.index.toDouble(), p.paceMinPerKm))
        .toList();
    final speedSpots = chart
        .map((p) => FlSpot(p.index.toDouble(), p.speedKmh))
        .toList();
    final elevSpots = chart
        .map((p) => FlSpot(p.index.toDouble(), p.elevationM))
        .toList();

    final maxPace = paceSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final maxSpeed = speedSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final maxElev = elevSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: profileElevatedDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Показатели', style: profileSectionTitleStyle()),
              const Spacer(),
              _LegendDot(color: ProfileColors.primaryGreen, label: 'Темп'),
              const SizedBox(width: 10),
              _LegendDot(color: ProfileColors.orange, label: 'Высота'),
            ],
          ),
          const SizedBox(height: 16),
          Text('Темп (мин/км)', style: profileSubtitleStyle()),
          const SizedBox(height: 8),
          _WorkoutLineChart(
            spots: paceSpots,
            maxY: maxPace * 1.2,
            color: ProfileColors.primaryGreen,
          ),
          const SizedBox(height: 16),
          Text('Скорость (км/ч)', style: profileSubtitleStyle()),
          const SizedBox(height: 8),
          _WorkoutLineChart(
            spots: speedSpots,
            maxY: maxSpeed * 1.2,
            color: const Color(0xFF00BFA5),
          ),
          const SizedBox(height: 16),
          Text('Высота (м)', style: profileSubtitleStyle()),
          const SizedBox(height: 8),
          _WorkoutLineChart(
            spots: elevSpots,
            maxY: maxElev < 1 ? 1 : maxElev * 1.2,
            color: ProfileColors.orange,
          ),
        ],
      ),
    );
  }
}

class _WorkoutLineChart extends StatelessWidget {
  const _WorkoutLineChart({
    required this.spots,
    required this.maxY,
    required this.color,
  });

  final List<FlSpot> spots;
  final double maxY;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final safeMaxY = maxY < 0.1 ? 1.0 : maxY;
    return SizedBox(
      height: 120,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: safeMaxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: safeMaxY / 2,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: Color(0xFFECECEC),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) => Text(
                  value.toInt().toString(),
                  style: profileSubtitleStyle(),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2.5,
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.15),
              ),
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: profileSubtitleStyle()),
      ],
    );
  }
}

class _SecondaryMetricsRow extends StatelessWidget {
  const _SecondaryMetricsRow({required this.workout});

  final WorkoutSummary workout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: profileElevatedDecoration(radius: 14),
      child: Row(
        children: [
          Expanded(
            child: _SecondaryMetric(
              value: workout.calories?.toString() ?? '—',
              label: 'Калории',
            ),
          ),
          Container(width: 1, height: 36, color: const Color(0xFFE8E8E8)),
          Expanded(
            child: _SecondaryMetric(
              value: workout.avgHeartRate?.toString() ?? '—',
              label: 'Средний пульс',
              valueColor: ProfileColors.orange,
            ),
          ),
          Container(width: 1, height: 36, color: const Color(0xFFE8E8E8)),
          Expanded(
            child: _SecondaryMetric(
              value: workout.cadenceSpm?.toString() ?? '—',
              label: 'Каденс',
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryMetric extends StatelessWidget {
  const _SecondaryMetric({
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
        Text(
          value,
          style: GoogleFonts.lexendDeca(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: valueColor ?? ProfileColors.title,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: profileSubtitleStyle()),
      ],
    );
  }
}

bool _hasWorkoutDetails(WorkoutSummary workout) {
  return (workout.description?.isNotEmpty ?? false) ||
      workout.tags.isNotEmpty ||
      (workout.notes?.isNotEmpty ?? false) ||
      workout.effortLevel != null ||
      workout.privacy != null ||
      (workout.photoPath?.isNotEmpty ?? false);
}

class _WorkoutDetailsCard extends StatelessWidget {
  const _WorkoutDetailsCard({required this.workout});

  final WorkoutSummary workout;

  @override
  Widget build(BuildContext context) {
    return ProfileCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'О тренировке',
            style: GoogleFonts.lexendDeca(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ProfileColors.title,
            ),
          ),
          if (workout.activityType != null) ...[
            const SizedBox(height: 12),
            _DetailRow(
              label: 'Тип',
              value: workout.activityType!.labelRu,
            ),
          ],
          if (workout.effortLevel != null) ...[
            const SizedBox(height: 10),
            _DetailRow(
              label: 'Нагрузка',
              value: '${workout.effortLevel} из 5',
            ),
          ],
          if (workout.privacy != null) ...[
            const SizedBox(height: 10),
            _DetailRow(
              label: 'Видимость',
              value: workout.privacy!.labelRu,
            ),
          ],
          if (workout.description?.isNotEmpty ?? false) ...[
            const SizedBox(height: 10),
            _DetailRow(
              label: 'Описание',
              value: workout.description!,
            ),
          ],
          if (workout.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Теги', style: profileSubtitleStyle()),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: workout.tags
                  .map(
                    (tag) => Chip(
                      label: Text(tag),
                      backgroundColor: ProfileColors.primaryGreen
                          .withValues(alpha: 0.12),
                      side: BorderSide.none,
                      labelStyle: GoogleFonts.lexendDeca(
                        fontSize: 12,
                        color: ProfileColors.title,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (workout.notes?.isNotEmpty ?? false) ...[
            const SizedBox(height: 10),
            _DetailRow(
              label: 'Заметка',
              value: workout.notes!,
            ),
          ],
          if (workout.photoPath != null &&
              File(workout.photoPath!).existsSync()) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(workout.photoPath!),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: profileSubtitleStyle()),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.lexendDeca(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: ProfileColors.title,
          ),
        ),
      ],
    );
  }
}
