import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:map_routing/core/network/config.dart';
import 'package:map_routing/core/network/network_errors.dart';
import 'package:map_routing/data/services/statistics_service.dart';
import 'package:map_routing/data/services/socket_chat_service.dart';
import 'package:map_routing/data/services/user_workout_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RegistrationService {
  final String baseUrl;

  RegistrationService({String? baseUrl}) : baseUrl = baseUrl ?? backendBaseUrl;

  Future<String?> registerUser(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: const {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'email': email.trim(),
          'password': password,
        }),
      );

      final responseData = jsonDecode(response.body);
      if (responseData is Map<String, dynamic>) {
        final message = responseData['message']?.toString();
        if (response.statusCode == 201 && responseData['success'] == true) {
          return null;
        }
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }

      debugPrint('Ошибка регистрации: ${response.statusCode}, ${response.body}');
      return 'Ошибка регистрации. Попробуйте снова.';
    } catch (e) {
      debugPrint('Ошибка соединения: $e');
      return userFacingNetworkError(e) ?? 'Ошибка соединения. Попробуйте снова.';
    }
  }

  Future<({String? token, String? error})> loginUser(
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: const {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        if (responseData is Map<String, dynamic>) {
          final token = responseData['token']?.toString();
          if (token != null && token.isNotEmpty) {
            await _saveToken(token);
            return (token: token, error: null);
          }

          final message = responseData['message']?.toString();
          if (message != null && message.isNotEmpty) {
            return (token: null, error: message);
          }
        }
      }

      return (token: null, error: 'Ошибка входа. Неверный email или пароль');
    } catch (e) {
      debugPrint('Login error: $e');
      return (
        token: null,
        error: userFacingNetworkError(e) ?? 'Ошибка соединения. Попробуйте снова.',
      );
    }
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    await UserWorkoutStorage.instance.syncUserIdFromToken(token);
    StatisticsService.clearGlobalCache();
    unawaited(SocketChatService.instance.reconnectForAccountSwitch());
  }

  Future<void> saveToken(String token) => _saveToken(token);

  Future<void> saveTrackingData({
    required double distance,
    required int steps,
    required double calories,
    required String token,
    DateTime? activityDate,
  }) async {
    final url = Uri.parse('$baseUrl/api/user_statistic');
    final date = activityDate ?? DateTime.now();
    final formattedDate =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

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
      debugPrint('Статистика успешно отправлена');
      return;
    }
    throw Exception(
      'Не удалось сохранить статистику: ${response.statusCode} ${response.body}',
    );
  }
}
