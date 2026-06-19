import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:map_routing/core/network/config.dart';

class WeeklySummary {
  final double distanceKm;
  final int steps;
  final double calories;

  WeeklySummary({
    required this.distanceKm,
    required this.steps,
    required this.calories,
  });
}

class ProfileStatisticsSnapshot {
  const ProfileStatisticsSnapshot({
    required this.totals,
    required this.week,
    required this.dailyDistanceMeters,
    required this.weekOverWeekChangePercent,
  });

  final WeeklySummary totals;
  final WeeklySummary week;
  final List<double> dailyDistanceMeters;
  final double? weekOverWeekChangePercent;

  static ProfileStatisticsSnapshot fromStats(List<dynamic> stats) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last7Days = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return StatisticsService._formatDateKey(day);
    });

    final dayStats = <String, Map<String, dynamic>>{
      for (final day in last7Days)
        day: {'distance': 0.0, 'steps': 0, 'calories': 0.0},
    };

    var totalDistanceM = 0.0;
    var totalSteps = 0;
    var totalCalories = 0.0;
    var currentWeekM = 0.0;
    var previousWeekM = 0.0;

    for (final raw in stats) {
      final stat = StatisticsService._asMap(raw);
      final date = StatisticsService._dateKey(stat['date']);
      if (date == null) continue;

      final distance = (stat['distance'] as num?)?.toDouble() ?? 0.0;
      final steps = (stat['steps'] as num?)?.toInt() ?? 0;
      final calories = (stat['calories'] as num?)?.toDouble() ?? 0.0;

      totalDistanceM += distance;
      totalSteps += steps;
      totalCalories += calories;

      final bucket = dayStats[date];
      if (bucket != null) {
        bucket['distance'] = (bucket['distance'] as num).toDouble() + distance;
        bucket['steps'] = (bucket['steps'] as num).toInt() + steps;
        bucket['calories'] = (bucket['calories'] as num).toDouble() + calories;
      }

      final parsed = DateTime.tryParse(date);
      if (parsed != null) {
        final day = DateTime(parsed.year, parsed.month, parsed.day);
        final daysAgo = today.difference(day).inDays;
        if (daysAgo >= 0 && daysAgo < 7) {
          currentWeekM += distance;
        } else if (daysAgo >= 7 && daysAgo < 14) {
          previousWeekM += distance;
        }
      }
    }

    final weekDayStats =
        last7Days.map((day) => dayStats[day]!).toList(growable: false);
    final weekDistanceM = weekDayStats.fold<double>(
      0.0,
      (sum, day) => sum + ((day['distance'] as num?)?.toDouble() ?? 0.0),
    );
    final weekSteps = weekDayStats.fold<int>(
      0,
      (sum, day) => sum + ((day['steps'] as num?)?.toInt() ?? 0),
    );
    final weekCalories = weekDayStats.fold<double>(
      0.0,
      (sum, day) => sum + ((day['calories'] as num?)?.toDouble() ?? 0.0),
    );

    final dailyDistanceMeters = weekDayStats
        .map((day) => (day['distance'] as num?)?.toDouble() ?? 0.0)
        .toList(growable: false);

    double? weekOverWeekChangePercent;
    if (previousWeekM <= 0) {
      weekOverWeekChangePercent = currentWeekM > 0 ? 100.0 : null;
    } else {
      weekOverWeekChangePercent =
          ((currentWeekM - previousWeekM) / previousWeekM) * 100;
    }

    return ProfileStatisticsSnapshot(
      totals: WeeklySummary(
        distanceKm: totalDistanceM / 1000.0,
        steps: totalSteps,
        calories: totalCalories,
      ),
      week: WeeklySummary(
        distanceKm: weekDistanceM / 1000.0,
        steps: weekSteps,
        calories: weekCalories,
      ),
      dailyDistanceMeters: dailyDistanceMeters,
      weekOverWeekChangePercent: weekOverWeekChangePercent,
    );
  }
}

class StatisticsService {
  static List<dynamic>? _cachedStats;
  static DateTime? _lastFetchTime;
  static String? _cachedForUserId;
  final Duration cacheDuration = const Duration(minutes: 1);

  void clearCache() {
    _cachedStats = null;
    _lastFetchTime = null;
    _cachedForUserId = null;
  }

  static void clearGlobalCache() {
    _cachedStats = null;
    _lastFetchTime = null;
    _cachedForUserId = null;
  }

  static String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String? _dateKey(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    if (text.length >= 10) {
      return text.substring(0, 10);
    }
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;
    return _formatDateKey(parsed.toLocal());
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  Future<List<dynamic>> _fetchStats({String? userId}) async {
    final now = DateTime.now();
    final cacheKey = userId ?? 'self';

    if (userId == null &&
        _cachedStats != null &&
        _cachedForUserId == cacheKey &&
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!) < cacheDuration) {
      return _cachedStats!;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) {
      throw Exception('Требуется авторизация');
    }

    final url = userId == null
        ? '$backendBaseUrl/api/user_statistic'
        : '$backendBaseUrl/api/user_statistic/$userId';

    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': token, 'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded is! List) {
        throw Exception('Неверный формат ответа сервера');
      }
      if (userId == null) {
        _cachedStats = decoded;
        _cachedForUserId = cacheKey;
        _lastFetchTime = now;
      }
      return decoded;
    }

    throw Exception(
      'Не удалось загрузить данные активности (${response.statusCode})',
    );
  }

  Future<ProfileStatisticsSnapshot> fetchProfileSnapshot({String? userId}) async {
    final stats = await _fetchStats(userId: userId);
    return ProfileStatisticsSnapshot.fromStats(stats);
  }

  Future<List<Map<String, dynamic>>> fetchWeeklyStats({String? userId}) async {
    final snapshot = await fetchProfileSnapshot(userId: userId);
    return snapshot.dailyDistanceMeters
        .map(
          (distance) => {
            'distance': distance,
            'steps': 0,
            'calories': 0.0,
          },
        )
        .toList(growable: false);
  }

  Future<WeeklySummary> fetchAllWeeklyStats({String? userId}) async {
    final snapshot = await fetchProfileSnapshot(userId: userId);
    return snapshot.week;
  }

  /// Сумма всей статистики пользователя с сервера (для шапки профиля).
  Future<WeeklySummary> fetchTotalsStats({String? userId}) async {
    final snapshot = await fetchProfileSnapshot(userId: userId);
    return snapshot.totals;
  }

  /// Процент изменения дистанции: последние 7 дней vs предыдущие 7 дней.
  Future<double?> fetchWeekOverWeekChangePercent({String? userId}) async {
    final snapshot = await fetchProfileSnapshot(userId: userId);
    return snapshot.weekOverWeekChangePercent;
  }

  Future<List<Map<String, dynamic>>> fetchAllDailyStats({String? userId}) async {
    final stats = await _fetchStats(userId: userId);
    return [
      for (final raw in stats)
        if (_dateKey(_asMap(raw)['date']) case final date?)
          {
            'date': date,
            'distance': (_asMap(raw)['distance'] as num?)?.toDouble() ?? 0.0,
          },
    ];
  }

  static String formatWeekChangeLabel(double? percent) {
    if (percent == null) return 'Нет данных за прошлую неделю';
    final rounded = percent.round();
    if (rounded == 0) return 'Без изменений к прошлой неделе';
    final sign = rounded > 0 ? '+' : '';
    return '$sign$rounded% к прошлой неделе';
  }
}
