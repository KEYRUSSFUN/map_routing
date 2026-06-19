import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:map_routing/data/models/track_point.dart';
import 'package:map_routing/data/services/user_workout_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:xml/xml.dart';
import 'package:yandex_maps_mapkit/mapkit.dart';

class GeometryProvider {
  static const startPosition = CameraPosition(
    Point(latitude: 53.3606, longitude: 83.7636),
    zoom: 13.0,
    azimuth: 0.0,
    tilt: 0.0,
  );

  static List<Point> defaultPoints = [];

  static Future<bool> requestPermission() async {
    return Geolocator.requestPermission()
        .then(
          (value) =>
              value == LocationPermission.always ||
              value == LocationPermission.whileInUse,
        )
        .catchError((_) => false);
  }

  static Future<bool> checkPermission() async {
    return Geolocator.checkPermission()
        .then(
          (value) =>
              value == LocationPermission.always ||
              value == LocationPermission.whileInUse,
        )
        .catchError((_) => false);
  }

  static Future<void> loadGPXPoints(
    void Function(String message) onError, {
    required String gpxPath,
  }) async {
    if (gpxPath.isEmpty) {
      defaultPoints = [];
      return;
    }

    try {
      defaultPoints = await loadAndParseGPX(gpxPath);
      if (defaultPoints.isEmpty) {
        onError('Ошибка загрузки GPX');
      }
    } catch (e) {
      defaultPoints = [];
      onError('Ошибка загрузки точек из GPX: $e');
    }
  }

  static Future<List<Point>> loadAndParseGPX(String gpxPath) async {
    final gpxData = await _loadGPXFile(gpxPath);
    if (gpxData == null) {
      return [];
    }
    return _parseGPXData(gpxData);
  }

  static Future<String?> _loadGPXFile(String gpxPath) async {
    try {
      final file = File(gpxPath);
      if (!await file.exists()) {
        debugPrint('Файл не существует');
        return null;
      }
      return await file.readAsString();
    } catch (e) {
      debugPrint('Ошибка при чтении GPX-файла: $e');
      return null;
    }
  }

  static Future<String?> saveTrackedRouteAsGpx(List<TrackPoint> points) async {
    if (points.isEmpty) return null;

    final startedAt = points.first.time ?? DateTime.now();
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('gpx', nest: () {
      builder.attribute('version', '1.1');
      builder.attribute('creator', 'StrideTrack');
      builder.element('metadata', nest: () {
        builder.element('time', nest: startedAt.toUtc().toIso8601String());
      });
      builder.element('trk', nest: () {
        builder.element('name', nest: 'Тренировка');
        builder.element('trkseg', nest: () {
          for (final point in points) {
            builder.element('trkpt', nest: () {
              builder.attribute('lat', point.latitude);
              builder.attribute('lon', point.longitude);
              if (point.elevation != null) {
                builder.element('ele', nest: point.elevation);
              }
              if (point.time != null) {
                builder.element('time',
                    nest: point.time!.toUtc().toIso8601String());
              }
            });
          }
        });
      });
    });

    final filePath = await UserWorkoutStorage.instance.newGpxFilePath('tracked_route');
    if (filePath == null) return null;
    final file = File(filePath);
    await file.writeAsString(builder.buildDocument().toXmlString(pretty: true));
    return filePath;
  }

  static Future<List<Point>> _parseGPXData(String gpxData) async {
    final document = XmlDocument.parse(gpxData);
    final List<Point> points = [];
    try {
      points.addAll(document
          .findAllElements('trkpt')
          .map((element) => Point(
                latitude: double.parse(element.getAttribute('lat')!),
                longitude: double.parse(element.getAttribute('lon')!),
              ))
          .toList());
    } catch (e) {
      debugPrint('Ошибка парсинга: $e');
    }
    return points;
  }

  static Future<String?> saveRouteAsGpx(List<Point> points) async {
    if (points.isEmpty) return null;

    final status = await Permission.storage.request();
    if (!status.isGranted) return null;

    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('gpx', nest: () {
      builder.attribute('version', '1.1');
      builder.attribute('creator', 'StrideTrack');
      builder.element('trk', nest: () {
        builder.element('name', nest: 'Saved Route');
        builder.element('trkseg', nest: () {
          for (final point in points) {
            builder.element('trkpt', nest: () {
              builder.attribute('lat', point.latitude);
              builder.attribute('lon', point.longitude);
              builder.element('time',
                  nest: DateTime.now().toUtc().toIso8601String());
            });
          }
        });
      });
    });

    final gpxXml = builder.buildDocument().toXmlString(pretty: true);
    final filePath = await UserWorkoutStorage.instance.newGpxFilePath('saved_route');
    if (filePath == null) return null;

    final file = File(filePath);
    await file.writeAsString(gpxXml);
    return file.path;
  }
}
