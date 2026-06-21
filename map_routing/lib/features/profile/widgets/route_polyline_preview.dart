import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:map_routing/data/models/track_point.dart';
import 'package:map_routing/features/profile/presentation/profile_ui.dart';

List<TrackPoint> parseGeoJsonTrackPoints(Map<String, dynamic>? geoJson) {
  final coords = geoJson?['coordinates'];
  if (coords is! List || coords.isEmpty) return [];

  final points = <TrackPoint>[];
  for (final item in coords) {
    if (item is! List || item.length < 2) continue;
    final lon = (item[0] as num).toDouble();
    final lat = (item[1] as num).toDouble();
    points.add(TrackPoint(latitude: lat, longitude: lon));
  }
  return points;
}

/// Лёгкое превью маршрута без MapKit (безопасно в списках карточек).
class RoutePolylinePreview extends StatelessWidget {
  const RoutePolylinePreview({
    super.key,
    required this.points,
    this.height = 88,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  final List<TrackPoint> points;
  final double height;
  final BorderRadiusGeometry borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _RoutePreviewPainter(points: points),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _RoutePreviewPainter extends CustomPainter {
  _RoutePreviewPainter({required this.points});

  final List<TrackPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFFEEF4F0);
    canvas.drawRect(Offset.zero & size, background);

    if (points.length < 2) {
      final iconPaint = Paint()..color = ProfileColors.primaryGreen.withValues(alpha: 0.35);
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), 14, iconPaint);
      return;
    }

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLon = points.first.longitude;
    var maxLon = points.first.longitude;

    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLon = math.min(minLon, point.longitude);
      maxLon = math.max(maxLon, point.longitude);
    }

    const padding = 12.0;
    final latSpan = math.max(maxLat - minLat, 1e-6);
    final lonSpan = math.max(maxLon - minLon, 1e-6);
    final drawableW = size.width - padding * 2;
    final drawableH = size.height - padding * 2;
    final scale = math.min(drawableW / lonSpan, drawableH / latSpan);

    Offset project(TrackPoint point) {
      final x = padding + (point.longitude - minLon) * scale;
      final y = padding + (maxLat - point.latitude) * scale;
      return Offset(x, y);
    }

    final path = Path();
    final first = project(points.first);
    path.moveTo(first.dx, first.dy);
    for (var i = 1; i < points.length; i++) {
      final p = project(points[i]);
      path.lineTo(p.dx, p.dy);
    }

    final linePaint = Paint()
      ..color = ProfileColors.primaryGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final outlinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, outlinePaint);
    canvas.drawPath(path, linePaint);

    final start = project(points.first);
    final end = project(points.last);
    _drawStartMarker(canvas, start);
    _drawFinishMarker(canvas, end);
  }

  void _drawStartMarker(Canvas canvas, Offset center) {
    canvas.drawCircle(center, 6.5, Paint()..color = Colors.white);
    canvas.drawCircle(center, 5.0, Paint()..color = const Color(0xFFFF9800));
  }

  void _drawFinishMarker(Canvas canvas, Offset center) {
    canvas.drawCircle(center, 7.0, Paint()..color = const Color(0xFF212121));
    canvas.drawCircle(center, 5.8, Paint()..color = Colors.white);

    const cell = 2.4;
    final origin = Offset(center.dx - cell, center.dy - cell * 0.75);
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 2; col++) {
        final isDark = (row + col).isOdd;
        canvas.drawRect(
          Rect.fromLTWH(
            origin.dx + col * cell,
            origin.dy + row * cell,
            cell,
            cell,
          ),
          Paint()..color = isDark ? const Color(0xFF212121) : Colors.white,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePreviewPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
