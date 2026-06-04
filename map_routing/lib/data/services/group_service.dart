import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:map_routing/data/models/chat.dart';
import 'package:map_routing/core/network/config.dart';

class GroupChatService {
  final String baseUrl;
  final String token;

  GroupChatService({String? baseUrl, required this.token})
      : baseUrl = baseUrl ?? backendBaseUrl;

  Future<List<Chat>> fetchUserChats() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/group_chats'),
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((chat) => Chat.fromJson(chat)).toList();
    } else {
      throw Exception('Failed to load group chats');
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
}
