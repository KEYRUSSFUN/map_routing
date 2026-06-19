import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:map_routing/core/network/config.dart';
import 'package:map_routing/data/models/challenge.dart';

class ChallengeService {
  ChallengeService({String? baseUrl, required this.token})
      : baseUrl = baseUrl ?? backendBaseUrl;

  final String baseUrl;
  final String token;

  Map<String, String> get _headers => {
        'Authorization': token,
        'Content-Type': 'application/json',
      };

  Future<List<ChallengeSummary>> fetchChallenges() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/challenges'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Не удалось загрузить челленджи: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (data is! List) return const [];

    return data
        .map((item) => ChallengeSummary.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  Future<void> joinChallenge(int challengeId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/challenges/$challengeId/join'),
      headers: _headers,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      String message =
          'Не удалось присоединиться к челленджу: ${response.statusCode}';
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['error'] != null) {
          message = data['error'].toString();
        }
      } catch (_) {}
      throw Exception(message);
    }
  }

  Future<void> leaveChallenge(int challengeId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/challenges/$challengeId/leave'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      String message =
          'Не удалось выйти из челленджа: ${response.statusCode}';
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['error'] != null) {
          message = data['error'].toString();
        }
      } catch (_) {}
      throw Exception(message);
    }
  }

  Future<ChallengeDetails> fetchChallengeDetails(int challengeId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/challenges/$challengeId'),
      headers: _headers,
    );

    if (response.statusCode == 403) {
      throw ChallengeNotJoinedException();
    }

    if (response.statusCode != 200) {
      String message =
          'Не удалось загрузить челлендж: ${response.statusCode}';
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['error'] != null) {
          message = data['error'].toString();
        }
      } catch (_) {}
      throw Exception(message);
    }

    return ChallengeDetails.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }
}

class ChallengeNotJoinedException implements Exception {}
