import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:map_routing/features/map/presentation/map_ui_styles.dart';

abstract final class MapRouteMarkerIcons {
  static const int _size = 96;
  static const _orange = MapUiColors.routeOrange;

  static const double startIconScale = 1.0;
  static const double finishIconScale = 1.15;

  static Future<Uint8List> startPointPng() async {
    final image = await _renderStart();
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static Future<Uint8List> finishPointPng() async {
    final image = await _renderFinish();
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static Future<ui.Image> _renderStart() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = _size.toDouble();
    final center = Offset(size / 2, size / 2);
    const radius = 16.0;
    const ring = 3.5;

    canvas.drawCircle(
      center.translate(0, 1.2),
      radius + ring,
      Paint()..color = const Color(0x33000000),
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

  static Future<ui.Image> _renderFinish() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = _size.toDouble();
    final center = Offset(size / 2, size / 2);
    const outerRadius = 20.0;
    const ring = 2.5;

    canvas.drawCircle(
      center.translate(0, 1.2),
      outerRadius + ring,
      Paint()..color = const Color(0x33000000),
    );

    canvas.drawCircle(
      center,
      outerRadius + ring,
      Paint()
        ..color = const Color(0xFF212121)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring,
    );

    canvas.drawCircle(
      center,
      outerRadius,
      Paint()..color = Colors.white,
    );

    _drawCheckeredFlag(canvas, center);

    final picture = recorder.endRecording();
    return picture.toImage(_size, _size);
  }

  static void _drawCheckeredFlag(Canvas canvas, Offset center) {
    const cols = 4;
    const rows = 3;
    const cell = 5.0;
    const flagWidth = cols * cell;
    const flagHeight = rows * cell;
    final left = center.dx - flagWidth / 2;
    final top = center.dy - flagHeight / 2;

    final flagRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, flagWidth, flagHeight),
      const Radius.circular(1),
    );
    canvas.drawRRect(flagRect, Paint()..color = Colors.white);

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final isDark = (row + col).isEven;
        canvas.drawRect(
          Rect.fromLTWH(left + col * cell, top + row * cell, cell, cell),
          Paint()..color = isDark ? const Color(0xFF212121) : Colors.white,
        );
      }
    }

    canvas.drawRRect(
      flagRect,
      Paint()
        ..color = const Color(0xFF212121)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }
}
