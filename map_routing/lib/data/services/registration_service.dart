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
        headers: const {'Content-Type': 'application/json; charset=UTF-8'},
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

      debugPrint(
        'Ошибка регистрации: ${response.statusCode}, ${response.body}',
      );
      return 'Ошибка регистрации. Попробуйте снова.';
    } catch (e) {
      debugPrint('Ошибка соединения: $e');
      return userFacingNetworkError(e) ??
          'Ошибка соединения. Попробуйте снова.';
    }
  }

  Future<({String? token, String? error})> loginUser(
    String email,
    String password,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: const {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 20));

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
        error:
            userFacingNetworkError(e) ?? 'Ошибка соединения. Попробуйте снова.',
      );
    }
  }

  Future<
      ({
        String? message,
        String? resetCode,
        bool emailSent,
        bool accountExists,
        bool suggestRegistration,
        String? error,
      })> requestPasswordReset(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/forgot-password'),
            headers: const {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode({'email': email.trim()}),
          )
          .timeout(const Duration(seconds: 20));

      final responseData = decodeJsonObject(response.body);
      if (responseData == null) {
        return (
          message: null,
          resetCode: null,
          emailSent: false,
          accountExists: true,
          suggestRegistration: false,
          error: userFacingApiError(
            statusCode: response.statusCode,
            body: response.body,
            fallback: 'Не удалось отправить код',
          ),
        );
      }

      final message = responseData['message']?.toString();
      final emailSent = responseData['email_sent'] == true;
      final accountExists = responseData['account_exists'] != false;
      final suggestRegistration =
          response.statusCode == 404 || responseData['account_exists'] == false;

      if (response.statusCode == 200 && responseData['success'] == true) {
        return (
          message: message,
          resetCode: responseData['reset_code']?.toString(),
          emailSent: emailSent,
          accountExists: accountExists,
          suggestRegistration: false,
          error: null,
        );
      }

      return (
        message: message,
        resetCode: null,
        emailSent: false,
        accountExists: accountExists,
        suggestRegistration: suggestRegistration,
        error: suggestRegistration ? null : (message ?? 'Не удалось отправить код'),
      );
    } catch (e) {
      debugPrint('Password reset request error: $e');
      return (
        message: null,
        resetCode: null,
        emailSent: false,
        accountExists: true,
        suggestRegistration: false,
        error:
            userFacingNetworkError(e) ?? 'Ошибка соединения. Попробуйте снова.',
      );
    }
  }

  Future<({String? message, String? error})> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/reset-password'),
            headers: const {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode({
              'email': email.trim(),
              'code': code.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final responseData = decodeJsonObject(response.body);
      if (responseData == null) {
        return (
          message: null,
          error: userFacingApiError(
            statusCode: response.statusCode,
            body: response.body,
            fallback: 'Не удалось изменить пароль',
          ),
        );
      }

      final message = responseData['message']?.toString();
      if (response.statusCode == 200 && responseData['success'] == true) {
        return (message: message, error: null);
      }

      return (message: null, error: message ?? 'Не удалось изменить пароль');
    } catch (e) {
      debugPrint('Password reset error: $e');
      return (
        message: null,
        error:
            userFacingNetworkError(e) ?? 'Ошибка соединения. Попробуйте снова.',
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
      headers: {'Content-Type': 'application/json', 'Authorization': token},
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
