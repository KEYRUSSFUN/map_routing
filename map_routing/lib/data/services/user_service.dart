import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:map_routing/core/network/config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  Future<Map<String, dynamic>?> fetchUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) return null;

    final response = await http.get(
      Uri.parse('$backendBaseUrl/api/user_info'),
      headers: {'Authorization': '$token', 'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      print(
          'Error fetching user info: ${response.statusCode} - ${response.body}');
      return null;
    }
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
      headers: {'Authorization': '$token', 'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      print(
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

    print(
      'Error uploading avatar: ${streamedResponse.statusCode} - $body',
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
        'Authorization': '$token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      print(
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
      headers: {'Authorization': '$token'},
    );

    if (response.statusCode == 200) {
      await prefs.remove('jwt_token');
      return json.decode(response.body);
    } else {
      print('Error logging out: ${response.statusCode} - ${response.body}');
      return null;
    }
  }
}
