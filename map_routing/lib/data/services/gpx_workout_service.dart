import 'dart:io';
import 'dart:math' as math;

import 'package:map_routing/data/activity_calculator.dart';
import 'package:map_routing/data/models/track_point.dart';
import 'package:map_routing/data/models/workout_metadata.dart';
import 'package:map_routing/data/models/workout_session_data.dart';
import 'package:map_routing/data/models/workout_summary.dart';
import 'package:map_routing/data/services/route_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

class GpxWorkoutService {
  final RouteService _routeService = RouteService();

  Future<List<WorkoutSummary>> loadWorkouts({double? userWeightKg}) async {
    final workouts = <WorkoutSummary>[];
    final seenKeys = <String>{};

    final directory = await getExternalStorageDirectory();
    if (directory != null) {
      final dir = Directory(directory.path);
      if (dir.existsSync()) {
        final files = dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.gpx'))
            .toList();

        for (final file in files) {
          try {
            final summary = await parseWorkoutFile(
              file.path,
              userWeightKg: userWeightKg,
            );
            if (summary != null && summary.points.length >= 2) {
              _addWorkout(workouts, seenKeys, summary);
            }
          } catch (_) {}
        }
      }
    }

    try {
      final backendRoutes = await _routeService.fetchUserRoutes();
      for (final route in backendRoutes) {
        try {
          final summary = parseBackendRoute(route, userWeightKg: userWeightKg);
          if (summary != null && summary.points.length >= 2) {
            _addWorkout(workouts, seenKeys, summary);
          }
        } catch (_) {}
      }
    } catch (_) {
      // Бэкенд недоступен — показываем локальные маршруты.
    }

    workouts.sort((a, b) {
      final aDate = a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return workouts;
  }

  void _addWorkout(
    List<WorkoutSummary> workouts,
    Set<String> seenKeys,
    WorkoutSummary summary,
  ) {
    final key = _dedupeKey(summary);
    if (seenKeys.contains(key)) {
      final index = workouts.indexWhere((w) => _dedupeKey(w) == key);
      if (index >= 0 && _preferWorkout(summary, workouts[index])) {
        workouts[index] = summary;
      }
      return;
    }
    seenKeys.add(key);
    workouts.add(summary);
  }

  bool _preferWorkout(WorkoutSummary candidate, WorkoutSummary existing) {
    if (candidate.filePath.isNotEmpty && existing.filePath.isEmpty) {
      return true;
    }
    if (candidate.activityType != null && existing.activityType == null) {
      return true;
    }
    if (candidate.tags.isNotEmpty && existing.tags.isEmpty) return true;
    if ((candidate.description?.isNotEmpty ?? false) &&
        (existing.description?.isEmpty ?? true)) {
      return true;
    }
    return false;
  }

  WorkoutSummary buildFromSession({
    required WorkoutSessionData session,
    required WorkoutMetadata metadata,
    required String gpxPath,
  }) {
    final duration = session.duration;
    int? cadenceSpm;
    if (duration.inMinutes > 0) {
      final steps = (session.distanceMeters / 0.75).round();
      cadenceSpm = (steps / duration.inMinutes).round();
    }

    return WorkoutSummary(
      id: gpxPath,
      title: metadata.title,
      filePath: gpxPath,
      startedAt: session.startedAt,
      distanceMeters: session.distanceMeters,
      duration: session.duration,
      avgSpeedKmh: session.avgSpeedKmh,
      elevationGainM: session.elevationGainM,
      calories: session.calories.round(),
      avgHeartRate: null,
      cadenceSpm: cadenceSpm,
      points: session.points,
      chartPoints: _buildChartPoints(session.points),
      activityType: metadata.activityType,
      description:
          metadata.description.isEmpty ? null : metadata.description,
      tags: metadata.tags,
      photoPath: metadata.photoPath,
      effortLevel: metadata.effortLevel,
      notes: metadata.notes.isEmpty ? null : metadata.notes,
      privacy: metadata.privacy,
    );
  }

  String _dedupeKey(WorkoutSummary w) {
    final date = w.startedAt;
    final day = date != null
        ? '${date.year}-${date.month}-${date.day}'
        : 'unknown';
    final dist = (w.distanceMeters / 50).round();
    return '$day-$dist';
  }

  WorkoutSummary? parseBackendRoute(
    BackendRoute route, {
    double? userWeightKg,
  }) {
    final points = _parseGeoJsonPoints(route.path, startedAt: route.creationDate);
    if (points.length < 2) return null;

    return _buildSummary(
      id: 'backend_route_${route.id}',
      title: _titleFromDate(route.creationDate),
      filePath: '',
      startedAt: route.creationDate,
      points: points,
      userWeightKg: userWeightKg,
    );
  }

  Future<WorkoutSummary?> parseWorkoutFile(
    String filePath, {
    double? userWeightKg,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final xmlString = await file.readAsString();
    final doc = XmlDocument.parse(xmlString);
    final points = _parseTrackPoints(doc);
    if (points.length < 2) return null;

    final startedAt = _parseStartTime(doc, filePath);
    return await _enrichWithMetadata(
      _buildSummary(
        id: filePath,
        title: _titleFromPath(filePath, startedAt),
        filePath: filePath,
        startedAt: startedAt,
        points: points,
        userWeightKg: userWeightKg,
      ),
      filePath,
    );
  }

  WorkoutSummary _buildSummary({
    required String id,
    required String title,
    required String filePath,
    required DateTime? startedAt,
    required List<TrackPoint> points,
    double? userWeightKg,
  }) {
    final distanceMeters = _totalDistanceMeters(points);
    var duration = _durationFromPoints(points);
    if (duration == null && distanceMeters > 0) {
      final seconds = (distanceMeters / (10 / 3.6)).round();
      if (seconds > 0) duration = Duration(seconds: seconds);
    }

    final elevationGainM = _elevationGain(points);
    final avgSpeedKmh = duration != null && duration.inSeconds > 0
        ? (distanceMeters / 1000) / (duration.inSeconds / 3600)
        : null;

    int? calories;
    if (userWeightKg != null && distanceMeters > 0) {
      final calculator = ActivityCalculator(weightKg: userWeightKg);
      calories = calculator
          .calculateRunningCalories(distanceMeters: distanceMeters)
          .round();
    }

    int? cadenceSpm;
    if (duration != null && duration.inMinutes > 0) {
      final steps = (distanceMeters / 0.75).round();
      cadenceSpm = (steps / duration.inMinutes).round();
    }

    return WorkoutSummary(
      id: id,
      title: title,
      filePath: filePath,
      startedAt: startedAt,
      distanceMeters: distanceMeters,
      duration: duration,
      avgSpeedKmh: avgSpeedKmh,
      elevationGainM: elevationGainM,
      calories: calories,
      avgHeartRate: null,
      cadenceSpm: cadenceSpm,
      points: points,
      chartPoints: _buildChartPoints(points),
      activityType: null,
      description: null,
      tags: const [],
      photoPath: null,
      effortLevel: null,
      notes: null,
      privacy: null,
    );
  }

  Future<WorkoutSummary?> _enrichWithMetadata(
    WorkoutSummary summary,
    String filePath,
  ) async {
    if (filePath.isEmpty) return summary;
    final metadata = await WorkoutMetadata.loadFromGpxPath(filePath);
    if (metadata == null) return summary;

    final startedAt = metadata.startedAtIso != null
        ? DateTime.tryParse(metadata.startedAtIso!)?.toLocal()
        : summary.startedAt;

    return WorkoutSummary(
      id: summary.id,
      title: metadata.title,
      filePath: summary.filePath,
      startedAt: startedAt ?? summary.startedAt,
      distanceMeters: metadata.distanceMeters ?? summary.distanceMeters,
      duration: metadata.durationSeconds != null
          ? Duration(seconds: metadata.durationSeconds!)
          : summary.duration,
      avgSpeedKmh: metadata.avgSpeedKmh ?? summary.avgSpeedKmh,
      elevationGainM: metadata.elevationGainM ?? summary.elevationGainM,
      calories: metadata.calories ?? summary.calories,
      avgHeartRate: summary.avgHeartRate,
      cadenceSpm: summary.cadenceSpm,
      points: summary.points,
      chartPoints: summary.chartPoints,
      activityType: metadata.activityType,
      description:
          metadata.description.isEmpty ? null : metadata.description,
      tags: metadata.tags,
      photoPath: metadata.photoPath,
      effortLevel: metadata.effortLevel,
      notes: metadata.notes.isEmpty ? null : metadata.notes,
      privacy: metadata.privacy,
    );
  }

  List<TrackPoint> _parseGeoJsonPoints(
    Map<String, dynamic> geoJson, {
    DateTime? startedAt,
  }) {
    final coords = geoJson['coordinates'];
    if (coords is! List || coords.isEmpty) return [];

    final rawPoints = <({double lat, double lon})>[];
    for (final item in coords) {
      if (item is! List || item.length < 2) continue;
      final lon = (item[0] as num).toDouble();
      final lat = (item[1] as num).toDouble();
      rawPoints.add((lat: lat, lon: lon));
    }

    if (rawPoints.length < 2) return [];

    final totalMs = startedAt != null ? _estimateDurationMs(rawPoints) : 0;
    return List.generate(rawPoints.length, (i) {
      DateTime? time;
      if (startedAt != null && rawPoints.length > 1 && totalMs > 0) {
        final fraction = i / (rawPoints.length - 1);
        time = startedAt.add(Duration(milliseconds: (totalMs * fraction).round()));
      }
      return TrackPoint(
        latitude: rawPoints[i].lat,
        longitude: rawPoints[i].lon,
        time: time,
      );
    });
  }

  int _estimateDurationMs(List<({double lat, double lon})> rawPoints) {
    var distance = 0.0;
    for (var i = 1; i < rawPoints.length; i++) {
      distance += _haversineMeters(
        rawPoints[i - 1].lat,
        rawPoints[i - 1].lon,
        rawPoints[i].lat,
        rawPoints[i].lon,
      );
    }
    if (distance <= 0) return 0;
    const avgSpeedMs = 10 / 3.6;
    return (distance / avgSpeedMs * 1000).round();
  }

  String _titleFromDate(DateTime? date) {
    if (date == null) return 'Тренировка';
    final hour = date.hour;
    if (hour >= 5 && hour < 12) return 'Утренняя тренировка';
    if (hour >= 12 && hour < 17) return 'Дневная тренировка';
    if (hour >= 17 && hour < 22) return 'Вечерняя тренировка';
    return 'Ночная тренировка';
  }

  List<TrackPoint> _parseTrackPoints(XmlDocument doc) {
    final result = <TrackPoint>[];
    for (final element in doc.findAllElements('trkpt')) {
      final lat = double.tryParse(element.getAttribute('lat') ?? '');
      final lon = double.tryParse(element.getAttribute('lon') ?? '');
      if (lat == null || lon == null) continue;

      final eleText = element.getElement('ele')?.innerText;
      final timeText = element.getElement('time')?.innerText;

      result.add(
        TrackPoint(
          latitude: lat,
          longitude: lon,
          elevation: eleText != null ? double.tryParse(eleText) : null,
          time: timeText != null && timeText.isNotEmpty
              ? DateTime.tryParse(timeText)?.toLocal()
              : null,
        ),
      );
    }
    return result;
  }

  DateTime? _parseStartTime(XmlDocument doc, String filePath) {
    for (final metadata in doc.findAllElements('metadata')) {
      for (final timeEl in metadata.findElements('time')) {
        final text = timeEl.innerText.trim();
        if (text.isEmpty) continue;
        final parsed = DateTime.tryParse(text);
        if (parsed != null) return parsed.toLocal();
      }
    }

    final name = p.basenameWithoutExtension(filePath);
    final match = RegExp(r'(\d{13})').firstMatch(name);
    if (match != null) {
      final ms = int.tryParse(match.group(1)!);
      if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    }

    final stat = File(filePath).statSync();
    return stat.modified.toLocal();
  }

  String _titleFromPath(String filePath, DateTime? startedAt) {
    final base = p.basenameWithoutExtension(filePath);
    if (base.startsWith('tracked_route_')) {
      if (startedAt != null) {
        final hour = startedAt.hour;
        if (hour >= 5 && hour < 12) return 'Утренняя тренировка';
        if (hour >= 12 && hour < 17) return 'Дневная тренировка';
        if (hour >= 17 && hour < 22) return 'Вечерняя тренировка';
        return 'Ночная тренировка';
      }
      return 'Тренировка';
    }
    if (base.startsWith('saved_route_')) return 'Сохранённый маршрут';
    return base.replaceAll('_', ' ');
  }

  double _totalDistanceMeters(List<TrackPoint> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += _haversineMeters(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    return total;
  }

  Duration? _durationFromPoints(List<TrackPoint> points) {
    final times = points.map((p) => p.time).whereType<DateTime>().toList();
    if (times.length < 2) return null;
    times.sort();
    final diff = times.last.difference(times.first);
    return diff.inSeconds > 0 ? diff : null;
  }

  double _elevationGain(List<TrackPoint> points) {
    var gain = 0.0;
    double? prev;
    for (final point in points) {
      final ele = point.elevation;
      if (ele == null) continue;
      if (prev != null && ele > prev) {
        gain += ele - prev;
      }
      prev = ele;
    }
    return gain;
  }

  List<WorkoutChartPoint> _buildChartPoints(List<TrackPoint> points) {
    const segments = 8;
    if (points.length < segments + 1) {
      return List.generate(points.length, (index) {
        final ele = points[index].elevation ?? 0;
        return WorkoutChartPoint(
          index: index + 1,
          paceMinPerKm: 6,
          elevationM: ele,
          speedKmh: 10,
        );
      });
    }

    final chunkSize = (points.length / segments).ceil();
    final chart = <WorkoutChartPoint>[];

    for (var i = 0; i < segments; i++) {
      final start = i * chunkSize;
      final end = math.min((i + 1) * chunkSize, points.length);
      if (start >= end - 1) continue;

      final slice = points.sublist(start, end);
      final distance = _totalDistanceMeters(slice);
      final duration = _durationFromPoints(slice);
      final pace = distance > 0 && duration != null && duration.inSeconds > 0
          ? (duration.inSeconds / 60) / (distance / 1000)
          : 6.0;
      final speedKmh = distance > 0 && duration != null && duration.inSeconds > 0
          ? (distance / 1000) / (duration.inSeconds / 3600)
          : 10.0;

      final elevations = slice
          .map((p) => p.elevation)
          .whereType<double>()
          .toList();
      final avgEle = elevations.isEmpty
          ? 0.0
          : elevations.reduce((a, b) => a + b) / elevations.length;

      chart.add(
        WorkoutChartPoint(
          index: i + 1,
          paceMinPerKm: pace.clamp(3.0, 15.0),
          elevationM: avgEle,
          speedKmh: speedKmh.clamp(1.0, 40.0),
        ),
      );
    }

    return chart;
  }

  double _haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _degToRad(double deg) => deg * math.pi / 180.0;
}

class WorkoutFormatters {
  static String formatDateTime(DateTime? date) {
    if (date == null) return 'Дата неизвестна';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    if (day == today) return 'Сегодня в $time';
    if (day == today.subtract(const Duration(days: 1))) {
      return 'Вчера в $time';
    }

    const months = [
      'янв',
      'фев',
      'мар',
      'апр',
      'мая',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек',
    ];
    return '${date.day} ${months[date.month - 1]}. ${date.year} в $time';
  }

  static String formatDuration(Duration? duration) {
    if (duration == null) return '—';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  static String formatDurationLong(Duration? duration) {
    if (duration == null) return '—';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) return '$hours ч $minutes м';
    return '$minutes м';
  }

  static String formatDistanceKm(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} м';
    return '${(meters / 1000).toStringAsFixed(1)} км';
  }

  static String formatSpeed(double? kmh) {
    if (kmh == null) return '—';
    return '${kmh.toStringAsFixed(1)} км/ч';
  }

  static String formatPace(Duration? duration, double distanceMeters) {
    if (duration == null || distanceMeters <= 0) return '—';
    final km = distanceMeters / 1000;
    final minPerKm = duration.inSeconds / 60 / km;
    final minutes = minPerKm.floor();
    final seconds = ((minPerKm - minutes) * 60).round();
    return "$minutes'${seconds.toString().padLeft(2, '0')}'' /км";
  }
}
