import 'package:http/http.dart' as http;
import 'dart:convert';

class TokenVerify {
  final String token;
  final String baseUrl;
  TokenVerify({required this.token, required this.baseUrl});

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
        print("Response body: ${response.body}");
        final data = json.decode(response.body);
        return data['valid'] ==
            true; // Замените на формат ответа вашего сервера
      } else {
        print('Ошибка при проверке токена на сервере: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Ошибка сети при проверке токена на сервере: $e');
      return false;
    }
  }
}
