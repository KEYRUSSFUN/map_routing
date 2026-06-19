import 'package:geolocator/geolocator.dart';
import 'package:map_routing/data/gps_kalman_filter.dart';
import 'package:map_routing/data/models/track_point.dart';
import 'package:map_routing/data/route_progress_tracker.dart';

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
  });

  final double maxAccuracyM;
  final double relaxedAccuracyM;
  final double minDistanceM;
  final double maxSpeedMs;
  final double stationarySpeedMs;
  final Duration minInterval;
  final Duration accuracyRelaxAfter;

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
  }) {
    final accuracy = position.accuracy;
    if (!accuracy.isFinite || accuracy <= 0) return null;

    var allowedAccuracy = maxAccuracyM;
    if (_lastAccepted == null && _lastAccuracyRejectAt != null) {
      if (DateTime.now().difference(_lastAccuracyRejectAt!) >=
          accuracyRelaxAfter) {
        allowedAccuracy = relaxedAccuracyM;
      }
    }
    if (accuracy > allowedAccuracy) {
      _lastAccuracyRejectAt ??= DateTime.now();
      return null;
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

    final reportedSpeed = position.speed >= 0 ? position.speed : 0.0;
    if (_lastAccepted != null) {
      final elapsed = timestamp.difference(_lastAccepted!.time ?? timestamp);
      if (elapsed < minInterval) return null;

      final distanceM = Geolocator.distanceBetween(
        _lastAccepted!.latitude,
        _lastAccepted!.longitude,
        latitude,
        longitude,
      );

      if (distanceM < minDistanceM) return null;

      if (reportedSpeed < stationarySpeedMs && distanceM < 8) {
        return null;
      }

      final elapsedSec = elapsed.inMilliseconds / 1000;
      if (elapsedSec > 0) {
        final impliedSpeed = distanceM / elapsedSec;
        if (impliedSpeed > maxSpeedMs) return null;
      }

      final point = TrackPoint(
        latitude: latitude,
        longitude: longitude,
        time: timestamp,
        elevation: position.altitude,
      );
      _lastAccepted = point;
      return GpsTrackAcceptResult(trackPoint: point, addedDistanceM: distanceM);
    }

    final first = TrackPoint(
      latitude: latitude,
      longitude: longitude,
      time: timestamp,
      elevation: position.altitude,
    );
    _lastAccepted = first;
    return GpsTrackAcceptResult(trackPoint: first, addedDistanceM: 0);
  }
}
