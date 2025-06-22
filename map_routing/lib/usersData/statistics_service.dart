import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class WeeklySummary {
  final double distanceKm;
  final int steps; // Changed from activeTimeSec to steps
  final double calories;

  WeeklySummary({
    required this.distanceKm,
    required this.steps, // Changed from activeTimeSec to steps
    required this.calories,
  });
}

class StatisticsService {
  List<dynamic>? _cachedStats;
  DateTime? _lastFetchTime;
  final Duration cacheDuration = Duration(minutes: 1);

  Future<List<dynamic>> _fetchStats() async {
    final now = DateTime.now();

    if (_cachedStats != null &&
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!) < cacheDuration) {
      return _cachedStats!;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.get(
      Uri.parse('http://192.168.1.81:5000/api/user_statistic'),
      headers: {'Authorization': token ?? ''},
    );

    if (response.statusCode == 200) {
      _cachedStats = json.decode(response.body);
      _lastFetchTime = now;
      return _cachedStats!;
    } else {
      throw Exception('Не удалось загрузить данные активности');
    }
  }

  Future<List<Map<String, dynamic>>> fetchWeeklyStats() async {
    final stats = await _fetchStats();

    final now = DateTime.now();
    final last7Days = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
    });

    // Создаем карту с ключом - дата, значениями по метрикам
    Map<String, Map<String, dynamic>> dayStats = {
      for (var day in last7Days)
        day: {
          'distance': 0.0,
          'steps': 0,
          'calories': 0.0
        } // Changed from active_time to steps
    };

    for (var stat in stats) {
      final date = stat['date'];
      if (dayStats.containsKey(date)) {
        dayStats[date]!['distance'] =
            (stat['distance'] as num?)?.toDouble() ?? 0.0;
        dayStats[date]!['steps'] =
            (stat['steps'] as int?) ?? 0; // Changed from active_time to steps
        dayStats[date]!['calories'] =
            (stat['calories'] as num?)?.toDouble() ?? 0.0;
      }
    }

    return last7Days.map((d) => dayStats[d]!).toList();
  }

  Future<WeeklySummary> fetchAllWeeklyStats() async {
    final weeklyStats = await fetchWeeklyStats();

    final distanceMeters = weeklyStats.fold<double>(
        0.0, (sum, day) => sum + (day['distance'] as double));
    final steps = weeklyStats.fold<int>(
        0,
        (sum, day) =>
            sum + (day['steps'] as int)); // Changed from active_time to steps
    final calories = weeklyStats.fold<double>(
        0.0, (sum, day) => sum + (day['calories'] as double));

    return WeeklySummary(
      distanceKm: distanceMeters / 1000.0,
      steps: steps, // Changed from activeTimeSec to steps
      calories: calories,
    );
  }
}
