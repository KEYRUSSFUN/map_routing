import 'dart:convert';
import 'package:http/http.dart' as http;

class UserSearchService {
  final String baseUrl;
  final String token;

  UserSearchService({required this.baseUrl, required this.token});

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/search?name=$query'),
        headers: {'Authorization': token, 'Content-Type': 'application/json'},
      );

      print(
          'Response for "$query": status=${response.statusCode}, body=${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! List) {
          print('Unexpected response format: $decoded');
          return [];
        }
        final List<dynamic> data = decoded;
        return data.map((item) {
          if (item is! Map<String, dynamic> ||
              !item.containsKey('id') ||
              !item.containsKey('name')) {
            print('Invalid user data for "$query": $item');
            return {'id': '0', 'name': 'Unknown'};
          }
          return Map<String, dynamic>.from(item); // Копируем для безопасности
        }).toList();
      } else if (response.statusCode == 500) {
        print('Server error for "$query": ${response.body}');
        return [];
      } else {
        throw Exception(
            'Failed to search users: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Search error for "$query": $e');
      return [];
    }
  }
}
