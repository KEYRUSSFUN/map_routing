import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:map_routing/features/map/presentation/map_ui_styles.dart';

/// Маркер текущего местоположения: оранжевый круг, белая обводка, луч направления.
abstract final class MapLocationMarkerIcon {
  static const int _size = 160;
  static const _orange = MapUiColors.routeOrange;

  /// Масштаб на карте MapKit для PNG [_size]×[_size].
  static const mapScale = 1.1;

  static Future<Uint8List> toPngBytes() async {
    final image = await _render();
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static Future<ui.Image> _render() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = _size.toDouble();
    final center = Offset(size / 2, size / 2);
    const radius = 18.0;
    const ring = 4.0;

    _drawDirectionBeam(canvas, center, radius);

    canvas.drawCircle(
      center.translate(0, 1.5),
      radius + ring,
      Paint()..color = const Color(0x30000000),
    );

    canvas.drawCircle(
      center,
      radius + ring,
      Paint()..color = Colors.white,
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = _orange,
    );

    final picture = recorder.endRecording();
    return picture.toImage(_size, _size);
  }

  static void _drawDirectionBeam(Canvas canvas, Offset center, double radius) {
    final apex = Offset(center.dx, center.dy - radius - 52);
    final left = Offset(center.dx - 34, center.dy - radius + 2);
    final right = Offset(center.dx + 34, center.dy - radius + 2);

    final beam = Path()
      ..moveTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(apex.dx, apex.dy)
      ..close();

    canvas.drawPath(
      beam,
      Paint()..color = _orange.withValues(alpha: 0.20),
    );

    final innerBeam = Path()
      ..moveTo(center.dx - 18, center.dy - radius + 2)
      ..lineTo(center.dx + 18, center.dy - radius + 2)
      ..lineTo(center.dx, center.dy - radius - 38)
      ..close();

    canvas.drawPath(
      innerBeam,
      Paint()..color = _orange.withValues(alpha: 0.42),
    );

    final coreBeam = Path()
      ..moveTo(center.dx - 8, center.dy - radius + 1)
      ..lineTo(center.dx + 8, center.dy - radius + 1)
      ..lineTo(center.dx, center.dy - radius - 24)
      ..close();

    canvas.drawPath(
      coreBeam,
      Paint()..color = _orange.withValues(alpha: 0.58),
    );
  }
}
