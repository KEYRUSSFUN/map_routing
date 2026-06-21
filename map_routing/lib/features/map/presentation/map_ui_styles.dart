import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/data/models/workout_activity_type.dart';

abstract final class MapUiColors {
  static const primaryGreen = Color(0xFF00E676);
  static const routeOrange = Color(0xFFFF9800);
  static const title = Color(0xFF030303);
  static const body = Color(0xFF757575);
  static const cardBg = Color(0xFFF5F5F5);
  static const glassDark = Color(0xCC1A1A1A);
  static const statusMoving = Color(0xFF00E676);
  static const statusPaused = Color(0xFFFF9800);
  static const statusStationary = Color(0xFF78909C);
  static const stopRed = Color(0xFFE53935);
}

TextStyle mapMetricValueStyle({double size = 28}) => GoogleFonts.lexendDeca(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: MapUiColors.title,
      height: 1.1,
    );

TextStyle mapMetricLabelStyle({Color? color}) => GoogleFonts.lexendDeca(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      color: color ?? MapUiColors.body,
    );

TextStyle mapChipLabelStyle({bool selected = false}) => GoogleFonts.lexendDeca(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: selected ? MapUiColors.title : MapUiColors.title,
    );

String formatWorkoutDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String formatSpeedKmh(double speedMs) {
  final kmh = speedMs * 3.6;
  return kmh.toStringAsFixed(2);
}

String formatDistanceKm(double meters) => (meters / 1000).toStringAsFixed(2);

String formatElevation(double meters) => '${meters.round()}m';

String formatCalories(double cal) => cal.round().toString();

String defaultWorkoutTitle(WorkoutActivityType type, DateTime time) {
  final hour = time.hour;
  String period;
  if (hour >= 5 && hour < 12) {
    period = 'Утренняя';
  } else if (hour >= 12 && hour < 17) {
    period = 'Дневная';
  } else if (hour >= 17 && hour < 22) {
    period = 'Вечерняя';
  } else {
    period = 'Ночная';
  }
  return '$period ${type.labelRu.toLowerCase()}';
}
