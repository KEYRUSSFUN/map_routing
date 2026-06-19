import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:map_routing/core/network/backend_urls.dart';
import 'package:map_routing/core/network/config.dart';
import 'package:map_routing/data/models/story.dart';

class StoryService {
  StoryService({String? baseUrl, required this.token})
      : baseUrl = baseUrl ?? backendBaseUrl;

  final String baseUrl;
  final String token;

  Map<String, String> get _headers => {
        'Authorization': token,
        'Content-Type': 'application/json',
      };

  Future<List<StoryFeedUser>> fetchFeed() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/stories/feed'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load stories feed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) return [];

    final users = data['users'];
    if (users is! List) return [];

    return users
        .map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          final user = StoryFeedUser.fromJson(map);
          return StoryFeedUser(
            userId: user.userId,
            name: user.name,
            avatarUrl: absoluteBackendUrl(user.avatarUrl),
            hasStory: user.hasStory,
            hasUnviewed: user.hasUnviewed,
            isMe: user.isMe,
            storyCount: user.storyCount,
            isOnline: user.isOnline,
          );
        })
        .toList();
  }

  Future<List<StoryItem>> fetchMyStories() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/stories/me'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load my stories: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (data is! List) return [];
    return _parseStoryItems(data);
  }

  Future<StoryUserBundle> fetchUserStories(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/stories/user/$userId'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load user stories: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid stories response');
    }

    final bundle = StoryUserBundle.fromJson(data);
    return StoryUserBundle(
      userId: bundle.userId,
      name: bundle.name,
      avatarUrl: absoluteBackendUrl(bundle.avatarUrl),
      stories: bundle.stories
          .map(
            (story) => StoryItem(
              id: story.id,
              mediaUrl: absoluteBackendUrl(story.mediaUrl) ?? story.mediaUrl,
              caption: story.caption,
              createdAt: story.createdAt,
              expiresAt: story.expiresAt,
              isViewed: story.isViewed,
            ),
          )
          .toList(),
    );
  }

  Future<StoryItem> publishStory(File image, {String? caption}) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/stories'),
    );
    request.headers['Authorization'] = token;
    request.files.add(
      await http.MultipartFile.fromPath('media', image.path),
    );
    if (caption != null && caption.trim().isNotEmpty) {
      request.fields['caption'] = caption.trim();
    }

    final streamedResponse = await request.send();
    final body = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode != 201) {
      String message = 'Failed to publish story';
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
      throw Exception('Invalid publish response');
    }
    return _parseStoryItem(data);
  }

  Future<void> markViewed(int storyId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/stories/$storyId/view'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to mark story viewed: ${response.statusCode}');
    }
  }

  Future<void> deleteStory(int storyId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/stories/$storyId'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete story: ${response.statusCode}');
    }
  }

  List<StoryItem> _parseStoryItems(List<dynamic> items) {
    return items
        .map((item) => _parseStoryItem(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  StoryItem _parseStoryItem(Map<String, dynamic> json) {
    final story = StoryItem.fromJson(json);
    return StoryItem(
      id: story.id,
      mediaUrl: absoluteBackendUrl(story.mediaUrl) ?? story.mediaUrl,
      caption: story.caption,
      createdAt: story.createdAt,
      expiresAt: story.expiresAt,
      isViewed: story.isViewed,
    );
  }
}
