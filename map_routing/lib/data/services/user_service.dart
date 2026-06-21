import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:map_routing/core/network/config.dart';
import 'package:map_routing/data/services/chat_session_cache.dart';
import 'package:map_routing/data/services/socket_chat_service.dart';
import 'package:map_routing/data/services/statistics_service.dart';
import 'package:map_routing/data/services/user_profile_cache.dart';
import 'package:map_routing/data/services/user_workout_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  static Map<String, dynamic>? _cachedSelfInfo;
  static DateTime? _cachedSelfInfoAt;
  static const _selfInfoTtl = Duration(minutes: 5);

  static void invalidateSelfInfoCache() {
    _cachedSelfInfo = null;
    _cachedSelfInfoAt = null;
  }

  Future<Map<String, dynamic>?> fetchUserInfo({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _cachedSelfInfo != null &&
        _cachedSelfInfoAt != null &&
        now.difference(_cachedSelfInfoAt!) < _selfInfoTtl) {
      return _cachedSelfInfo;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) return null;

    final response = await http.get(
      Uri.parse('$backendBaseUrl/api/user_info'),
      headers: {'Authorization': token, 'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        _cachedSelfInfo = decoded;
        _cachedSelfInfoAt = now;
        return decoded;
      }
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        _cachedSelfInfo = map;
        _cachedSelfInfoAt = now;
        return map;
      }
    } else {
      debugPrint(
          'Error fetching user info: ${response.statusCode} - ${response.body}');
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchOtherUserInfo({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) return null;

    final url = userId == null
        ? Uri.parse('$backendBaseUrl/api/user_info')
        : Uri.parse('$backendBaseUrl/api/user_info/$userId');

    final response = await http.get(
      url,
      headers: {'Authorization': token, 'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      debugPrint(
          'Error fetching other user info: ${response.statusCode} - ${response.body}');
      return null;
    }
  }

  Future<String?> uploadAvatar(File file) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) return null;

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$backendBaseUrl/api/user_info/avatar'),
    );
    request.headers['Authorization'] = token;
    request.files.add(
      await http.MultipartFile.fromPath('avatar', file.path),
    );

    final streamedResponse = await request.send();
    final body = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode == 200) {
      final data = json.decode(body) as Map<String, dynamic>;
      return data['avatar_url'] as String?;
    }

    debugPrint(
      'Error uploading avatar: ${streamedResponse.statusCode} - $body',
    );
    return null;
  }

  Future<Map<String, dynamic>?> setCoverPreset(String presetId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) return null;

    final response = await http.post(
      Uri.parse('$backendBaseUrl/api/user_info/cover/preset'),
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'cover_preset': presetId}),
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        invalidateSelfInfoCache();
        return decoded;
      }
      if (decoded is Map) {
        invalidateSelfInfoCache();
        return Map<String, dynamic>.from(decoded);
      }
    }

    debugPrint(
      'Error setting cover preset: ${response.statusCode} - ${response.body}',
    );
    return null;
  }

  Future<Map<String, dynamic>?> uploadCover(File file) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) return null;

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$backendBaseUrl/api/user_info/cover'),
    );
    request.headers['Authorization'] = token;
    request.files.add(
      await http.MultipartFile.fromPath('cover', file.path),
    );

    final streamedResponse = await request.send();
    final body = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode == 200) {
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) {
        invalidateSelfInfoCache();
        return decoded;
      }
      if (decoded is Map) {
        invalidateSelfInfoCache();
        return Map<String, dynamic>.from(decoded);
      }
    }

    debugPrint(
      'Error uploading cover: ${streamedResponse.statusCode} - $body',
    );
    return null;
  }

  Future<Map<String, dynamic>?> updateUserInfo(
      Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) return null;

    final response = await http.post(
      Uri.parse('$backendBaseUrl/api/user_info'),
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      invalidateSelfInfoCache();
      return json.decode(response.body);
    } else {
      debugPrint(
          'Error updating user info: ${response.statusCode} - ${response.body}');
      return null;
    }
  }

  Future<Map<String, dynamic>?> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) return null;

    final response = await http.post(
      Uri.parse('$backendBaseUrl/api/logout'),
      headers: {'Authorization': token},
    );

    if (response.statusCode == 200) {
      await prefs.remove('jwt_token');
      await UserWorkoutStorage.instance.clearCurrentUserId();
      StatisticsService.clearGlobalCache();
      invalidateSelfInfoCache();
      UserProfileCache.instance.clear();
      ChatSessionCache.instance.clear();
      SocketChatService.instance.disconnect();
      return json.decode(response.body);
    } else {
      debugPrint('Error logging out: ${response.statusCode} - ${response.body}');
      return null;
    }
  }
}
