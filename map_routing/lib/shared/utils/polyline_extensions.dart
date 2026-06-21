import 'package:flutter/material.dart';
import 'package:map_routing/features/map/presentation/map_ui_styles.dart';
import 'package:yandex_maps_mapkit/mapkit.dart';

extension StyleMainRoute on PolylineMapObject {
  void applyMainRouteStyle() {
    zIndex = 10.0;
    setStrokeColor(MapUiColors.primaryGreen);
    style = const LineStyle(
      strokeWidth: 6.0,
      outlineColor: Colors.white,
      outlineWidth: 2.5,
    );
  }
}

extension StyleAlternativeRoute on PolylineMapObject {
  void applyAlternativeRouteStyle() {
    zIndex = 5.0;
    setStrokeColor(MapUiColors.primaryGreen.withValues(alpha: 0.55));
    style = LineStyle(
      strokeWidth: 5.0,
      outlineColor: Colors.white.withValues(alpha: 0.9),
      outlineWidth: 2.0,
    );
  }
}

/// Линия, которую пользователь рисует во время активной тренировки.
extension StyleTrackedWorkoutPath on PolylineMapObject {
  void applyTrackedWorkoutPathStyle() {
    zIndex = 15.0;
    setStrokeColor(MapUiColors.routeOrange);
    style = const LineStyle(
      strokeWidth: 6.0,
      outlineColor: Colors.white,
      outlineWidth: 2.5,
    );
  }
}
