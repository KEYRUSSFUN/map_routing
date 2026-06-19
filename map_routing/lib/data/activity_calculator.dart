import 'package:map_routing/data/models/workout_activity_type.dart';

class ActivityCalculator {
  ActivityCalculator({
    required this.weightKg,
    this.heightCm,
    this.age,
  });

  final double weightKg;
  final double? heightCm;
  final int? age;

  /// Длина шага по росту (Antonetti / Winfield), иначе среднее 0.75 м.
  double get stepLengthMeters {
    if (heightCm != null && heightCm! > 0) {
      return (heightCm! * 0.415) / 100;
    }
    return 0.75;
  }

  int estimateStepsByDistance(double distanceMeters) {
    if (distanceMeters <= 0) return 0;
    return (distanceMeters / stepLengthMeters).round();
  }

  /// MET × вес (кг) × время (ч) — основная формула расхода энергии.
  double calculateCalories({
    required WorkoutActivityType activityType,
    Duration? duration,
    double distanceMeters = 0,
    double? avgSpeedKmh,
  }) {
    final safeWeight = weightKg > 0 ? weightKg : 70;

    if (duration != null && duration.inSeconds > 0) {
      return activityType.met * safeWeight * (duration.inSeconds / 3600);
    }

    if (distanceMeters <= 0) return 0;

    final speed = (avgSpeedKmh != null && avgSpeedKmh > 0)
        ? avgSpeedKmh
        : _defaultSpeedKmh(activityType);
    final durationHours = (distanceMeters / 1000) / speed;
    return activityType.met * safeWeight * durationHours;
  }

  double calculateWalkingCalories({
    required double distanceMeters,
    double met = 3.8,
    double averageSpeedKmH = 5.0,
  }) {
    return calculateCalories(
      activityType: WorkoutActivityType.walk,
      distanceMeters: distanceMeters,
      avgSpeedKmh: averageSpeedKmH,
    );
  }

  double calculateRunningCalories({
    required double distanceMeters,
    double met = 9.0,
    double averageSpeedKmH = 8.0,
  }) {
    return calculateCalories(
      activityType: WorkoutActivityType.run,
      distanceMeters: distanceMeters,
      avgSpeedKmh: averageSpeedKmH,
    );
  }

  int? estimateAverageHeartRate({
    required double distanceMeters,
    Duration? duration,
    WorkoutActivityType? activityType,
    double? avgSpeedKmh,
    int? effortLevel,
  }) {
    if (duration == null || duration.inSeconds <= 0 || distanceMeters <= 0) {
      return null;
    }

    final userAge = age ?? 30;
    const restingHr = 62;
    final maxHr = (220 - userAge).clamp(150, 200);
    final speedKmh = avgSpeedKmh ??
        (distanceMeters / 1000) / (duration.inSeconds / 3600);
    final intensity = _workoutIntensity(
      activityType ?? WorkoutActivityType.run,
      speedKmh,
      effortLevel ?? 3,
    );

    return (restingHr + intensity * (maxHr - restingHr))
        .round()
        .clamp(restingHr + 12, maxHr - 5);
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

  double _workoutIntensity(
    WorkoutActivityType activityType,
    double speedKmh,
    int effortLevel,
  ) {
    final referenceSpeed = switch (activityType) {
      WorkoutActivityType.walk => 5.0,
      WorkoutActivityType.run => 9.0,
      WorkoutActivityType.bike => 18.0,
      WorkoutActivityType.hike => 4.5,
      WorkoutActivityType.trail => 8.0,
      WorkoutActivityType.roller => 12.0,
      WorkoutActivityType.ski => 10.0,
      WorkoutActivityType.swim => 3.0,
    };

    final speedFactor = (speedKmh / referenceSpeed).clamp(0.55, 1.45);
    final effortFactor = 0.55 + (effortLevel.clamp(1, 5) - 1) * 0.1;
    return (speedFactor * 0.52 * effortFactor).clamp(0.38, 0.9);
  }
}
