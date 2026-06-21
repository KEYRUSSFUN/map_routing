import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:map_routing/core/network/backend_urls.dart';
import 'package:map_routing/core/network/config.dart';
import 'package:map_routing/data/models/club.dart';
import 'package:map_routing/data/models/moment.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClubService {
  ClubService({required this.token});

  final String token;

  Map<String, String> get _headers => {
        'Authorization': token,
        'Content-Type': 'application/json',
      };

  Future<List<ClubSummary>> fetchMyClubs() async {
    final response = await http.get(
      Uri.parse('$backendBaseUrl/api/clubs'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      debugPrint('fetchMyClubs failed: ${response.statusCode} ${response.body}');
      throw Exception('Не удалось загрузить клубы');
    }

    final decoded = json.decode(response.body);
    if (decoded is! Map) return const [];

    final raw = decoded['clubs'];
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((item) => ClubSummary.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<ClubSummary>> discoverClubs(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final response = await http.get(
      Uri.parse(
        '$backendBaseUrl/api/clubs/discover?q=${Uri.encodeQueryComponent(trimmed)}',
      ),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response.body, 'Не удалось найти клубы'));
    }

    final decoded = json.decode(response.body);
    if (decoded is! Map) return const [];

    final raw = decoded['clubs'];
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((item) => ClubSummary.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<ClubSummary> fetchClub(int clubId) async {
    final response = await http.get(
      Uri.parse('$backendBaseUrl/api/clubs/$clubId'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response.body, 'Не удалось загрузить клуб'));
    }

    final decoded = json.decode(response.body);
    if (decoded is Map<String, dynamic>) {
      return ClubSummary.fromJson(decoded);
    }
    if (decoded is Map) {
      return ClubSummary.fromJson(Map<String, dynamic>.from(decoded));
    }
    throw Exception('Некорректный ответ сервера');
  }

  Future<ClubSummary> createClub({
    required CreateClubPayload payload,
    File? avatar,
    File? cover,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$backendBaseUrl/api/clubs'),
    );
    request.headers['Authorization'] = token;
    request.fields.addAll(payload.toFields());

    if (avatar != null) {
      request.files.add(await http.MultipartFile.fromPath('avatar', avatar.path));
    }
    if (cover != null) {
      request.files.add(await http.MultipartFile.fromPath('cover', cover.path));
    }

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode == 201) {
      return _parseClub(body);
    }

    throw Exception(_errorMessage(body, 'Не удалось создать клуб'));
  }

  Future<ClubSummary> updateClub({
    required int clubId,
    required UpdateClubPayload payload,
    File? avatar,
    File? cover,
  }) async {
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('$backendBaseUrl/api/clubs/$clubId'),
    );
    request.headers['Authorization'] = token;
    request.fields.addAll(payload.toFields());

    if (avatar != null) {
      request.files.add(await http.MultipartFile.fromPath('avatar', avatar.path));
    }
    if (cover != null) {
      request.files.add(await http.MultipartFile.fromPath('cover', cover.path));
    }

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode == 200) {
      return _parseClub(body);
    }

    throw Exception(_errorMessage(body, 'Не удалось обновить клуб'));
  }

  Future<ClubSummary> updateSettings({
    required int clubId,
    required ClubSettingsPayload payload,
  }) async {
    final response = await http.put(
      Uri.parse('$backendBaseUrl/api/clubs/$clubId/settings'),
      headers: _headers,
      body: json.encode(payload.toJson()),
    );

    if (response.statusCode == 200) {
      return _parseClub(response.body);
    }

    throw Exception(_errorMessage(response.body, 'Не удалось сохранить настройки'));
  }

  Future<String> joinClub(int clubId) async {
    final response = await http.post(
      Uri.parse('$backendBaseUrl/api/clubs/$clubId/join'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded is Map && decoded['status'] != null) {
        return decoded['status'].toString();
      }
      return 'active';
    }

    throw Exception(_errorMessage(response.body, 'Не удалось вступить в клуб'));
  }

  Future<void> leaveClub(int clubId) async {
    final response = await http.post(
      Uri.parse('$backendBaseUrl/api/clubs/$clubId/leave'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response.body, 'Не удалось выйти из клуба'));
    }
  }

  Future<List<ClubMemberItem>> fetchMembers(int clubId) async {
    final response = await http.get(
      Uri.parse('$backendBaseUrl/api/clubs/$clubId/members'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response.body, 'Не удалось загрузить участников'));
    }

    final decoded = json.decode(response.body);
    if (decoded is! Map) return const [];

    final raw = decoded['members'];
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((item) => ClubMemberItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<({List<MomentItem> posts, bool hasMore, int page})> fetchPosts({
    required int clubId,
    int page = 1,
  }) async {
    final response = await http.get(
      Uri.parse('$backendBaseUrl/api/clubs/$clubId/posts?page=$page&per_page=20'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response.body, 'Не удалось загрузить записи'));
    }

    final decoded = json.decode(response.body);
    if (decoded is! Map) {
      return (posts: const <MomentItem>[], hasMore: false, page: page);
    }

    final raw = decoded['posts'];
    final posts = raw is List
        ? raw
            .whereType<Map>()
            .map(
              (item) => _momentWithAbsoluteUrls(
                MomentItem.fromJson(Map<String, dynamic>.from(item)),
              ),
            )
            .toList()
        : <MomentItem>[];

    return (
      posts: posts,
      hasMore: decoded['has_more'] == true,
      page: (decoded['page'] as num?)?.toInt() ?? page,
    );
  }

  Future<MomentItem> publishPost({
    required int clubId,
    String? text,
    File? photo,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$backendBaseUrl/api/clubs/$clubId/posts'),
    );
    request.headers['Authorization'] = token;

    final trimmed = text?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      request.fields['text'] = trimmed;
    }
    if (photo != null) {
      request.files.add(await http.MultipartFile.fromPath('photo', photo.path));
    }

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode == 201) {
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) {
        return _momentWithAbsoluteUrls(MomentItem.fromJson(decoded));
      }
      if (decoded is Map) {
        return _momentWithAbsoluteUrls(
          MomentItem.fromJson(Map<String, dynamic>.from(decoded)),
        );
      }
    }

    throw Exception(_errorMessage(body, 'Не удалось опубликовать запись'));
  }

  Future<({List<ClubMemberWorkout> workouts, bool hasMore, int page})> fetchWorkouts({
    required int clubId,
    int page = 1,
  }) async {
    final response = await http.get(
      Uri.parse('$backendBaseUrl/api/clubs/$clubId/workouts?page=$page&per_page=20'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response.body, 'Не удалось загрузить тренировки'));
    }

    final decoded = json.decode(response.body);
    if (decoded is! Map) {
      return (workouts: const <ClubMemberWorkout>[], hasMore: false, page: page);
    }

    final raw = decoded['workouts'];
    final workouts = raw is List
        ? raw
            .whereType<Map>()
            .map((item) {
              final map = Map<String, dynamic>.from(item);
              return ClubMemberWorkout.fromJson({
                ...map,
                if (map['avatarUrl'] != null)
                  'avatarUrl': absoluteBackendUrl(map['avatarUrl']?.toString()),
                if (map['photo_url'] != null)
                  'photo_url': absoluteBackendUrl(map['photo_url']?.toString()),
              });
            })
            .toList()
        : <ClubMemberWorkout>[];

    return (
      workouts: workouts,
      hasMore: decoded['has_more'] == true,
      page: (decoded['page'] as num?)?.toInt() ?? page,
    );
  }

  Future<ClubWeeklyStats> fetchWeeklyStats(int clubId) async {
    final response = await http.get(
      Uri.parse('$backendBaseUrl/api/clubs/$clubId/weekly-stats'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response.body, 'Не удалось загрузить статистику'));
    }

    final decoded = json.decode(response.body);
    if (decoded is Map<String, dynamic>) {
      return ClubWeeklyStats.fromJson(decoded);
    }
    if (decoded is Map) {
      return ClubWeeklyStats.fromJson(Map<String, dynamic>.from(decoded));
    }
    throw Exception('Некорректный ответ сервера');
  }

  ClubSummary _parseClub(String body) {
    final decoded = json.decode(body);
    if (decoded is Map<String, dynamic>) {
      return ClubSummary.fromJson(decoded);
    }
    if (decoded is Map) {
      return ClubSummary.fromJson(Map<String, dynamic>.from(decoded));
    }
    throw Exception('Некорректный ответ сервера');
  }

  MomentItem _momentWithAbsoluteUrls(MomentItem moment) {
    return MomentItem(
      id: moment.id,
      userId: moment.userId,
      userName: moment.userName,
      avatarUrl: absoluteBackendUrl(moment.avatarUrl),
      text: moment.text,
      photoUrl: absoluteBackendUrl(moment.photoUrl) ?? moment.photoUrl,
      createdAt: moment.createdAt,
      likesCount: moment.likesCount,
      commentsCount: moment.commentsCount,
      likedByMe: moment.likedByMe,
      isMe: moment.isMe,
      clubId: moment.clubId,
      clubTitle: moment.clubTitle,
      clubAvatarUrl: absoluteBackendUrl(moment.clubAvatarUrl),
      isClubPost: moment.isClubPost,
    );
  }

  String _errorMessage(String body, String fallback) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map && decoded['error'] != null) {
        return decoded['error'].toString();
      }
    } catch (_) {}
    return fallback;
  }

  static Future<ClubService?> fromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) return null;
    return ClubService(token: token);
  }
}
