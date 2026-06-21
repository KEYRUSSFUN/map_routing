import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:map_routing/core/network/backend_urls.dart';
import 'package:map_routing/core/network/config.dart';
import 'package:map_routing/data/models/moment.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MomentService {
  MomentService({String? baseUrl, required this.token})
      : baseUrl = baseUrl ?? backendBaseUrl;

  final String baseUrl;
  final String token;

  Map<String, String> get _headers => {
        'Authorization': token,
        'Content-Type': 'application/json',
      };

  Future<MomentFeedPage> fetchFeed({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/moments/feed?page=$page&per_page=20'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load feed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid feed response');
    }

    return _parseFeedPage(data);
  }

  Future<List<MomentItem>> fetchMyMoments() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/moments/me'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load moments: ${response.statusCode}');
    }

    return _parseMomentList(response.body);
  }

  Future<List<MomentItem>> fetchUserMoments(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/moments/user/$userId'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load user moments: ${response.statusCode}');
    }

    return _parseMomentList(response.body);
  }

  Future<MomentItem> publishMoment({
    String? text,
    File? photo,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/moments'),
    );
    request.headers['Authorization'] = token;

    final trimmed = text?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      request.fields['text'] = trimmed;
    }
    if (photo != null) {
      request.files.add(
        await http.MultipartFile.fromPath('photo', photo.path),
      );
    }

    final streamedResponse = await request.send();
    final body = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode != 201) {
      String message = 'Failed to publish moment (${streamedResponse.statusCode})';
      try {
        final data = jsonDecode(body);
        if (data is Map) {
          if (data['error'] != null) {
            message = data['error'].toString();
          } else if (data['message'] != null) {
            message = data['message'].toString();
          }
        }
      } catch (_) {
        final snippet = body.trim();
        if (snippet.isNotEmpty && snippet.length <= 120) {
          message = snippet;
        }
      }
      throw Exception(message);
    }

    final data = jsonDecode(body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid publish response');
    }
    return _parseMomentItem(data);
  }

  Future<({bool liked, int likesCount})> toggleLike(int momentId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/moments/$momentId/like'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to toggle like: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid like response');
    }

    return (
      liked: data['liked'] == true,
      likesCount: (data['likes_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<List<MomentCommentItem>> fetchComments(int momentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/moments/$momentId/comments'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load comments: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (data is! List) return [];

    return data
        .map(
          (item) => MomentCommentItem.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<({MomentCommentItem comment, int commentsCount})> addComment(
    int momentId,
    String text,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/moments/$momentId/comments'),
      headers: _headers,
      body: jsonEncode({'text': text.trim()}),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to add comment: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid comment response');
    }

    final commentRaw = data['comment'];
    if (commentRaw is! Map<String, dynamic>) {
      throw Exception('Invalid comment payload');
    }

    return (
      comment: MomentCommentItem.fromJson(commentRaw),
      commentsCount: (data['comments_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> deleteMoment(int momentId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/moments/$momentId'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete moment: ${response.statusCode}');
    }
  }

  Future<MomentItem> updateMoment({
    required int momentId,
    required String text,
    File? photo,
    bool removePhoto = false,
  }) async {
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('$baseUrl/api/moments/$momentId'),
    );
    request.headers['Authorization'] = token;
    request.fields['text'] = text.trim();
    if (removePhoto) {
      request.fields['remove_photo'] = 'true';
    }
    if (photo != null) {
      request.files.add(
        await http.MultipartFile.fromPath('photo', photo.path),
      );
    }

    final streamedResponse = await request.send();
    final body = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode != 200) {
      String message = 'Failed to update moment (${streamedResponse.statusCode})';
      try {
        final data = jsonDecode(body);
        if (data is Map && data['error'] != null) {
          message = data['error'].toString();
        }
      } catch (_) {}
      throw Exception(message);
    }

    final data = jsonDecode(body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid update response');
    }
    return _parseMomentItem(data);
  }

  MomentFeedPage _parseFeedPage(Map<String, dynamic> json) {
    final page = MomentFeedPage.fromJson(json);
    return MomentFeedPage(
      moments: page.moments.map(_withAbsoluteUrls).toList(),
      page: page.page,
      hasMore: page.hasMore,
    );
  }

  List<MomentItem> _parseMomentList(String body) {
    final data = jsonDecode(body);
    if (data is! List) return [];
    return data
        .map(
          (item) => _withAbsoluteUrls(
            MomentItem.fromJson(Map<String, dynamic>.from(item as Map)),
          ),
        )
        .toList();
  }

  MomentItem _parseMomentItem(Map<String, dynamic> json) {
    return _withAbsoluteUrls(MomentItem.fromJson(json));
  }

  MomentItem _withAbsoluteUrls(MomentItem moment) {
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

  static Future<MomentService?> fromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) return null;
    return MomentService(token: token);
  }
}
