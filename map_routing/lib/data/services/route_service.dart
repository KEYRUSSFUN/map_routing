import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:map_routing/core/network/config.dart';
import 'package:map_routing/data/models/track_point.dart';
import 'package:map_routing/data/models/workout_activity_type.dart';
import 'package:map_routing/data/models/workout_metadata.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackendRoute {
  const BackendRoute({
    required this.id,
    required this.path,
    this.creationDate,
    this.title,
    this.activityType,
    this.description,
    this.tags = const [],
    this.effortLevel,
    this.notes,
    this.privacy,
    this.distanceMeters,
    this.durationSeconds,
    this.calories,
    this.elevationGainM,
    this.avgSpeedKmh,
    this.startedAt,
    this.photoUrl,
  });

  final int id;
  final Map<String, dynamic> path;
  final DateTime? creationDate;
  final String? title;
  final String? activityType;
  final String? description;
  final List<String> tags;
  final int? effortLevel;
  final String? notes;
  final String? privacy;
  final double? distanceMeters;
  final int? durationSeconds;
  final int? calories;
  final double? elevationGainM;
  final double? avgSpeedKmh;
  final DateTime? startedAt;
  final String? photoUrl;

  factory BackendRoute.fromJson(Map<String, dynamic> json) {
    final rawPath = json['path'];
    Map<String, dynamic> pathMap;
    if (rawPath is String) {
      pathMap = jsonDecode(rawPath) as Map<String, dynamic>;
    } else if (rawPath is Map) {
      pathMap = Map<String, dynamic>.from(rawPath);
    } else {
      pathMap = {};
    }

    DateTime? parseDate(String? value) {
      if (value == null || value.isEmpty) return null;
      return DateTime.tryParse(value)?.toLocal();
    }

    return BackendRoute(
      id: json['id_Route'] as int,
      path: pathMap,
      creationDate: parseDate(json['creation_date'] as String?),
      title: json['title'] as String?,
      activityType: json['activity_type'] as String?,
      description: json['description'] as String?,
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      effortLevel: (json['effort_level'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      privacy: json['privacy'] as String?,
      distanceMeters: (json['distance'] as num?)?.toDouble(),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      calories: (json['calories'] as num?)?.toInt(),
      elevationGainM: (json['elevation_gain_m'] as num?)?.toDouble(),
      avgSpeedKmh: (json['avg_speed_kmh'] as num?)?.toDouble(),
      startedAt: parseDate(json['started_at'] as String?),
      photoUrl: _absoluteBackendUrl(json['photo_url'] as String?),
    );
  }

  static String? _absoluteBackendUrl(String? relativeOrAbsolute) {
    if (relativeOrAbsolute == null || relativeOrAbsolute.isEmpty) return null;
    if (relativeOrAbsolute.startsWith('http')) return relativeOrAbsolute;
    if (relativeOrAbsolute.startsWith('/')) {
      return '$backendBaseUrl$relativeOrAbsolute';
    }
    return '$backendBaseUrl/$relativeOrAbsolute';
  }
}

class RouteService {
  Future<List<BackendRoute>> fetchUserRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) return [];

    final response = await http.get(
      Uri.parse('$backendBaseUrl/api/routes'),
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Не удалось загрузить маршруты: ${response.statusCode}');
    }

    final List<dynamic> data = json.decode(response.body);
    return data
        .whereType<Map<String, dynamic>>()
        .map(BackendRoute.fromJson)
        .toList();
  }

  Future<int> uploadWorkout({
    required Map<String, dynamic> geoJsonPath,
    required WorkoutMetadata metadata,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) {
      throw Exception('Не авторизован');
    }

    final body = {
      'path': geoJsonPath,
      ...metadata.toBackendPayload(),
    };

    final response = await http.post(
      Uri.parse('$backendBaseUrl/api/routes'),
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
      body: json.encode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Не удалось отправить тренировку: ${response.statusCode} ${response.body}',
      );
    }

    final decoded = json.decode(response.body);
    if (decoded is Map<String, dynamic>) {
      final id = (decoded['id'] as num?)?.toInt();
      if (id == null) {
        throw Exception('Сервер не вернул id маршрута');
      }
      return id;
    }
    throw Exception('Некорректный ответ сервера при загрузке маршрута');
  }

  Future<BackendRoute> updateRouteMetadata({
    required int routeId,
    required String title,
    required String description,
    required List<String> tags,
    required int effortLevel,
    required WorkoutPrivacy privacy,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) {
      throw Exception('Не авторизован');
    }

    final response = await http.patch(
      Uri.parse('$backendBaseUrl/api/routes/$routeId'),
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'title': title,
        'description': description,
        'tags': tags,
        'effort_level': effortLevel,
        'privacy': privacy.id,
      }),
    );

    if (response.statusCode != 200) {
      String message = 'Не удалось обновить маршрут (${response.statusCode})';
      try {
        final data = json.decode(response.body);
        if (data is Map && data['error'] != null) {
          message = data['error'].toString();
        }
      } catch (_) {}
      throw Exception(message);
    }

    final decoded = json.decode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Некорректный ответ сервера');
    }
    final routeRaw = decoded['route'];
    if (routeRaw is! Map<String, dynamic>) {
      throw Exception('Сервер не вернул маршрут');
    }
    return BackendRoute.fromJson(routeRaw);
  }

  Future<String?> uploadWorkoutPhoto(int routeId, File photoFile) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) return null;

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$backendBaseUrl/api/routes/$routeId/photo'),
    );
    request.headers['Authorization'] = token;
    request.files.add(
      await http.MultipartFile.fromPath('photo', photoFile.path),
    );

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      throw Exception(
        'Не удалось загрузить фото: ${streamed.statusCode} $body',
      );
    }

    final decoded = json.decode(body);
    if (decoded is Map<String, dynamic>) {
      return BackendRoute._absoluteBackendUrl(
        decoded['photo_url'] as String?,
      );
    }
    return null;
  }

  Future<bool> deleteRoute(int routeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null || token.isEmpty) return false;

      final response = await http
          .delete(
            Uri.parse('$backendBaseUrl/api/routes/$routeId'),
            headers: {
              'Authorization': token,
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 12));

      return response.statusCode == 200;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> uploadRoute(Map<String, dynamic> geoJsonPath) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) return false;

    final response = await http.post(
      Uri.parse('$backendBaseUrl/api/routes'),
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
      body: json.encode({'path': geoJsonPath}),
    );

    return response.statusCode == 200;
  }

  static Map<String, dynamic> trackPointsToGeoJson(List<TrackPoint> points) {
    return {
      'type': 'LineString',
      'coordinates': points
          .map((p) => [p.longitude, p.latitude])
          .toList(),
    };
  }
}
