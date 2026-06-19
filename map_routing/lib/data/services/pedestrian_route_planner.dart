import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:map_routing/core/map/mapkit_bootstrap.dart';
import 'package:yandex_maps_mapkit/mapkit.dart';
import 'package:yandex_maps_mapkit/transport.dart';

class PedestrianRoutePlanner {
  PedestrianRoutePlanner._();

  static Future<List<Point>> planRoute({
    required Point start,
    required Point end,
  }) async {
    await MapkitBootstrap.ensureInitialized();
    final router = TransportFactory.instance.createPedestrianRouter();
    final completer = Completer<List<Point>>();

    final listener = RouteHandler(
      onMasstransitRoutes: (routes) {
        if (routes.isEmpty) {
          if (!completer.isCompleted) {
            completer.completeError(Exception('Маршрут не найден'));
          }
          return;
        }
        if (!completer.isCompleted) {
          completer.complete(routes.first.geometry.points);
        }
      },
      onMasstransitRoutesError: (_) {
        if (!completer.isCompleted) {
          completer.completeError(Exception('Ошибка построения маршрута'));
        }
      },
    );

    final session = router.requestRoutes(
      const TimeOptions(),
      const RouteOptions(FitnessOptions(avoidSteep: false)),
      listener,
      points: [
        RequestPoint(start, RequestPointType.Waypoint, null, null, null),
        RequestPoint(end, RequestPointType.Waypoint, null, null, null),
      ],
    );

    try {
      return await completer.future.timeout(const Duration(seconds: 20));
    } finally {
      session.cancel();
    }
  }
}

double routeDistanceMeters(List<Point> points) {
  if (points.length < 2) return 0;

  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += Geolocator.distanceBetween(
      points[i - 1].latitude,
      points[i - 1].longitude,
      points[i].latitude,
      points[i].longitude,
    );
  }
  return total;
}
