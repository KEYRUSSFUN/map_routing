import 'dart:math' as math;

import 'package:map_routing/data/models/track_point.dart';
import 'package:map_routing/data/models/workout_summary.dart';

/// Расчёт метрик тренировки для экрана деталей и графиков.
class WorkoutAnalytics {
  WorkoutAnalytics({
    required this.elevationGainM,
    required this.chartPoints,
  });

  final double elevationGainM;
  final List<WorkoutChartPoint> chartPoints;

  factory WorkoutAnalytics.fromWorkout(WorkoutSummary workout) {
    final computedGain = computeElevationGain(workout.points);
    final gain = workout.elevationGainM > 0 ? workout.elevationGainM : computedGain;

    final charts = buildChartPoints(workout.points);
    final chartPoints = charts.isNotEmpty ? charts : workout.chartPoints;

    return WorkoutAnalytics(
      elevationGainM: gain,
      chartPoints: chartPoints,
    );
  }

  static double computeElevationGain(List<TrackPoint> points) {
    var gain = 0.0;
    double? prev;

    for (final point in points) {
      final ele = point.elevation;
      if (ele == null) continue;
      if (prev != null && ele > prev) {
        gain += ele - prev;
      }
      prev = ele;
    }

    return gain;
  }

  static List<WorkoutChartPoint> buildChartPoints(List<TrackPoint> points) {
    if (points.length < 2) return [];

    const targetSegments = 12;
    final segmentCount = math.min(targetSegments, points.length - 1);
    final chart = <WorkoutChartPoint>[];

    for (var seg = 0; seg < segmentCount; seg++) {
      final startIdx = (seg * (points.length - 1) / segmentCount).floor();
      final endIdx =
          ((seg + 1) * (points.length - 1) / segmentCount).ceil().clamp(
                startIdx + 1,
                points.length - 1,
              );

      final slice = points.sublist(startIdx, endIdx + 1);
      if (slice.length < 2) continue;

      final distanceM = _totalDistanceMeters(slice);
      final duration = _durationFromPoints(slice);
      final overallDuration = _durationFromPoints(points);

      Duration? effectiveDuration = duration;
      if ((effectiveDuration == null || effectiveDuration.inSeconds <= 0) &&
          overallDuration != null &&
          overallDuration.inSeconds > 0) {
        final totalDist = _totalDistanceMeters(points);
        if (totalDist > 0 && distanceM > 0) {
          final fraction = distanceM / totalDist;
          effectiveDuration = Duration(
            milliseconds: (overallDuration.inMilliseconds * fraction).round(),
          );
        }
      }

      final pace = distanceM > 0 &&
              effectiveDuration != null &&
              effectiveDuration.inSeconds > 0
          ? (effectiveDuration.inSeconds / 60) / (distanceM / 1000)
          : null;
      final speedKmh = distanceM > 0 &&
              effectiveDuration != null &&
              effectiveDuration.inSeconds > 0
          ? (distanceM / 1000) / (effectiveDuration.inSeconds / 3600)
          : null;

      final elevations = slice.map((p) => p.elevation).whereType<double>().toList();
      final avgEle = elevations.isEmpty
          ? 0.0
          : elevations.reduce((a, b) => a + b) / elevations.length;

      chart.add(
        WorkoutChartPoint(
          index: seg + 1,
          paceMinPerKm: (pace ?? 0).clamp(2.0, 20.0),
          elevationM: avgEle,
          speedKmh: (speedKmh ?? 0).clamp(0.0, 45.0),
        ),
      );
    }

    return chart;
  }

  static double _totalDistanceMeters(List<TrackPoint> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += _haversineMeters(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    return total;
  }

  static Duration? _durationFromPoints(List<TrackPoint> points) {
    final times = points.map((p) => p.time).whereType<DateTime>().toList();
    if (times.length < 2) return null;
    times.sort();
    final diff = times.last.difference(times.first);
    return diff.inSeconds > 0 ? diff : null;
  }

  static double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _degToRad(double deg) => deg * math.pi / 180.0;
}
