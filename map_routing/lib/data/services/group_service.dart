import 'dart:convert';
import 'package:http/http.dart' as http;
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

  Future<Map<String, dynamic>> getChatDetails(String chatId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/group_chats/$chatId'),
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

  Future<void> deleteChat(String chatId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/group_chats/$chatId'),
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete chat: ${response.body}');
    }
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
      throw Exception('Failed to remove member: ${response.body}');
    }
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
}
