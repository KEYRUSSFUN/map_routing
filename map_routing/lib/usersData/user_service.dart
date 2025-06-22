import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UserService {
  Future<Map<String, dynamic>?> fetchUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) return null;

    final response = await http.get(
      Uri.parse('http://192.168.1.105:5000/api/user_info'),
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
        ? Uri.parse('http://192.168.1.105:5000/api/user_info')
        : Uri.parse('http://192.168.1.105:5000/api/user_info/$userId');

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

  Future<Map<String, dynamic>?> updateUserInfo(
      Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) return null;

    final response = await http.post(
      Uri.parse('http://192.168.1.105:5000/api/user_info'),
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
      Uri.parse('http://192.168.1.105:5000/api/logout'),
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
