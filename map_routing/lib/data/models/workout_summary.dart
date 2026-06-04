import 'package:map_routing/data/models/track_point.dart';
import 'package:map_routing/data/models/workout_activity_type.dart';

class WorkoutChartPoint {
  const WorkoutChartPoint({
    required this.index,
    required this.paceMinPerKm,
    required this.elevationM,
    required this.speedKmh,
  });

  final int index;
  final double paceMinPerKm;
  final double elevationM;
  final double speedKmh;
}

class WorkoutSummary {
  const WorkoutSummary({
    required this.id,
    required this.title,
    required this.filePath,
    required this.startedAt,
    required this.distanceMeters,
    required this.duration,
    required this.avgSpeedKmh,
    required this.elevationGainM,
    required this.calories,
    required this.avgHeartRate,
    required this.cadenceSpm,
    required this.points,
    required this.chartPoints,
    this.activityType,
    this.description,
    this.tags = const [],
    this.photoPath,
    this.effortLevel,
    this.notes,
    this.privacy,
  });

  final String id;
  final String title;
  final String filePath;
  final DateTime? startedAt;
  final double distanceMeters;
  final Duration? duration;
  final double? avgSpeedKmh;
  final double elevationGainM;
  final int? calories;
  final int? avgHeartRate;
  final int? cadenceSpm;
  final List<TrackPoint> points;
  final List<WorkoutChartPoint> chartPoints;
  final WorkoutActivityType? activityType;
  final String? description;
  final List<String> tags;
  final String? photoPath;
  final int? effortLevel;
  final String? notes;
  final WorkoutPrivacy? privacy;

  double get distanceKm => distanceMeters / 1000.0;
}
