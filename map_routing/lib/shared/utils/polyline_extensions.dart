import 'package:flutter/material.dart';
import 'package:map_routing/features/map/presentation/map_ui_styles.dart';
import 'package:yandex_maps_mapkit/mapkit.dart';

extension StyleMainRoute on PolylineMapObject {
  void applyMainRouteStyle() {
    this
      ..zIndex = 10.0
      ..setStrokeColor(Colors.white)
      ..strokeWidth = 5.0
      ..outlineColor = MapUiColors.primaryGreen
      ..outlineWidth = 2.0;
  }
}

extension StyleAlternativeRoute on PolylineMapObject {
  void applyAlternativeRouteStyle() {
    this
      ..zIndex = 5.0
      ..setStrokeColor(Colors.white.withValues(alpha: 0.85))
      ..strokeWidth = 4.0
      ..outlineColor = MapUiColors.primaryGreen.withValues(alpha: 0.45)
      ..outlineWidth = 1.5;
  }
}

extension StyleTrackedWorkoutPath on PolylineMapObject {
  void applyTrackedWorkoutPathStyle() {
    this
      ..zIndex = 15.0
      ..setStrokeColor(MapUiColors.primaryGreen)
      ..strokeWidth = 4.0
      ..outlineColor = Colors.white
      ..outlineWidth = 1.5;
  }
}
