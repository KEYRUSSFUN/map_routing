import 'package:map_routing/data/models/workout_activity_type.dart';
import 'package:yandex_maps_mapkit/mapkit.dart' hide Map;

class PlannedWorkout {
  PlannedWorkout({
    required this.id,
    required this.title,
    required this.scheduledAt,
    required this.activityType,
    required this.startPoint,
    required this.endPoint,
    this.startLabel = '',
    this.endLabel = '',
    this.routePoints = const [],
    this.distanceMeters = 0,
    this.estimatedDurationSeconds = 0,
    this.estimatedCalories = 0,
    required this.notificationId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String title;
  final DateTime scheduledAt;
  final WorkoutActivityType activityType;
  final Point startPoint;
  final Point endPoint;
  final String startLabel;
  final String endLabel;
  final List<Point> routePoints;
  final double distanceMeters;
  final int estimatedDurationSeconds;
  final int estimatedCalories;
  final int notificationId;
  final DateTime createdAt;

  bool get isDue => !scheduledAt.isAfter(DateTime.now());

  Duration get timeUntil {
    final diff = scheduledAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  List<Point> get displayRoutePoints {
    if (routePoints.length >= 2) return routePoints;
    return [startPoint, endPoint];
  }

  PlannedWorkout copyWith({
    String? title,
    DateTime? scheduledAt,
    WorkoutActivityType? activityType,
    Point? startPoint,
    Point? endPoint,
    String? startLabel,
    String? endLabel,
    List<Point>? routePoints,
    double? distanceMeters,
    int? estimatedDurationSeconds,
    int? estimatedCalories,
  }) {
    return PlannedWorkout(
      id: id,
      title: title ?? this.title,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      activityType: activityType ?? this.activityType,
      startPoint: startPoint ?? this.startPoint,
      endPoint: endPoint ?? this.endPoint,
      startLabel: startLabel ?? this.startLabel,
      endLabel: endLabel ?? this.endLabel,
      routePoints: routePoints ?? this.routePoints,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      estimatedDurationSeconds:
          estimatedDurationSeconds ?? this.estimatedDurationSeconds,
      estimatedCalories: estimatedCalories ?? this.estimatedCalories,
      notificationId: notificationId,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'scheduledAt': scheduledAt.toIso8601String(),
        'activityTypeId': activityType.id,
        'startLat': startPoint.latitude,
        'startLon': startPoint.longitude,
        'endLat': endPoint.latitude,
        'endLon': endPoint.longitude,
        'startLabel': startLabel,
        'endLabel': endLabel,
        'routePoints': routePoints
            .map((p) => {'lat': p.latitude, 'lon': p.longitude})
            .toList(),
        'distanceMeters': distanceMeters,
        'estimatedDurationSeconds': estimatedDurationSeconds,
        'estimatedCalories': estimatedCalories,
        'notificationId': notificationId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PlannedWorkout.fromJson(Map<String, dynamic> json) {
    final routeRaw = json['routePoints'];
    final routePoints = <Point>[];
    if (routeRaw is List) {
      for (final item in routeRaw) {
        if (item is Map<String, dynamic>) {
          final lat = (item['lat'] as num?)?.toDouble();
          final lon = (item['lon'] as num?)?.toDouble();
          if (lat != null && lon != null) {
            routePoints.add(Point(latitude: lat, longitude: lon));
          }
        }
      }
    }

    return PlannedWorkout(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Тренировка',
      scheduledAt: DateTime.tryParse(json['scheduledAt']?.toString() ?? '') ??
          DateTime.now(),
      activityType: WorkoutActivityType.fromId(json['activityTypeId']?.toString()),
      startPoint: Point(
        latitude: (json['startLat'] as num?)?.toDouble() ?? 0,
        longitude: (json['startLon'] as num?)?.toDouble() ?? 0,
      ),
      endPoint: Point(
        latitude: (json['endLat'] as num?)?.toDouble() ?? 0,
        longitude: (json['endLon'] as num?)?.toDouble() ?? 0,
      ),
      startLabel: json['startLabel']?.toString() ?? '',
      endLabel: json['endLabel']?.toString() ?? '',
      routePoints: routePoints,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
      estimatedDurationSeconds:
          (json['estimatedDurationSeconds'] as num?)?.toInt() ?? 0,
      estimatedCalories: (json['estimatedCalories'] as num?)?.toInt() ?? 0,
      notificationId: (json['notificationId'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}
