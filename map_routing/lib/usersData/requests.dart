import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RegistrationService {
  final String baseUrl;

  RegistrationService({required this.baseUrl});

  Future<bool> registerUser(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return responseData['success'] as bool;
      } else {
        print('Ошибка регистрации: ${response.statusCode}, ${response.body}');
        return false;
      }
    } catch (e) {
      print('Ошибка соединения: $e');
      return false;
    }
  }

  Future<String?> loginUser(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final token = responseData['token'];
        if (token != null) {
          await _saveToken(token);
          return token;
        }
      }
      return null;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  Future<void> _saveToken(String token) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  Future<void> saveTrackingData({
    required double distance,
    required int steps,
    required double calories,
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl/api/user_statistic');
    final now = DateTime.now();
    final formattedDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token,
      },
      body: jsonEncode({
        'distance': distance,
        'steps': steps,
        'calories': calories,
        'date': formattedDate,
      }),
    );

    if (response.statusCode == 201) {
      print("✅ Статистика успешно отправлена");
    } else {
      print("❌ Ошибка: ${response.statusCode} ${response.body}");
    }
  }
}
