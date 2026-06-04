import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:map_routing/core/network/config.dart';
import 'package:map_routing/data/models/track_point.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackendRoute {
  const BackendRoute({
    required this.id,
    required this.path,
    this.creationDate,
  });

  final int id;
  final Map<String, dynamic> path;
  final DateTime? creationDate;

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

    DateTime? creationDate;
    final dateStr = json['creation_date'] as String?;
    if (dateStr != null && dateStr.isNotEmpty) {
      creationDate = DateTime.tryParse(dateStr)?.toLocal();
    }

    return BackendRoute(
      id: json['id_Route'] as int,
      path: pathMap,
      creationDate: creationDate,
    );
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
