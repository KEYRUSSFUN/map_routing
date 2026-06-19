import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:map_routing/core/network/config.dart';
import 'package:map_routing/data/models/achievement.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AchievementService {
  static const definitions = <AchievementDefinition>[
    AchievementDefinition(
      id: AchievementId.firstWorkout,
      title: 'Первый шаг',
      description: 'Сохраните первую тренировку',
      icon: Icons.flag_outlined,
    ),
    AchievementDefinition(
      id: AchievementId.earlyBird,
      title: 'Ранняя пташка',
      description: 'Начните тренировку до 7:00',
      icon: Icons.emoji_events_outlined,
    ),
    AchievementDefinition(
      id: AchievementId.speedDemon,
      title: 'Демон скорости',
      description: 'Средняя скорость от 12 км/ч на дистанции от 3 км',
      icon: Icons.speed,
    ),
    AchievementDefinition(
      id: AchievementId.peakForm,
      title: 'Пиковая форма',
      description: 'Наберите 300 м высоты за одну тренировку',
      icon: Icons.landscape,
    ),
    AchievementDefinition(
      id: AchievementId.streak7,
      title: '7 дней подряд',
      description: 'Тренируйтесь 7 дней подряд',
      icon: Icons.local_fire_department,
    ),
    AchievementDefinition(
      id: AchievementId.century,
      title: 'Сотня',
      description: 'Пройдите или проедьте 100 км суммарно',
      icon: Icons.directions_bike,
    ),
    AchievementDefinition(
      id: AchievementId.marathoner,
      title: 'Марафонец',
      description: 'Одна тренировка длиной от 42 км',
      icon: Icons.directions_run,
    ),
    AchievementDefinition(
      id: AchievementId.ninja,
      title: 'Ниндзя',
      description: '5 тренировок с высокой нагрузкой (4+ из 5)',
      icon: Icons.sports_martial_arts,
    ),
    AchievementDefinition(
      id: AchievementId.explorer,
      title: 'Исследователь',
      description: 'Сохраните 10 тренировок',
      icon: Icons.explore_outlined,
    ),
    AchievementDefinition(
      id: AchievementId.photographer,
      title: 'Фотограф',
      description: 'Добавьте фото к тренировке',
      icon: Icons.photo_camera_outlined,
    ),
    AchievementDefinition(
      id: AchievementId.traveler,
      title: 'Путешественник',
      description: '500 км суммарной дистанции',
      icon: Icons.map_outlined,
    ),
    AchievementDefinition(
      id: AchievementId.worldTraveler,
      title: 'Мировой путешественник',
      description: '1000 км суммарной дистанции',
      icon: Icons.public,
    ),
  ];

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<Map<String, DateTime>> _fetchUnlockedFromServer({String? userId}) async {
    final token = await _token();
    if (token == null) return {};

    final url = userId == null
        ? '$backendBaseUrl/api/user_achievements'
        : '$backendBaseUrl/api/user_achievements/$userId';

    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': token},
    );

    if (response.statusCode != 200) {
      throw Exception('Не удалось загрузить достижения');
    }

    final rows = json.decode(response.body) as List<dynamic>;
    final unlocked = <String, DateTime>{};

    for (final row in rows) {
      if (row is! Map<String, dynamic>) continue;
      final achievementId = row['achievement_id'] as String?;
      final unlockedAtRaw = row['unlocked_at'] as String?;
      if (achievementId == null || unlockedAtRaw == null) continue;
      unlocked[achievementId] = DateTime.parse(unlockedAtRaw);
    }

    return unlocked;
  }

  /// Сервер считает достижения по user_statistic и своим routes (не GPX из чата).
  Future<AchievementSyncResult> sync() async {
    final token = await _token();
    if (token == null) {
      throw Exception('Требуется авторизация для сохранения достижений');
    }

    final response = await http.post(
      Uri.parse('$backendBaseUrl/api/user_achievements/sync'),
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
      body: json.encode({}),
    );

    if (response.statusCode != 200) {
      throw Exception('Не удалось синхронизировать достижения');
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    final allRows = body['all'] as List<dynamic>? ?? [];
    final newRows = body['newly_unlocked'] as List<dynamic>? ?? [];

    final unlockedMap = <String, DateTime>{};
    for (final row in allRows) {
      if (row is! Map<String, dynamic>) continue;
      final achievementId = row['achievement_id'] as String?;
      final unlockedAtRaw = row['unlocked_at'] as String?;
      if (achievementId == null || unlockedAtRaw == null) continue;
      unlockedMap[achievementId] = DateTime.parse(unlockedAtRaw);
    }

    final newlyUnlocked = _statusesFromRows(newRows);
    return _buildResult(unlockedMap, newlyUnlocked);
  }

  Future<List<AchievementStatus>> fetchForUser({String? userId}) async {
    final unlockedMap = await _fetchUnlockedFromServer(userId: userId);
    return _buildResult(unlockedMap, const []).all;
  }

  AchievementSyncResult _buildResult(
    Map<String, DateTime> unlockedMap,
    List<AchievementStatus> newlyUnlocked,
  ) {
    final all = definitions
        .map(
          (definition) => AchievementStatus(
            definition: definition,
            unlocked: unlockedMap.containsKey(definition.storageKey),
            unlockedAt: unlockedMap[definition.storageKey],
          ),
        )
        .toList();

    return AchievementSyncResult(all: all, newlyUnlocked: newlyUnlocked);
  }

  List<AchievementStatus> _statusesFromRows(List<dynamic> rows) {
    final byId = {for (final d in definitions) d.storageKey: d};

    return [
      for (final row in rows)
        if (row is Map<String, dynamic>)
          () {
            final achievementId = row['achievement_id'] as String?;
            final unlockedAtRaw = row['unlocked_at'] as String?;
            final definition = achievementId == null ? null : byId[achievementId];
            if (definition == null || unlockedAtRaw == null) return null;
            return AchievementStatus(
              definition: definition,
              unlocked: true,
              unlockedAt: DateTime.parse(unlockedAtRaw),
            );
          }(),
    ].whereType<AchievementStatus>().toList();
  }

  List<AchievementStatus> recentUnlocked(
    List<AchievementStatus> all, {
    int limit = 4,
  }) {
    final recent = all
        .where((a) => a.unlocked && a.unlockedAt != null)
        .toList()
      ..sort((a, b) => b.unlockedAt!.compareTo(a.unlockedAt!));
    return recent.take(limit).toList();
  }
}
