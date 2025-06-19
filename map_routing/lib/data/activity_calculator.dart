import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';

class ActivityCalculator {
  final double weightKg;

  ActivityCalculator({required this.weightKg});

  int estimateStepsByDistance(double distanceMeters) {
    const double averageStepLengthMeters = 0.75;
    return (distanceMeters / averageStepLengthMeters).round();
  }

  // Расчёт калорий при ходьбе
  double calculateWalkingCalories({
    required double distanceMeters,
    double met = 3.8,
    double averageSpeedKmH = 5.0,
  }) {
    final distanceKm = distanceMeters / 1000.0;
    final durationHours = distanceKm / averageSpeedKmH;
    return met * weightKg * durationHours;
  }

  // Расчёт калорий при беге
  double calculateRunningCalories({
    required double distanceMeters,
    double met = 9.0,
    double averageSpeedKmH = 8.0,
  }) {
    final distanceKm = distanceMeters / 1000.0;
    final durationHours = distanceKm / averageSpeedKmH;
    return met * weightKg * durationHours;
  }
}
