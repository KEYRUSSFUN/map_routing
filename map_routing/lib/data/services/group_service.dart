import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:map_routing/core/network/backend_urls.dart';
import 'package:map_routing/data/models/chat.dart';
import 'package:map_routing/core/network/config.dart';

class GroupChatService {
  final String baseUrl;
  final String token;

  GroupChatService({String? baseUrl, required this.token})
      : baseUrl = baseUrl ?? backendBaseUrl;

  Future<GroupChatsResponse> fetchUserChats() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/group_chats'),
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        final chatsRaw = decoded['chats'] as List<dynamic>? ?? const [];
        return GroupChatsResponse(
          chats: chatsRaw
              .whereType<Map<String, dynamic>>()
              .map(Chat.fromJson)
              .toList(),
          unreadInvitationCount:
              (decoded['unreadInvitationCount'] as num?)?.toInt() ?? 0,
        );
      }

      if (decoded is List) {
        return GroupChatsResponse(
          chats: decoded
              .whereType<Map<String, dynamic>>()
              .map(Chat.fromJson)
              .toList(),
          unreadInvitationCount: 0,
        );
      }

      throw Exception('Unexpected group chats response format');
    } else {
      throw Exception('Failed to load group chats');
    }
  }

  Future<void> markGroupInvitationsSeen() async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/group_chats/invitations/mark_seen'),
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to mark group invitations as seen: ${response.statusCode}',
      );
    }
  }

  Future<Chat> createGroupChat(String title, List<String> memberIds) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/group_chats'),
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'title': title,
        'members': memberIds,
      }),
    );

    if (response.statusCode == 201) {
      return Chat.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create group chat: ${response.body}');
    }
  }

  Future<Chat> getOrCreateDirectChat(String friendUserId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/group_chats/direct'),
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
      body: json.encode({'user_id': friendUserId}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        return Chat.fromJson(decoded);
      }
      throw Exception('Unexpected direct chat response format');
    }

    String message = 'Failed to open chat';
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map && decoded['error'] != null) {
        message = decoded['error'].toString();
      }
    } catch (_) {}
    throw Exception(message);
  }

  Future<Map<String, dynamic>> getChatDetails(
    String chatId, {
    bool includeMessages = true,
  }) async {
    final query = includeMessages ? '' : '?include_messages=false';
    final response = await http.get(
      Uri.parse('$baseUrl/api/group_chats/$chatId$query'),
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load chat details');
    }
  }

  Future<List<Map<String, dynamic>>> fetchMessages(
    String chatId, {
    int? afterId,
  }) async {
    final query = afterId != null ? '?after_id=$afterId' : '';
    final response = await http.get(
      Uri.parse('$baseUrl/api/group_chats/$chatId/messages$query'),
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load chat messages: ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    if (decoded is! Map<String, dynamic>) return const [];
    final messages = decoded['messages'];
    if (messages is! List) return const [];

    return messages
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _responseErrorMessage(http.Response response, String fallback) {
    if (response.body.isEmpty) return fallback;
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map) {
        final error = decoded['error']?.toString();
        if (error != null && error.isNotEmpty) return error;
        final details = decoded['details']?.toString();
        if (details != null && details.isNotEmpty) return details;
      }
    } catch (_) {}
    return fallback;
  }

  Future<void> deleteChat(String chatId) async {
    final response = await http
        .delete(
          Uri.parse('$baseUrl/api/group_chats/$chatId'),
          headers: {
            'Authorization': token,
            'Content-Type': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw Exception(
      _responseErrorMessage(response, 'Не удалось удалить группу'),
    );
  }

  Future<void> removeMember(String chatId, String memberId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/group_chats/$chatId/members/$memberId'),
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        _responseErrorMessage(response, 'Не удалось исключить участника'),
      );
    }
  }

  Future<void> addMember(String chatId, String memberId) async {
    final userId = int.tryParse(memberId);
    if (userId == null) {
      throw Exception('Некорректный ID пользователя');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/group_chats/$chatId/add_user'),
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
      body: json.encode({'user_id': userId}),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return;
    }

    try {
      final decoded = json.decode(response.body);
      if (decoded is Map && decoded['error'] != null) {
        throw Exception(decoded['error'].toString());
      }
    } catch (e) {
      if (e is Exception) rethrow;
    }
    throw Exception('Не удалось добавить участника: ${response.body}');
  }

  Future<void> markChatAsRead(String chatId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/group_chats/$chatId/read'),
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to mark chat as read: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> toggleMessageReaction({
    required String chatId,
    required String messageId,
    required String emoji,
  }) async {
    final response = await http.post(
      Uri.parse(
        '$baseUrl/api/group_chats/$chatId/messages/$messageId/reactions',
      ),
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
      body: json.encode({'emoji': emoji}),
    );

    if (response.statusCode != 200) {
      String message = 'Failed to set reaction: ${response.statusCode}';
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map && decoded['error'] != null) {
          message = decoded['error'].toString();
        }
      } catch (_) {}
      throw Exception(message);
    }

    final decoded = json.decode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected reaction response');
    }

    final reactions = decoded['reactions'];
    if (reactions is! List) return const [];

    return reactions
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/group_chats/$chatId/messages/$messageId'),
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      String message = 'Failed to delete message: ${response.statusCode}';
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map && decoded['error'] != null) {
          message = decoded['error'].toString();
        }
      } catch (_) {}
      throw Exception(message);
    }
  }

  Future<void> updateChatTitle(String chatId, String title) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/api/group_chats/$chatId'),
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
      body: json.encode({'title': title}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        _responseErrorMessage(response, 'Не удалось обновить название'),
      );
    }
  }

  Future<String?> uploadChatPhoto(String chatId, File photoFile) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/group_chats/$chatId/photo'),
    );
    request.headers['Authorization'] = token;
    request.files.add(
      await http.MultipartFile.fromPath('photo', photoFile.path),
    );

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      throw Exception(
        _responseErrorMessage(
          http.Response(body, streamed.statusCode),
          'Не удалось загрузить фото',
        ),
      );
    }

    final decoded = json.decode(body);
    if (decoded is Map<String, dynamic>) {
      return absoluteBackendUrl(decoded['photoUrl']?.toString());
    }
    return null;
  }

  Future<void> updateNotificationsMuted(String chatId, bool muted) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/api/group_chats/$chatId/settings'),
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
      body: json.encode({'notifications_muted': muted}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        _responseErrorMessage(response, 'Не удалось сохранить настройки'),
      );
    }
  }
}
