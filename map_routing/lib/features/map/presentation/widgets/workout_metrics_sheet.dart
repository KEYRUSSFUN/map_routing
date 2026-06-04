import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/features/map/presentation/map_ui_styles.dart';

class WorkoutMetricsSheet extends StatelessWidget {
  const WorkoutMetricsSheet({
    super.key,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.steps,
    required this.cadence,
    required this.ascentRate,
    required this.activityLabel,
  });

  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final int steps;
  final int cadence;
  final double ascentRate;
  final String activityLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'Дополнительные метрики',
              style: GoogleFonts.lexendDeca(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: MapUiColors.title,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(activityLabel, style: mapMetricLabelStyle()),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                _MetricRow(label: 'Средняя скорость', value: '${avgSpeedKmh.toStringAsFixed(1)} км/ч'),
                _MetricRow(label: 'Макс. скорость', value: '${maxSpeedKmh.toStringAsFixed(1)} км/ч'),
                _MetricRow(label: 'Шаги (оценка)', value: '$steps'),
                _MetricRow(label: 'Каденс (оценка)', value: '$cadence шаг/мин'),
                _MetricRow(label: 'Набор высоты/ч', value: '${ascentRate.toStringAsFixed(0)} м/ч'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(child: Text(label, style: mapMetricLabelStyle(color: MapUiColors.title))),
          Text(
            value,
            style: GoogleFonts.lexendDeca(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: MapUiColors.title,
            ),
          ),
        ],
      ),
    );
  }
}
