import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:map_routing/UIWidgets/friend.dart';

class FriendService {
  final String baseUrl;
  final String token;

  FriendService({required this.baseUrl, required this.token});

  Future<List<Friend>> fetchFriends() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/friends'),
      headers: {'Authorization': token},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((json) => Friend(
                id: json['id'].toString(),
                avatarUrl:
                    'https://i.pravatar.cc/100?img=${json['id']}', // Генерация аватара по ID
                isOnline: false, // Можно улучшить логику определения статуса
                name: json['name'].toString(),
              ))
          .toList();
    } else {
      throw Exception('Failed to load friends: ${response.statusCode}');
    }
  }

  Future<void> sendFriendRequest(String friendId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/friends/send_request'),
      headers: {'Authorization': token, 'Content-Type': 'application/json'},
      body: jsonEncode({'friend_id': friendId}),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to send friend request: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchFriendRequests() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/friends/requests'),
      headers: {'Authorization': token},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((json) => {
                'id': json['id'].toString(),
                'fromUserId': json['fromUserId'].toString(),
                'fromUserName': json['fromUserName'] as String? ??
                    'Неизвестный пользователь',
              })
          .toList();
    } else {
      throw Exception('Failed to load friend requests: ${response.statusCode}');
    }
  }

  Future<void> acceptFriendRequest(String requestId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/friends/accept_request'),
      headers: {'Authorization': token, 'Content-Type': 'application/json'},
      body: jsonEncode({'friend_id': requestId}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          'Failed to accept friend request: ${response.statusCode}');
    }
  }

  Future<void> rejectFriendRequest(String requestId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/friends/reject_request'),
      headers: {'Authorization': token, 'Content-Type': 'application/json'},
      body: jsonEncode({'friend_id': requestId}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          'Failed to reject friend request: ${response.statusCode}');
    }
  }
}
