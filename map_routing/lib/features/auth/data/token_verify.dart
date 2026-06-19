import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:map_routing/core/network/config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenVerify {
  final String token;
  final String baseUrl;

  TokenVerify({required this.token, String? baseUrl})
      : baseUrl = baseUrl ?? backendBaseUrl;

  Future<bool> isTokenValidOnServer() async {
    final url = Uri.parse('$baseUrl/token_verify');
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': token,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['valid'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> refreshTokenOnServer() async {
    final url = Uri.parse('$baseUrl/token_refresh');
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': token,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      if (data is! Map<String, dynamic>) return null;
      if (data['valid'] != true) return null;

      final refreshed = data['token']?.toString();
      if (refreshed == null || refreshed.isEmpty) return null;
      return refreshed;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> ensureValidSession({String? baseUrl}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) return false;

    final verifier = TokenVerify(token: token, baseUrl: baseUrl);
    if (await verifier.isTokenValidOnServer()) {
      return true;
    }

    final refreshed = await verifier.refreshTokenOnServer();
    if (refreshed == null) return false;

    await prefs.setString('jwt_token', refreshed);
    return true;
  }
}
