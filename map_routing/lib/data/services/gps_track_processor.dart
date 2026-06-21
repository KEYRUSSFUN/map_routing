import 'package:geolocator/geolocator.dart';
import 'package:map_routing/data/gps_kalman_filter.dart';
import 'package:map_routing/data/models/track_point.dart';
import 'package:map_routing/data/route_progress_tracker.dart';
import 'package:yandex_maps_mapkit/mapkit.dart';

class GpsTrackAcceptResult {
  const GpsTrackAcceptResult({
    required this.trackPoint,
    required this.addedDistanceM,
  });

  final TrackPoint trackPoint;
  final double addedDistanceM;
}

/// Фильтрация GPS-трека: точность, выбросы скорости, Kalman и snap к маршруту.
class GpsTrackProcessor {
  GpsTrackProcessor({
    this.maxAccuracyM = 22,
    this.relaxedAccuracyM = 40,
    this.minDistanceM = 4,
    this.maxSpeedMs = 11,
    this.stationarySpeedMs = 0.45,
    this.minInterval = const Duration(milliseconds: 900),
    this.accuracyRelaxAfter = const Duration(seconds: 12),
    this.gapInterpolationStepM = 10,
    this.gapTimeThreshold = const Duration(seconds: 18),
    this.gapDistanceThresholdM = 30,
    this.maxGapInterpolationDuration = const Duration(minutes: 12),
    this.maxGapInterpolationDistanceM = 1200,
  });

  final double maxAccuracyM;
  final double relaxedAccuracyM;
  final double minDistanceM;
  final double maxSpeedMs;
  final double stationarySpeedMs;
  final Duration minInterval;
  final Duration accuracyRelaxAfter;
  final double gapInterpolationStepM;
  final Duration gapTimeThreshold;
  final double gapDistanceThresholdM;
  final Duration maxGapInterpolationDuration;
  final double maxGapInterpolationDistanceM;

  final GpsKalmanFilter _kalman = GpsKalmanFilter();
  TrackPoint? _lastAccepted;
  DateTime? _lastAccuracyRejectAt;

  void reset() {
    _kalman.reset();
    _lastAccepted = null;
    _lastAccuracyRejectAt = null;
  }

  GpsTrackAcceptResult? accept({
    required Position position,
    PathSnapResult? routeSnap,
    bool preferRouteSnap = true,
    List<Point>? routeGapPoints,
  }) {
    final results = acceptTrackPoints(
      position: position,
      routeSnap: routeSnap,
      preferRouteSnap: preferRouteSnap,
      routeGapPoints: routeGapPoints,
    );
    if (results.isEmpty) return null;
    return results.last;
  }

  List<GpsTrackAcceptResult> acceptTrackPoints({
    required Position position,
    PathSnapResult? routeSnap,
    bool preferRouteSnap = true,
    List<Point>? routeGapPoints,
  }) {
    final accuracy = position.accuracy;
    if (!accuracy.isFinite || accuracy <= 0) return const [];

    var allowedAccuracy = maxAccuracyM;
    if (_lastAccepted == null && _lastAccuracyRejectAt != null) {
      if (DateTime.now().difference(_lastAccuracyRejectAt!) >=
          accuracyRelaxAfter) {
        allowedAccuracy = relaxedAccuracyM;
      }
    }
    if (accuracy > allowedAccuracy) {
      _lastAccuracyRejectAt ??= DateTime.now();
      return const [];
    }
    _lastAccuracyRejectAt = null;

    final timestamp = position.timestamp;
    final dtSeconds = _lastAccepted?.time != null
        ? timestamp.difference(_lastAccepted!.time!).inMilliseconds / 1000
        : 1.0;

    final smoothed = _kalman.update(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyM: accuracy,
      dtSeconds: dtSeconds,
    );

    var latitude = smoothed.latitude;
    var longitude = smoothed.longitude;

    final onRoute = routeSnap != null && !routeSnap.isOffRoute;
    if (preferRouteSnap && onRoute) {
      latitude = routeSnap.point.latitude;
      longitude = routeSnap.point.longitude;
    }

    final target = TrackPoint(
      latitude: latitude,
      longitude: longitude,
      time: timestamp,
      elevation: position.altitude,
    );

    final reportedSpeed = position.speed >= 0 ? position.speed : 0.0;
    if (_lastAccepted == null) {
      _lastAccepted = target;
      return [
        GpsTrackAcceptResult(trackPoint: target, addedDistanceM: 0),
      ];
    }

    final elapsed = timestamp.difference(_lastAccepted!.time ?? timestamp);
    if (elapsed < minInterval) return const [];

    final distanceM = Geolocator.distanceBetween(
      _lastAccepted!.latitude,
      _lastAccepted!.longitude,
      latitude,
      longitude,
    );

    if (distanceM < minDistanceM) return const [];

    if (reportedSpeed < stationarySpeedMs && distanceM < 8) {
      return const [];
    }

    final elapsedSec = elapsed.inMilliseconds / 1000;
    if (elapsedSec > 0) {
      final impliedSpeed = distanceM / elapsedSec;
      final isGap = elapsed >= gapTimeThreshold ||
          distanceM >= gapDistanceThresholdM;
      if (impliedSpeed > maxSpeedMs && !isGap) return const [];

      if (isGap) {
        if (elapsed > maxGapInterpolationDuration ||
            distanceM > maxGapInterpolationDistanceM) {
          _kalman.reset();
          _lastAccepted = target;
          return [
            GpsTrackAcceptResult(trackPoint: target, addedDistanceM: 0),
          ];
        }

        if (routeGapPoints != null && routeGapPoints.length >= 2) {
          return _appendAlongRoute(
            routeGapPoints,
            target: target,
            timestamp: timestamp,
            elevation: position.altitude,
          );
        }

        return _appendLinear(
          target: target,
          timestamp: timestamp,
          elevation: position.altitude,
        );
      }
    }

    _lastAccepted = target;
    return [
      GpsTrackAcceptResult(trackPoint: target, addedDistanceM: distanceM),
    ];
  }

  List<GpsTrackAcceptResult> _appendLinear({
    required TrackPoint target,
    required DateTime timestamp,
    required double elevation,
  }) {
    final from = _lastAccepted!;
    final totalDistanceM = Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      target.latitude,
      target.longitude,
    );
    if (totalDistanceM < minDistanceM) return const [];

    final steps = (totalDistanceM / gapInterpolationStepM).ceil().clamp(1, 80);
    final results = <GpsTrackAcceptResult>[];
    TrackPoint previous = from;
    final startTime = from.time ?? timestamp;
    final totalMs = timestamp.difference(startTime).inMilliseconds;

    for (var step = 1; step <= steps; step++) {
      final t = step / steps;
      final point = TrackPoint(
        latitude: from.latitude + (target.latitude - from.latitude) * t,
        longitude: from.longitude + (target.longitude - from.longitude) * t,
        time: totalMs > 0
            ? startTime.add(Duration(milliseconds: (totalMs * t).round()))
            : timestamp,
        elevation: elevation,
      );
      final stepDistanceM = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        point.latitude,
        point.longitude,
      );
      if (stepDistanceM >= minDistanceM * 0.5) {
        results.add(
          GpsTrackAcceptResult(
            trackPoint: point,
            addedDistanceM: stepDistanceM,
          ),
        );
        previous = point;
        _lastAccepted = point;
      }
    }

    return results;
  }

  List<GpsTrackAcceptResult> _appendAlongRoute(
    List<Point> routePoints, {
    required TrackPoint target,
    required DateTime timestamp,
    required double elevation,
  }) {
    final results = <GpsTrackAcceptResult>[];
    TrackPoint previous = _lastAccepted!;
    final startTime = previous.time ?? timestamp;
    final totalMs = timestamp.difference(startTime).inMilliseconds;

    for (var i = 1; i < routePoints.length; i++) {
      final routePoint = routePoints[i];
      final point = TrackPoint(
        latitude: routePoint.latitude,
        longitude: routePoint.longitude,
        time: totalMs > 0
            ? startTime.add(
                Duration(
                  milliseconds:
                      (totalMs * (i / (routePoints.length - 1))).round(),
                ),
              )
            : timestamp,
        elevation: elevation,
      );
      final stepDistanceM = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        point.latitude,
        point.longitude,
      );
      if (stepDistanceM < minDistanceM * 0.5) continue;

      results.add(
        GpsTrackAcceptResult(
          trackPoint: point,
          addedDistanceM: stepDistanceM,
        ),
      );
      previous = point;
      _lastAccepted = point;
    }

    if (results.isEmpty) {
      _lastAccepted = target;
      return [
        GpsTrackAcceptResult(trackPoint: target, addedDistanceM: 0),
      ];
    }

    return results;
  }
}
