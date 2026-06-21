import 'package:map_routing/data/models/track_point.dart';
import 'package:map_routing/data/models/workout_activity_type.dart';

enum WorkoutSource {
  tracked,
  saved,
  imported,
  synced;

  String get labelRu {
    switch (this) {
      case WorkoutSource.tracked:
        return 'Тренировка';
      case WorkoutSource.saved:
        return 'Сохранённый маршрут';
      case WorkoutSource.imported:
        return 'Из чата';
      case WorkoutSource.synced:
        return 'С сервера';
    }
  }

  static WorkoutSource fromPath(String filePath) {
    if (filePath.isEmpty) return WorkoutSource.tracked;
    final base = filePath.replaceAll(r'\', '/').split('/').last;
    if (base.startsWith('shared_')) return WorkoutSource.imported;
    if (base.startsWith('saved_route_')) return WorkoutSource.saved;
    return WorkoutSource.tracked;
  }
}

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
    this.photoUrl,
    this.effortLevel,
    this.notes,
    this.privacy,
    this.source = WorkoutSource.tracked,
    this.backendRouteId,
    this.sharedByUserId,
    this.sharedByUserName,
    this.sharedByAvatarUrl,
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
  final String? photoUrl;
  final int? effortLevel;
  final String? notes;
  final WorkoutPrivacy? privacy;
  final WorkoutSource source;
  final int? backendRouteId;
  final String? sharedByUserId;
  final String? sharedByUserName;
  final String? sharedByAvatarUrl;

  bool get isImported => source == WorkoutSource.imported;

  double get distanceKm => distanceMeters / 1000.0;

  WorkoutSummary copyWith({
    String? id,
    String? title,
    String? filePath,
    DateTime? startedAt,
    double? distanceMeters,
    Duration? duration,
    double? avgSpeedKmh,
    double? elevationGainM,
    int? calories,
    int? avgHeartRate,
    int? cadenceSpm,
    List<TrackPoint>? points,
    List<WorkoutChartPoint>? chartPoints,
    WorkoutActivityType? activityType,
    String? description,
    List<String>? tags,
    String? photoPath,
    String? photoUrl,
    int? effortLevel,
    String? notes,
    WorkoutPrivacy? privacy,
    WorkoutSource? source,
    int? backendRouteId,
    String? sharedByUserId,
    String? sharedByUserName,
    String? sharedByAvatarUrl,
  }) {
    return WorkoutSummary(
      id: id ?? this.id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      startedAt: startedAt ?? this.startedAt,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      duration: duration ?? this.duration,
      avgSpeedKmh: avgSpeedKmh ?? this.avgSpeedKmh,
      elevationGainM: elevationGainM ?? this.elevationGainM,
      calories: calories ?? this.calories,
      avgHeartRate: avgHeartRate ?? this.avgHeartRate,
      cadenceSpm: cadenceSpm ?? this.cadenceSpm,
      points: points ?? this.points,
      chartPoints: chartPoints ?? this.chartPoints,
      activityType: activityType ?? this.activityType,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      photoPath: photoPath ?? this.photoPath,
      photoUrl: photoUrl ?? this.photoUrl,
      effortLevel: effortLevel ?? this.effortLevel,
      notes: notes ?? this.notes,
      privacy: privacy ?? this.privacy,
      source: source ?? this.source,
      backendRouteId: backendRouteId ?? this.backendRouteId,
      sharedByUserId: sharedByUserId ?? this.sharedByUserId,
      sharedByUserName: sharedByUserName ?? this.sharedByUserName,
      sharedByAvatarUrl: sharedByAvatarUrl ?? this.sharedByAvatarUrl,
    );
  }
}
