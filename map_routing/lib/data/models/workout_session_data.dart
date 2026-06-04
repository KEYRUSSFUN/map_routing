import 'package:map_routing/data/models/track_point.dart';
import 'package:map_routing/data/models/workout_activity_type.dart';

enum WorkoutMotionStatus { moving, paused, stationary }

class WorkoutSessionData {
  const WorkoutSessionData({
    required this.points,
    required this.distanceMeters,
    required this.duration,
    required this.elevationGainM,
    required this.calories,
    required this.activityType,
    required this.startedAt,
    required this.avgSpeedKmh,
    required this.currentSpeedKmh,
  });

  final List<TrackPoint> points;
  final double distanceMeters;
  final Duration duration;
  final double elevationGainM;
  final double calories;
  final WorkoutActivityType activityType;
  final DateTime startedAt;
  final double avgSpeedKmh;
  final double currentSpeedKmh;
}
