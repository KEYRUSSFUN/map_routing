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

class StatisticsService {
  List<dynamic>? _cachedStats;
  DateTime? _lastFetchTime;
  final Duration cacheDuration = Duration(minutes: 1);

  Future<List<dynamic>> _fetchStats({String? userId}) async {
    final now = DateTime.now();

    if (userId == null &&
        _cachedStats != null &&
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!) < cacheDuration) {
      return _cachedStats!;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final url = userId == null
        ? '$backendBaseUrl/api/user_statistic'
        : '$backendBaseUrl/api/user_statistic/$userId';

    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': token ?? ''},
    );

    if (response.statusCode == 200) {
      final stats = json.decode(response.body) as List<dynamic>;
      if (userId == null) {
        _cachedStats = stats;
        _lastFetchTime = now;
      }
      return stats;
    } else {
      throw Exception('Не удалось загрузить данные активности');
    }
  }

  Future<List<Map<String, dynamic>>> fetchWeeklyStats({String? userId}) async {
    final stats = await _fetchStats(userId: userId);

    final now = DateTime.now();
    final last7Days = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
    });

    Map<String, Map<String, dynamic>> dayStats = {
      for (var day in last7Days)
        day: {'distance': 0.0, 'steps': 0, 'calories': 0.0}
    };

    for (var stat in stats) {
      final date = stat['date'];
      if (dayStats.containsKey(date)) {
        dayStats[date]!['distance'] =
            (stat['distance'] as num?)?.toDouble() ?? 0.0;
        dayStats[date]!['steps'] = (stat['steps'] as int?) ?? 0;
        dayStats[date]!['calories'] =
            (stat['calories'] as num?)?.toDouble() ?? 0.0;
      }
    }

    return last7Days.map((d) => dayStats[d]!).toList();
  }

  Future<WeeklySummary> fetchAllWeeklyStats({String? userId}) async {
    final weeklyStats = await fetchWeeklyStats(userId: userId);

    final distanceMeters = weeklyStats.fold<double>(
        0.0, (sum, day) => sum + (day['distance'] as double));
    final steps =
        weeklyStats.fold<int>(0, (sum, day) => sum + (day['steps'] as int));
    final calories = weeklyStats.fold<double>(
        0.0, (sum, day) => sum + (day['calories'] as double));

    return WeeklySummary(
      distanceKm: distanceMeters / 1000.0,
      steps: steps,
      calories: calories,
    );
  }

  /// Процент изменения дистанции: последние 7 дней vs предыдущие 7 дней.
  Future<double?> fetchWeekOverWeekChangePercent({String? userId}) async {
    final stats = await _fetchStats(userId: userId);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    var currentWeekM = 0.0;
    var previousWeekM = 0.0;

    for (final stat in stats) {
      final dateStr = stat['date'] as String?;
      if (dateStr == null) continue;
      final parsed = DateTime.tryParse(dateStr);
      if (parsed == null) continue;

      final day = DateTime(parsed.year, parsed.month, parsed.day);
      final daysAgo = today.difference(day).inDays;
      final distance = (stat['distance'] as num?)?.toDouble() ?? 0.0;

      if (daysAgo >= 0 && daysAgo < 7) {
        currentWeekM += distance;
      } else if (daysAgo >= 7 && daysAgo < 14) {
        previousWeekM += distance;
      }
    }

    if (previousWeekM <= 0) {
      return currentWeekM > 0 ? 100.0 : null;
    }
    return ((currentWeekM - previousWeekM) / previousWeekM) * 100;
  }

  static String formatWeekChangeLabel(double? percent) {
    if (percent == null) return 'Нет данных за прошлую неделю';
    final rounded = percent.round();
    if (rounded == 0) return 'Без изменений к прошлой неделе';
    final sign = rounded > 0 ? '+' : '';
    return '$sign$rounded% к прошлой неделе';
  }
}
