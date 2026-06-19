import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:map_routing/core/config/google_auth_config.dart';
import 'package:map_routing/core/network/config.dart';
import 'package:map_routing/core/network/network_errors.dart';
import 'package:map_routing/data/services/registration_service.dart';

class GoogleAuthResult {
  const GoogleAuthResult({
    required this.token,
    required this.isNewUser,
    required this.name,
    required this.email,
  });

  final String token;
  final bool isNewUser;
  final String name;
  final String email;
}

class GoogleAuthService {
  GoogleAuthService({
    RegistrationService? registrationService,
    GoogleSignIn? googleSignIn,
  })  : _registrationService = registrationService ?? RegistrationService(),
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: const ['email', 'profile'],
              serverClientId:
                  googleWebClientId.isEmpty ? null : googleWebClientId,
            );

  final RegistrationService _registrationService;
  final GoogleSignIn _googleSignIn;

  bool get isConfigured => googleWebClientId.isNotEmpty;

  Future<GoogleAuthResult?> signIn() async {
    if (!isConfigured) {
      throw Exception(
        'Google OAuth не настроен. Укажите GOOGLE_WEB_CLIENT_ID.',
      );
    }

    // Сбрасываем кэш Google, иначе SDK сразу берёт последний аккаунт
    // без окна выбора.
    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    GoogleSignInAccount? account;
    try {
      account = await _googleSignIn.signIn();
    } on PlatformException catch (e) {
      throw Exception(_mapPlatformError(e));
    }

    if (account == null) {
      return null;
    }

    GoogleSignInAuthentication auth;
    try {
      auth = await account.authentication;
    } on PlatformException catch (e) {
      throw Exception(_mapPlatformError(e));
    }
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Не удалось получить Google id_token');
    }

    late final http.Response response;
    try {
      response = await http.post(
        Uri.parse('$backendBaseUrl/auth/google'),
        headers: const {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'id_token': idToken}),
      ).timeout(const Duration(seconds: 20));
    } catch (e) {
      throw Exception(
        userFacingNetworkError(e) ?? 'Ошибка соединения с сервером',
      );
    }

    if (response.statusCode != 201) {
      String message = 'Ошибка входа через Google: ${response.statusCode}';
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['message'] != null) {
          message = data['message'].toString();
        }
      } catch (_) {}
      throw Exception(message);
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic> || data['success'] != true) {
      throw Exception('Не удалось войти через Google');
    }

    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      throw Exception('Сервер не вернул токен');
    }

    await _registrationService.saveToken(token);

    return GoogleAuthResult(
      token: token,
      isNewUser: data['is_new_user'] == true,
      name: data['name']?.toString() ?? account.displayName ?? '',
      email: data['email']?.toString() ?? account.email,
    );
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  String _mapPlatformError(PlatformException error) {
    final details = error.details?.toString() ?? '';
    final message = error.message ?? '';

    if (error.code == 'sign_in_failed') {
      if (details.contains('10') || message.contains('10')) {
        return 'Google Sign-In: ошибка конфигурации (код 10). '
            'В Google Cloud Console создайте OAuth client типа Android '
            'для package com.yandex.map_routing и добавьте SHA-1: '
            '8A:4F:AA:C8:47:5F:F3:CD:E8:C9:00:6B:F3:A2:EC:B2:AB:CE:17:9E';
      }
      return 'Не удалось войти через Google ($message $details). '
          'Проверьте OAuth clients (Android + Web) и SHA-1 в Google Cloud.';
    }

    return 'Google Sign-In: ${error.code} — $message $details'.trim();
  }
}
