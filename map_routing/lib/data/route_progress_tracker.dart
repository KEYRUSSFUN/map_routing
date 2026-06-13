import 'package:geolocator/geolocator.dart';
import 'package:yandex_maps_mapkit/mapkit.dart';

class RouteProgressSnapshot {
  const RouteProgressSnapshot({
    required this.totalMeters,
    required this.completedMeters,
    required this.remainingMeters,
    required this.progress,
    required this.isOffRoute,
    required this.offRouteDistanceM,
  });

  final double totalMeters;
  final double completedMeters;
  final double remainingMeters;
  final double progress;
  final bool isOffRoute;
  final double offRouteDistanceM;
}

class RouteProgressTracker {
  RouteProgressTracker(List<Point> routePoints) : pathPoints = _densify(routePoints) {
    _cumulativeMeters = _buildCumulative(pathPoints);
    totalMeters = _cumulativeMeters.isEmpty ? 0 : _cumulativeMeters.last;
  }

  final List<Point> pathPoints;
  late final double totalMeters;
  late final List<double> _cumulativeMeters;

  double _completedMeters = 0;
  bool _isOffRoute = false;
  double _offRouteDistanceM = 0;

  RouteProgressSnapshot update(
    double latitude,
    double longitude, {
    double offRouteThresholdM = 35,
  }) {
    if (pathPoints.length < 2 || totalMeters <= 0) {
      return RouteProgressSnapshot(
        totalMeters: totalMeters,
        completedMeters: _completedMeters,
        remainingMeters: totalMeters,
        progress: 0,
        isOffRoute: false,
        offRouteDistanceM: 0,
      );
    }

    var nearestDistanceM = double.infinity;
    var projectedMeters = _completedMeters;

    for (var i = 0; i < pathPoints.length - 1; i++) {
      final start = pathPoints[i];
      final end = pathPoints[i + 1];
      final projection = _projectOnSegment(latitude, longitude, start, end);
      final distanceToPath = Geolocator.distanceBetween(
        latitude,
        longitude,
        projection.latitude,
        projection.longitude,
      );

      if (distanceToPath < nearestDistanceM) {
        nearestDistanceM = distanceToPath;
        final segmentLength = Geolocator.distanceBetween(
          start.latitude,
          start.longitude,
          end.latitude,
          end.longitude,
        );
        projectedMeters =
            _cumulativeMeters[i] + segmentLength * projection.t;
      }
    }

    _isOffRoute = nearestDistanceM > offRouteThresholdM;
    _offRouteDistanceM = nearestDistanceM;

    if (projectedMeters > _completedMeters - 10) {
      _completedMeters = projectedMeters.clamp(0, totalMeters);
    }

    final remaining = (totalMeters - _completedMeters).clamp(0, totalMeters);

    return RouteProgressSnapshot(
      totalMeters: totalMeters,
      completedMeters: _completedMeters,
      remainingMeters: remaining,
      progress: totalMeters > 0 ? (_completedMeters / totalMeters).clamp(0, 1) : 0,
      isOffRoute: _isOffRoute,
      offRouteDistanceM: _offRouteDistanceM,
    );
  }

  static List<Point> _densify(List<Point> points, {double stepMeters = 10}) {
    if (points.length < 2) return List<Point>.from(points);

    final result = <Point>[points.first];
    for (var i = 0; i < points.length - 1; i++) {
      final start = points[i];
      final end = points[i + 1];
      final segmentLength = Geolocator.distanceBetween(
        start.latitude,
        start.longitude,
        end.latitude,
        end.longitude,
      );

      if (segmentLength <= stepMeters) {
        result.add(end);
        continue;
      }

      final steps = (segmentLength / stepMeters).floor();
      for (var step = 1; step <= steps; step++) {
        final t = step / (steps + 1);
        result.add(
          Point(
            latitude: start.latitude + (end.latitude - start.latitude) * t,
            longitude: start.longitude + (end.longitude - start.longitude) * t,
          ),
        );
      }
      result.add(end);
    }

    return result;
  }

  static List<double> _buildCumulative(List<Point> points) {
    if (points.isEmpty) return const [0];
    final cumulative = <double>[0];
    for (var i = 1; i < points.length; i++) {
      cumulative.add(
        cumulative.last +
            Geolocator.distanceBetween(
              points[i - 1].latitude,
              points[i - 1].longitude,
              points[i].latitude,
              points[i].longitude,
            ),
      );
    }
    return cumulative;
  }

  static ({double latitude, double longitude, double t}) _projectOnSegment(
    double latitude,
    double longitude,
    Point start,
    Point end,
  ) {
    final dx = end.longitude - start.longitude;
    final dy = end.latitude - start.latitude;
    final lengthSquared = dx * dx + dy * dy;

    if (lengthSquared == 0) {
      return (latitude: start.latitude, longitude: start.longitude, t: 0);
    }

    final t = ((longitude - start.longitude) * dx +
            (latitude - start.latitude) * dy) /
        lengthSquared;

    final clamped = t.clamp(0.0, 1.0);
    return (
      latitude: start.latitude + dy * clamped,
      longitude: start.longitude + dx * clamped,
      t: clamped,
    );
  }
}
