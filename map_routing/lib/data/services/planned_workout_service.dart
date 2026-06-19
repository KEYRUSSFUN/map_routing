import 'package:map_routing/data/activity_calculator.dart';
import 'package:map_routing/data/models/planned_workout.dart';
import 'package:map_routing/data/models/workout_activity_type.dart';
import 'package:map_routing/data/services/pedestrian_route_planner.dart';
import 'package:map_routing/data/services/planned_workout_storage.dart';
import 'package:map_routing/data/services/user_service.dart';
import 'package:map_routing/core/services/notification_service.dart';
import 'package:yandex_maps_mapkit/mapkit.dart';

class PlannedWorkoutService {
  PlannedWorkoutService._();

  static final PlannedWorkoutService instance = PlannedWorkoutService._();

  final _storage = PlannedWorkoutStorage.instance;

  Future<List<PlannedWorkout>> loadUpcoming(String userId) async {
    final all = await _storage.loadAll(userId);
    return all.where((w) => w.scheduledAt.isAfter(
          DateTime.now().subtract(const Duration(hours: 1)),
        )).toList();
  }

  Future<PlannedWorkout?> findById(String userId, String id) async {
    final all = await _storage.loadAll(userId);
    for (final workout in all) {
      if (workout.id == id) return workout;
    }
    return null;
  }

  Future<PlannedWorkoutEstimates> estimate({
    required WorkoutActivityType activityType,
    required List<Point> routePoints,
  }) async {
    final distanceMeters = routeDistanceMeters(routePoints);
    final info = await UserService().fetchUserInfo();
    final weight = (info?['weight'] as num?)?.toDouble() ?? 70;
    final height = (info?['height'] as num?)?.toDouble();
    final ageRaw = info?['age'] ?? info?['Age'];
    final age = ageRaw is int ? ageRaw : int.tryParse(ageRaw?.toString() ?? '');

    final calculator = ActivityCalculator(
      weightKg: weight,
      heightCm: height,
      age: age,
    );

    final avgSpeed = _defaultSpeedKmh(activityType);
    final durationSeconds = distanceMeters <= 0
        ? 0
        : ((distanceMeters / 1000) / avgSpeed * 3600).round();
    final duration = Duration(seconds: durationSeconds);
    final calories = calculator
        .calculateCalories(
          activityType: activityType,
          duration: duration,
          distanceMeters: distanceMeters,
          avgSpeedKmh: avgSpeed,
        )
        .round();

    return PlannedWorkoutEstimates(
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      calories: calories,
    );
  }

  Future<PlannedWorkout> save({
    required String userId,
    required String title,
    required DateTime scheduledAt,
    required WorkoutActivityType activityType,
    required Point startPoint,
    required Point endPoint,
    required String startLabel,
    required String endLabel,
    required List<Point> routePoints,
    required PlannedWorkoutEstimates estimates,
    String? existingId,
    int? existingNotificationId,
  }) async {
    final id = existingId ?? DateTime.now().millisecondsSinceEpoch.toString();
    final notificationId =
        existingNotificationId ?? id.hashCode.abs().clamp(1, 2147483646);

    final workout = PlannedWorkout(
      id: id,
      title: title,
      scheduledAt: scheduledAt,
      activityType: activityType,
      startPoint: startPoint,
      endPoint: endPoint,
      startLabel: startLabel,
      endLabel: endLabel,
      routePoints: routePoints,
      distanceMeters: estimates.distanceMeters,
      estimatedDurationSeconds: estimates.durationSeconds,
      estimatedCalories: estimates.calories,
      notificationId: notificationId,
    );

    await _storage.save(userId, workout);
    await NotificationService.instance.schedulePlannedWorkout(workout);
    return workout;
  }

  Future<void> delete(String userId, PlannedWorkout workout) async {
    await NotificationService.instance.cancelScheduled(workout.notificationId);
    await _storage.delete(userId, workout.id);
  }

  Future<void> rescheduleAllNotifications(String userId) async {
    final workouts = await _storage.loadAll(userId);
    for (final workout in workouts) {
      if (workout.scheduledAt.isAfter(DateTime.now())) {
        await NotificationService.instance.schedulePlannedWorkout(workout);
      } else {
        await NotificationService.instance.cancelScheduled(workout.notificationId);
      }
    }
  }

  double _defaultSpeedKmh(WorkoutActivityType activityType) {
    return switch (activityType) {
      WorkoutActivityType.walk => 5.0,
      WorkoutActivityType.run => 9.0,
      WorkoutActivityType.bike => 18.0,
      WorkoutActivityType.hike => 4.5,
      WorkoutActivityType.trail => 8.0,
      WorkoutActivityType.roller => 12.0,
      WorkoutActivityType.ski => 10.0,
      WorkoutActivityType.swim => 3.0,
    };
  }
}

class PlannedWorkoutEstimates {
  const PlannedWorkoutEstimates({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.calories,
  });

  final double distanceMeters;
  final int durationSeconds;
  final int calories;
}

String formatPlannedWorkoutCountdown(DateTime scheduledAt) {
  final diff = scheduledAt.difference(DateTime.now());
  if (diff.isNegative || diff.inSeconds <= 0) return 'Пора начать';
  if (diff.inDays >= 1) {
    return 'через ${diff.inDays} ${_ruDays(diff.inDays)}';
  }
  if (diff.inHours >= 1) {
    final minutes = diff.inMinutes % 60;
    return minutes > 0
        ? 'через ${diff.inHours} ч $minutes мин'
        : 'через ${diff.inHours} ${_ruHours(diff.inHours)}';
  }
  if (diff.inMinutes >= 1) {
    return 'через ${diff.inMinutes} ${_ruMinutes(diff.inMinutes)}';
  }
  return 'через ${diff.inSeconds} сек';
}

String formatPlannedWorkoutSchedule(DateTime scheduledAt) {
  final day = scheduledAt.day.toString().padLeft(2, '0');
  final month = scheduledAt.month.toString().padLeft(2, '0');
  final hour = scheduledAt.hour.toString().padLeft(2, '0');
  final minute = scheduledAt.minute.toString().padLeft(2, '0');
  return '$day.$month.${scheduledAt.year} · $hour:$minute';
}

String _ruMinutes(int value) {
  final mod10 = value % 10;
  final mod100 = value % 100;
  if (mod10 == 1 && mod100 != 11) return 'минуту';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'минуты';
  }
  return 'минут';
}

String _ruHours(int value) {
  final mod10 = value % 10;
  final mod100 = value % 100;
  if (mod10 == 1 && mod100 != 11) return 'час';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'часа';
  }
  return 'часов';
}

String _ruDays(int value) {
  final mod10 = value % 10;
  final mod100 = value % 100;
  if (mod10 == 1 && mod100 != 11) return 'день';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'дня';
  }
  return 'дней';
}
