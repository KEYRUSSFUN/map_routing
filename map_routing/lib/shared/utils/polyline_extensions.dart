import 'package:flutter/material.dart';
import 'package:yandex_maps_mapkit/mapkit.dart';

extension StyleMainRoute on PolylineMapObject {
  void applyMainRouteStyle() {
    this
      ..zIndex = 10.0
      ..setStrokeColor(const Color.fromARGB(255, 54, 184, 244))
      ..strokeWidth = 3.0
      ..outlineColor = const Color.fromARGB(255, 223, 222, 222)
      ..outlineWidth = 0.3;
  }
}

extension StyleAlternativeRoute on PolylineMapObject {
  void applyAlternativeRouteStyle() {
    this
      ..zIndex = 5.0
      ..setStrokeColor(const Color.fromARGB(255, 211, 211, 211))
      ..strokeWidth = 4.0
      ..outlineColor = const Color.fromARGB(255, 112, 112, 112)
      ..outlineWidth = 2.0;
  }
}
