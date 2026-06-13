import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:map_routing/core/network/config.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ChatRouteService {
  ChatRouteService({String? baseUrl, required this.token})
      : baseUrl = baseUrl ?? backendBaseUrl;

  final String baseUrl;
  final String token;

  Future<Map<String, dynamic>> shareRoute({
    required String chatId,
    required String gpxPath,
    String? title,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/group_chats/$chatId/route_shares'),
    );
    request.headers['Authorization'] = token;
    request.files.add(await http.MultipartFile.fromPath('gpx', gpxPath));
    if (title != null && title.trim().isNotEmpty) {
      request.fields['title'] = title.trim();
    }

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode == 201) {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['message'] is Map) {
        return Map<String, dynamic>.from(decoded['message'] as Map);
      }
      throw Exception('Unexpected share route response');
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] != null) {
        throw Exception(decoded['error'].toString());
      }
    } catch (_) {}
    throw Exception('Failed to share route: ${streamed.statusCode}');
  }

  Future<String> downloadRoute({
    required String chatId,
    required int shareId,
    required String originalFilename,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/api/group_chats/$chatId/route_shares/$shareId/download',
      ),
      headers: {'Authorization': token},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to download route: ${response.statusCode}');
    }

    final directory = await getExternalStorageDirectory();
    if (directory == null) {
      throw Exception('Не удалось получить папку для сохранения');
    }

    final safeName = p.basename(originalFilename);
    final fileName = safeName.toLowerCase().endsWith('.gpx')
        ? safeName
        : '$safeName.gpx';
    final targetPath = p.join(
      directory.path,
      'shared_${shareId}_$fileName',
    );

    await File(targetPath).writeAsBytes(response.bodyBytes);
    return targetPath;
  }
}
