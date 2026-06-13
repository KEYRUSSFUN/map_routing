import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:map_routing/core/network/config.dart';

class UserSearchService {
  final String baseUrl;
  final String token;

  UserSearchService({String? baseUrl, required this.token})
      : baseUrl = baseUrl ?? backendBaseUrl;

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final encodedQuery = Uri.encodeQueryComponent(query);
    final response = await http.get(
      Uri.parse('$baseUrl/api/users/search?name=$encodedQuery'),
      headers: {'Authorization': token, 'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) => item['id'] != null && item['name'] != null)
          .toList();
    }

    if (response.statusCode == 500) {
      return [];
    }

    throw Exception(
      'Failed to search users: ${response.statusCode} - ${response.body}',
    );
  }
}
