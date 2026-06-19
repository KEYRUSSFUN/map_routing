import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:map_routing/data/models/track_point.dart';
import 'package:map_routing/features/profile/presentation/profile_ui.dart';

/// Лёгкое превью маршрута без MapKit (безопасно в списках карточек).
class RoutePolylinePreview extends StatelessWidget {
  const RoutePolylinePreview({
    super.key,
    required this.points,
    this.height = 88,
    this.borderRadius = 12,
  });

  final List<TrackPoint> points;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
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

    final shadowPaint = Paint()
      ..color = ProfileColors.primaryGreen.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, shadowPaint);

    final linePaint = Paint()
      ..color = ProfileColors.primaryGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    final start = project(points.first);
    final end = project(points.last);
    _drawDot(canvas, start, ProfileColors.primaryGreen);
    _drawDot(canvas, end, ProfileColors.orange);
  }

  void _drawDot(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(
      center,
      4.5,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      center,
      3.5,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RoutePreviewPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
