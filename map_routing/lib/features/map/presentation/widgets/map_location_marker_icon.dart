import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:map_routing/features/map/presentation/map_ui_styles.dart';

/// Генерирует PNG-иконку маркера текущего местоположения в фирменных цветах.
abstract final class MapLocationMarkerIcon {
  static const int _size = 128 * 3;

  static Future<Uint8List> toPngBytes() async {
    final image = await _render();
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static Future<ui.Image> _render() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = _size.toDouble();
    const green = MapUiColors.primaryGreen;

    final arrow = _arrowPath(size);

    canvas.drawPath(
      arrow.shift(const Offset(0, 3)),
      Paint()..color = const Color(0x40000000),
    );

    canvas.drawPath(
      arrow,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.09
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawPath(arrow, Paint()..color = green);

    final picture = recorder.endRecording();
    return picture.toImage(_size, _size);
  }

  static Path _arrowPath(double size) {
    final stemHalf = size * 0.11;
    final centerX = size * 0.5;

    return Path()
      ..moveTo(centerX, size * 0.06)
      ..lineTo(size * 0.8, size * 0.54)
      ..lineTo(centerX + stemHalf, size * 0.54)
      ..lineTo(centerX + stemHalf, size * 0.9)
      ..arcToPoint(
        Offset(centerX - stemHalf, size * 0.9),
        radius: Radius.circular(stemHalf),
      )
      ..lineTo(centerX - stemHalf, size * 0.54)
      ..lineTo(size * 0.2, size * 0.54)
      ..close();
  }
}
