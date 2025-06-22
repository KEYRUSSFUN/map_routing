import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:xml/xml.dart';
import 'package:yandex_maps_mapkit/mapkit.dart';
import 'package:path/path.dart' as p;
import 'package:http_parser/http_parser.dart';
import 'package:http/http.dart' as http;
import 'dart:core';

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

  static Future<void> loadGPXPoints(BuildContext context,
      {required String gpxPath}) async {
    if (gpxPath.isEmpty) {
      defaultPoints = [];
      return;
    }

    try {
      defaultPoints = await loadAndParseGPX(context, gpxPath);
    } catch (e) {
      defaultPoints = [];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки точек из GPX: $e')),
      );
    }
  }

  static Future<List<Point>> loadAndParseGPX(
      BuildContext context, String gpxPath) async {
    try {
      final gpxData = await _loadGPXFile(gpxPath);
      if (gpxData == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Ошибка загрузки GPX')));
        return [];
      }
      return await _parseGPXData(gpxData);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка обработки GPX: $e')));
      return [];
    }
  }

  static Future<String?> _loadGPXFile(String gpxPath) async {
    try {
      final file = File(gpxPath);
      if (!await file.exists()) {
        print('Файл не существует');
        return null;
      }
      return await file.readAsString();
    } catch (e) {
      print('Ошибка при чтении GPX-файла: $e');
      return null;
    }
  }

  static Future<String?> saveTrackedRouteAsGpx(List<Point> points) async {
    if (points.isEmpty) return null;

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<gpx version="1.1" creator="YourAppName">');
    buffer.writeln('  <trk><name>Tracked Route</name><trkseg>');

    for (final point in points) {
      buffer.writeln(
          '    <trkpt lat="${point.latitude}" lon="${point.longitude}"></trkpt>');
    }

    buffer.writeln('  </trkseg></trk>');
    buffer.writeln('</gpx>');

    final directory = await getExternalStorageDirectory();
    final filePath =
        '${directory?.path}/tracked_route_${DateTime.now().millisecondsSinceEpoch}.gpx';
    final file = File(filePath);
    await file.writeAsString(buffer.toString());
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
      print("Ошибка парсинга: $e");
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
      builder.attribute('creator', 'MapRoutingApp');
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
    final directory = await getExternalStorageDirectory();
    final filePath =
        '${directory?.path}/saved_route_${DateTime.now().millisecondsSinceEpoch}.gpx';

    final file = File(filePath);
    await file.writeAsString(gpxXml);
    return file.path;
  }
}
