import 'dart:io';

import 'package:geolocator/geolocator.dart';

abstract final class WorkoutLocationSettings {
  static LocationSettings forTracking() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 4,
        forceLocationManager: false,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'StrideTrack',
          notificationText: 'Тренировка в процессе',
          notificationChannelName: 'Тренировка',
          enableWakeLock: true,
        ),
      );
    }

    if (Platform.isIOS || Platform.isMacOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 4,
        activityType: ActivityType.fitness,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
        pauseLocationUpdatesAutomatically: false,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 4,
    );
  }

  static LocationSettings forIdle() {
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 8,
    );
  }

  static Future<bool> ensureWorkoutPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    if (Platform.isAndroid &&
        permission == LocationPermission.whileInUse) {
      final background = await Geolocator.requestPermission();
      if (background == LocationPermission.always) {
        return true;
      }
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}
