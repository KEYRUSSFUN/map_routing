import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:map_routing/core/network/config.dart';
import 'package:map_routing/data/models/route_share_snapshot.dart';
import 'package:map_routing/data/services/gpx_workout_service.dart';
import 'package:map_routing/data/services/user_workout_storage.dart';
import 'package:path/path.dart' as p;

class ChatRouteService {
  ChatRouteService({String? baseUrl, required this.token})
      : baseUrl = baseUrl ?? backendBaseUrl;

  final String baseUrl;
  final String token;

  Future<Map<String, dynamic>> shareRoute({
    required String chatId,
    required String gpxPath,
    String? title,
    RouteShareSnapshot? snapshot,
    String? photoPath,
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
    if (snapshot != null) {
      request.fields.addAll(snapshot.toFormFields());
    }
    if (photoPath != null && photoPath.isNotEmpty) {
      final photoFile = File(photoPath);
      if (await photoFile.exists()) {
        request.files.add(
          await http.MultipartFile.fromPath('photo', photoPath),
        );
      }
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
    String? title,
    RouteShareSnapshot? snapshot,
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

    if (response.bodyBytes.isEmpty) {
      throw Exception('Сервер вернул пустой файл маршрута');
    }

    var userDir =
        await UserWorkoutStorage.instance.getCurrentUserWorkoutsDirectory();
    if (userDir == null) {
      await UserWorkoutStorage.instance.syncUserIdFromToken(token);
      userDir =
          await UserWorkoutStorage.instance.getCurrentUserWorkoutsDirectory();
    }
    if (userDir == null) {
      throw Exception('Не удалось получить папку для сохранения');
    }

    final safeName = p.basename(originalFilename);
    final fileName = safeName.toLowerCase().endsWith('.gpx')
        ? safeName
        : '$safeName.gpx';
    final targetPath = p.join(
      userDir.path,
      'shared_${shareId}_$fileName',
    );

    await File(targetPath).writeAsBytes(response.bodyBytes);

    final gpxService = GpxWorkoutService();
    if (!await gpxService.hasValidTrack(targetPath)) {
      try {
        await File(targetPath).delete();
      } catch (_) {}
      throw Exception('Файл маршрута не содержит точек трека');
    }

    final displayTitle = (title?.trim().isNotEmpty ?? false)
        ? title!.trim()
        : p.basenameWithoutExtension(fileName);

    String? localPhotoPath;
    if (snapshot?.hasPhoto ?? false) {
      localPhotoPath = await _downloadSharePhoto(
        chatId: chatId,
        shareId: shareId,
        gpxPath: targetPath,
      );
    }

    final photoUrl = snapshot?.photoUrl != null
        ? _absoluteBackendUrl(snapshot!.photoUrl!)
        : null;

    await gpxService.writeImportedRouteMetadata(
      targetPath,
      shareId: shareId,
      title: displayTitle,
      snapshot: snapshot?.copyWithPhotoUrl(photoUrl),
      localPhotoPath: localPhotoPath,
    );
    GpxWorkoutService.invalidateMemoryCache();

    return targetPath;
  }

  Future<String?> _downloadSharePhoto({
    required String chatId,
    required int shareId,
    required String gpxPath,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/api/group_chats/$chatId/route_shares/$shareId/photo',
      ),
      headers: {'Authorization': token},
    );
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      return null;
    }

    final contentType = response.headers['content-type'] ?? '';
    var ext = '.jpg';
    if (contentType.contains('png')) {
      ext = '.png';
    } else if (contentType.contains('webp')) {
      ext = '.webp';
    }

    final baseName = p.basenameWithoutExtension(gpxPath);
    final photoPath = p.join(p.dirname(gpxPath), '${baseName}_photo$ext');
    await File(photoPath).writeAsBytes(response.bodyBytes);
    return photoPath;
  }

  String _absoluteBackendUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    if (url.startsWith('/')) {
      return '$baseUrl$url';
    }
    return '$baseUrl/$url';
  }
}

extension _RouteShareSnapshotPhoto on RouteShareSnapshot {
  RouteShareSnapshot copyWithPhotoUrl(String? url) {
    return RouteShareSnapshot(
      activityType: activityType,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      elevationGainM: elevationGainM,
      avgSpeedKmh: avgSpeedKmh,
      calories: calories,
      startedAtIso: startedAtIso,
      description: description,
      tags: tags,
      effortLevel: effortLevel,
      notes: notes,
      photoUrl: url ?? photoUrl,
      hasPhoto: hasPhoto,
    );
  }
}
