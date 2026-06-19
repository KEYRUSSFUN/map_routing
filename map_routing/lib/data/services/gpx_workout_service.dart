import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:map_routing/data/activity_calculator.dart';
import 'package:map_routing/data/models/route_share_snapshot.dart';
import 'package:map_routing/data/models/track_point.dart';
import 'package:map_routing/data/models/workout_activity_type.dart';
import 'package:map_routing/data/models/workout_metadata.dart';
import 'package:map_routing/data/models/workout_session_data.dart';
import 'package:map_routing/data/models/workout_summary.dart';
import 'package:map_routing/data/services/route_service.dart';
import 'package:map_routing/data/services/user_workout_storage.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

class GpxWorkoutService {
  final RouteService _routeService = RouteService();

  static List<WorkoutSummary>? _memoryWorkouts;
  static String? _memoryUserId;
  static DateTime? _memoryLoadedAt;
  static const _memoryTtl = Duration(minutes: 2);

  static void invalidateMemoryCache({bool notify = true}) {
    _memoryWorkouts = null;
    _memoryUserId = null;
    _memoryLoadedAt = null;
    if (notify) {
      onLibraryChanged?.call();
    }
  }

  /// Вызывается при добавлении/изменении локальных маршрутов (скачивание из чата и т.д.).
  static VoidCallback? onLibraryChanged;

  Future<List<WorkoutSummary>> loadWorkouts({
    double? userWeightKg,
    int? userAge,
    String? userId,
    bool force = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final targetUserId = userId ??
        await UserWorkoutStorage.instance.syncUserIdFromToken(
          prefs.getString('jwt_token'),
        );

    if (!force &&
        userId == null &&
        _memoryWorkouts != null &&
        _memoryUserId == targetUserId &&
        _memoryLoadedAt != null &&
        DateTime.now().difference(_memoryLoadedAt!) < _memoryTtl) {
      return _memoryWorkouts!;
    }

    final workouts = <WorkoutSummary>[];

    final seenKeys = <String>{};

    if (targetUserId != null) {
      final files =
          await UserWorkoutStorage.instance.listUserGpxFiles(userId: targetUserId);

      for (final file in files) {
        try {
          final summary = await parseWorkoutFile(
            file.path,
            userWeightKg: userWeightKg,
            userAge: userAge,
          );
          if (summary != null && summary.points.length >= 2) {
            _addWorkout(workouts, seenKeys, summary);
          }
        } catch (_) {}
      }
    }

    if (userId == null) {
      try {
        final backendRoutes = await _routeService.fetchUserRoutes();
        for (final route in backendRoutes) {
          try {
            final summary = parseBackendRoute(
              route,
              userWeightKg: userWeightKg,
              userAge: userAge,
            );
            if (summary != null && summary.points.length >= 2) {
              _addWorkout(workouts, seenKeys, summary);
            }
          } catch (_) {}
        }
      } catch (_) {
        // Бэкенд недоступен — показываем локальные маршруты.
      }
    }

    workouts.sort((a, b) {
      final aDate = a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    if (userId == null && targetUserId != null) {
      _memoryWorkouts = workouts;
      _memoryUserId = targetUserId;
      _memoryLoadedAt = DateTime.now();
    }

    return workouts;
  }

  Future<bool> deleteWorkout(
    WorkoutSummary workout, {
    bool notify = true,
  }) async {
    var deleted = false;
    int? backendRouteId;

    try {
      if (workout.filePath.isNotEmpty) {
        final gpxPath = workout.filePath;
        final metadata = await WorkoutMetadata.loadFromGpxPath(gpxPath);
        backendRouteId = metadata?.backendRouteId;

        final gpxFile = File(gpxPath);
        if (await gpxFile.exists()) {
          await gpxFile.delete();
        }

        final jsonFile = File(p.setExtension(gpxPath, '.json'));
        if (await jsonFile.exists()) {
          await jsonFile.delete();
        }

        final photoPath = metadata?.photoPath ?? workout.photoPath;
        if (photoPath != null && photoPath.isNotEmpty) {
          final photoFile = File(photoPath);
          if (await photoFile.exists()) {
            await photoFile.delete();
          }
        }

        deleted = true;
      } else if (workout.id.startsWith('backend_route_')) {
        backendRouteId =
            int.tryParse(workout.id.replaceFirst('backend_route_', ''));
      }

      if (backendRouteId != null) {
        if (await _routeService.deleteRoute(backendRouteId)) {
          deleted = true;
        }
      }
    } catch (_) {
      // Локальное удаление могло частично пройти — не прерываем пакетное удаление.
    }

    if (deleted && notify) {
      invalidateMemoryCache();
    }
    return deleted;
  }

  Future<int> deleteWorkouts(Iterable<WorkoutSummary> workouts) async {
    var deletedCount = 0;
    for (final workout in workouts) {
      if (await deleteWorkout(workout, notify: false)) {
        deletedCount++;
      }
    }
    if (deletedCount > 0) {
      invalidateMemoryCache(notify: false);
    }
    return deletedCount;
  }

  Future<WorkoutSummary> updateWorkoutDetails(
    WorkoutSummary workout, {
    required String title,
    required String description,
    required List<String> tags,
    required int effortLevel,
    required WorkoutPrivacy privacy,
  }) async {
    final trimmedTitle =
        title.trim().isEmpty ? workout.title : title.trim();
    final trimmedDescription = description.trim();
    var backendRouteId = workout.backendRouteId;

    if (workout.filePath.isNotEmpty) {
      final existing = await WorkoutMetadata.loadFromGpxPath(workout.filePath);
      final baseMetadata = existing ??
          WorkoutMetadata(
            title: workout.title,
            activityType: workout.activityType ?? WorkoutActivityType.run,
            description: workout.description ?? '',
            tags: workout.tags,
            effortLevel: workout.effortLevel ?? 3,
            notes: workout.notes ?? '',
            privacy: workout.privacy ?? WorkoutPrivacy.friends,
            photoPath: workout.photoPath,
            photoUrl: workout.photoUrl,
            distanceMeters: workout.distanceMeters,
            durationSeconds: workout.duration?.inSeconds,
            calories: workout.calories,
            elevationGainM: workout.elevationGainM,
            avgSpeedKmh: workout.avgSpeedKmh,
            startedAtIso: workout.startedAt?.toUtc().toIso8601String(),
            backendRouteId: workout.backendRouteId,
            importedFromChat: workout.isImported,
            shareId: existing?.shareId,
          );

      final metadata = baseMetadata.copyWith(
        title: trimmedTitle,
        description: trimmedDescription,
        tags: tags,
        effortLevel: effortLevel,
        privacy: privacy,
      );
      await WorkoutMetadata.saveToFile(workout.filePath, metadata);
      backendRouteId = metadata.backendRouteId ?? backendRouteId;

      if (backendRouteId != null && !workout.isImported) {
        await _routeService.updateRouteMetadata(
          routeId: backendRouteId,
          title: trimmedTitle,
          description: trimmedDescription,
          tags: tags,
          effortLevel: effortLevel,
          privacy: privacy,
        );
      }

      final refreshed = await parseWorkoutFile(workout.filePath);
      invalidateMemoryCache();
      if (refreshed != null) return refreshed;
    } else if (backendRouteId != null) {
      await _routeService.updateRouteMetadata(
        routeId: backendRouteId,
        title: trimmedTitle,
        description: trimmedDescription,
        tags: tags,
        effortLevel: effortLevel,
        privacy: privacy,
      );
      invalidateMemoryCache();
    } else {
      invalidateMemoryCache();
    }

    return workout.copyWith(
      title: trimmedTitle,
      description: trimmedDescription.isEmpty ? null : trimmedDescription,
      tags: tags,
      effortLevel: effortLevel,
      privacy: privacy,
    );
  }

  void _addWorkout(
    List<WorkoutSummary> workouts,
    Set<String> seenKeys,
    WorkoutSummary summary,
  ) {
    if (summary.backendRouteId != null &&
        workouts.any((w) => w.backendRouteId == summary.backendRouteId)) {
      return;
    }

    if (summary.id.startsWith('backend_route_')) {
      final routeId =
          int.tryParse(summary.id.replaceFirst('backend_route_', ''));
      if (routeId != null &&
          workouts.any((w) => w.backendRouteId == routeId)) {
        return;
      }
    }

    final fingerprint = _trackFingerprint(summary);
    if (summary.source == WorkoutSource.synced ||
        summary.backendRouteId != null) {
      if (workouts.any(
        (w) => w.isImported && _trackFingerprint(w) == fingerprint,
      )) {
        return;
      }
    }

    final key = _dedupeKey(summary);
    if (seenKeys.contains(key)) return;

    seenKeys.add(key);
    workouts.add(summary);
  }

  String _trackFingerprint(WorkoutSummary w) {
    if (w.points.length < 2) return w.id;
    final first = w.points.first;
    final last = w.points.last;
    return '${w.points.length}-${w.distanceMeters.round()}-'
        '${first.latitude.toStringAsFixed(5)}-'
        '${first.longitude.toStringAsFixed(5)}-'
        '${last.latitude.toStringAsFixed(5)}-'
        '${last.longitude.toStringAsFixed(5)}';
  }

  bool _isImportedPath(String filePath) {
    return p.basename(filePath).startsWith('shared_');
  }

  int? _shareIdFromPath(String filePath) {
    final match = RegExp(r'^shared_(\d+)_').firstMatch(p.basename(filePath));
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
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
      avgHeartRate: _averageHeartRate(
        points: session.points,
        distanceMeters: session.distanceMeters,
        duration: session.duration,
        activityType: metadata.activityType,
        avgSpeedKmh: session.avgSpeedKmh,
        effortLevel: metadata.effortLevel,
        userWeightKg: null,
        userAge: null,
      ),
      cadenceSpm: cadenceSpm,
      points: session.points,
      chartPoints: _buildChartPoints(session.points),
      activityType: metadata.activityType,
      description:
          metadata.description.isEmpty ? null : metadata.description,
      tags: metadata.tags,
      photoPath: metadata.photoPath,
      photoUrl: metadata.photoUrl,
      effortLevel: metadata.effortLevel,
      notes: metadata.notes.isEmpty ? null : metadata.notes,
      privacy: metadata.privacy,
      source: WorkoutSource.fromPath(gpxPath),
      backendRouteId: metadata.backendRouteId,
    );
  }

  String _dedupeKey(WorkoutSummary w) {
    if (w.filePath.isNotEmpty) return w.filePath;
    return w.id;
  }

  WorkoutSummary? parseBackendRoute(
    BackendRoute route, {
    double? userWeightKg,
    int? userAge,
  }) {
    final startedAt = route.startedAt ?? route.creationDate;
    final points = _parseGeoJsonPoints(route.path, startedAt: startedAt);
    if (points.length < 2) return null;

    final activityType = route.activityType != null
        ? WorkoutActivityType.fromId(route.activityType)
        : null;
    final duration = route.durationSeconds != null
        ? Duration(seconds: route.durationSeconds!)
        : null;

    final summary = _buildSummary(
      id: 'backend_route_${route.id}',
      title: (route.title?.trim().isNotEmpty ?? false)
          ? route.title!.trim()
          : _titleFromDate(startedAt),
      filePath: '',
      startedAt: startedAt,
      points: points,
      userWeightKg: userWeightKg,
      userAge: userAge,
      activityType: activityType,
    );

    return WorkoutSummary(
      id: summary.id,
      title: summary.title,
      filePath: summary.filePath,
      startedAt: startedAt ?? summary.startedAt,
      distanceMeters: route.distanceMeters ?? summary.distanceMeters,
      duration: duration ?? summary.duration,
      avgSpeedKmh: route.avgSpeedKmh ?? summary.avgSpeedKmh,
      elevationGainM: route.elevationGainM ?? summary.elevationGainM,
      calories: route.calories ?? summary.calories,
      avgHeartRate: _averageHeartRate(
        points: points,
        distanceMeters: route.distanceMeters ?? summary.distanceMeters,
        duration: duration ?? summary.duration,
        activityType: activityType,
        avgSpeedKmh: route.avgSpeedKmh ?? summary.avgSpeedKmh,
        effortLevel: route.effortLevel,
        userWeightKg: userWeightKg,
        userAge: userAge,
      ) ??
          summary.avgHeartRate,
      cadenceSpm: summary.cadenceSpm,
      points: summary.points,
      chartPoints: summary.chartPoints,
      activityType: activityType,
      description: (route.description?.trim().isNotEmpty ?? false)
          ? route.description!.trim()
          : null,
      tags: route.tags,
      photoUrl: route.photoUrl,
      effortLevel: route.effortLevel,
      notes: (route.notes?.trim().isNotEmpty ?? false) ? route.notes!.trim() : null,
      privacy: route.privacy != null
          ? WorkoutPrivacy.fromId(route.privacy)
          : null,
      source: WorkoutSource.synced,
      backendRouteId: route.id,
    );
  }

  Future<bool> hasValidTrack(String gpxPath) async {
    final summary = await _readGpxSummary(gpxPath);
    return summary != null && summary.points.length >= 2;
  }

  /// Создаёт sidecar `.json` для GPX без метаданных (локальные файлы без sidecar).
  Future<void> ensureSidecarMetadataIfMissing(
    String gpxPath, {
    required String title,
    WorkoutActivityType activityType = WorkoutActivityType.run,
    WorkoutSummary? precomputedSummary,
    double? userWeightKg,
    int? userAge,
  }) async {
    if (_isImportedPath(gpxPath)) return;
    if (await WorkoutMetadata.loadFromGpxPath(gpxPath) != null) return;

    final summary = precomputedSummary ??
        await _readGpxSummary(
          gpxPath,
          userWeightKg: userWeightKg,
          userAge: userAge,
        );
    if (summary == null) return;

    final metadata = WorkoutMetadata(
      title: title.trim().isEmpty ? 'Тренировка' : title.trim(),
      activityType: activityType,
      distanceMeters: summary.distanceMeters,
      durationSeconds: summary.duration?.inSeconds,
      calories: summary.calories,
      elevationGainM: summary.elevationGainM,
      avgSpeedKmh: summary.avgSpeedKmh,
      startedAtIso: summary.startedAt?.toUtc().toIso8601String(),
    );
    await WorkoutMetadata.saveToFile(gpxPath, metadata);
  }

  /// Записывает только публичные метаданные для маршрута, скачанного из чата.
  Future<void> writeImportedRouteMetadata(
    String gpxPath, {
    required int shareId,
    required String title,
    RouteShareSnapshot? snapshot,
    String? localPhotoPath,
    WorkoutSummary? precomputedSummary,
    double? userWeightKg,
    int? userAge,
  }) async {
    final summary = precomputedSummary ??
        await _readGpxSummary(
          gpxPath,
          userWeightKg: userWeightKg,
          userAge: userAge,
        );
    if (summary == null) return;

    final metadata = WorkoutMetadata.imported(
      title: title,
      shareId: shareId,
      activityType: snapshot?.activityType ?? WorkoutActivityType.run,
      distanceMeters: snapshot?.distanceMeters ?? summary.distanceMeters,
      durationSeconds:
          snapshot?.durationSeconds ?? summary.duration?.inSeconds,
      calories: snapshot?.calories ?? summary.calories,
      elevationGainM: snapshot?.elevationGainM ?? summary.elevationGainM,
      avgSpeedKmh: snapshot?.avgSpeedKmh ?? summary.avgSpeedKmh,
      startedAtIso: snapshot?.startedAtIso ??
          summary.startedAt?.toUtc().toIso8601String(),
      description: snapshot?.description ?? '',
      tags: snapshot?.tags ?? const [],
      effortLevel: snapshot?.effortLevel ?? 3,
      notes: snapshot?.notes ?? '',
      photoUrl: snapshot?.photoUrl,
      photoPath: localPhotoPath,
    );
    await WorkoutMetadata.saveToFile(gpxPath, metadata);
  }

  Future<WorkoutSummary?> _readGpxSummary(
    String filePath, {
    double? userWeightKg,
    int? userAge,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final xmlString = await file.readAsString();
    final doc = XmlDocument.parse(xmlString);
    final points = _parseTrackPoints(doc);
    if (points.length < 2) return null;

    final startedAt = _parseStartTime(doc, filePath);
    return _buildSummary(
      id: filePath,
      title: _titleFromPath(filePath, startedAt),
      filePath: filePath,
      startedAt: startedAt,
      points: points,
      userWeightKg: userWeightKg,
      userAge: userAge,
    );
  }

  Future<WorkoutSummary?> parseWorkoutFile(
    String filePath, {
    double? userWeightKg,
    int? userAge,
  }) async {
    final summary = await _readGpxSummary(
      filePath,
      userWeightKg: userWeightKg,
      userAge: userAge,
    );
    if (summary == null) return null;

    if (_isImportedPath(filePath)) {
      await _repairImportedSidecarIfNeeded(filePath);
    } else if (await WorkoutMetadata.loadFromGpxPath(filePath) == null) {
      await ensureSidecarMetadataIfMissing(
        filePath,
        title: summary.title,
        precomputedSummary: summary,
        userWeightKg: userWeightKg,
        userAge: userAge,
      );
    }

    return _enrichWithMetadata(
      summary,
      filePath,
      userWeightKg: userWeightKg,
      userAge: userAge,
    );
  }

  WorkoutSummary _buildSummary({
    required String id,
    required String title,
    required String filePath,
    required DateTime? startedAt,
    required List<TrackPoint> points,
    double? userWeightKg,
    int? userAge,
    double? userHeightCm,
    WorkoutActivityType? activityType,
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

    final calculator = ActivityCalculator(
      weightKg: userWeightKg ?? 70,
      heightCm: userHeightCm,
      age: userAge,
    );
    final resolvedActivity = activityType ?? WorkoutActivityType.run;

    int? calories;
    if (userWeightKg != null &&
        (distanceMeters > 0 ||
            (duration != null && duration.inSeconds > 0))) {
      calories = calculator
          .calculateCalories(
            activityType: resolvedActivity,
            duration: duration,
            distanceMeters: distanceMeters,
            avgSpeedKmh: avgSpeedKmh,
          )
          .round();
    }

    int? cadenceSpm;
    if (duration != null && duration.inMinutes > 0) {
      final steps =
          calculator.estimateStepsByDistance(distanceMeters);
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
      avgHeartRate: _averageHeartRate(
        points: points,
        distanceMeters: distanceMeters,
        duration: duration,
        activityType: resolvedActivity,
        avgSpeedKmh: avgSpeedKmh,
        effortLevel: null,
        userWeightKg: userWeightKg,
        userAge: userAge,
      ),
      cadenceSpm: cadenceSpm,
      points: points,
      chartPoints: _buildChartPoints(points),
      activityType: activityType,
      description: null,
      tags: const [],
      photoPath: null,
      effortLevel: null,
      notes: null,
      privacy: null,
      source: WorkoutSource.fromPath(filePath),
    );
  }

  Future<void> _repairImportedSidecarIfNeeded(String filePath) async {
    final metadata = await WorkoutMetadata.loadFromGpxPath(filePath);
    if (metadata == null) return;

    final pathShareId = _shareIdFromPath(filePath);
    if (pathShareId == null) return;

    if (metadata.shareId == pathShareId &&
        metadata.importedFromChat &&
        metadata.backendRouteId == null) {
      return;
    }

    await WorkoutMetadata.saveToFile(
      filePath,
      metadata.copyWith(
        shareId: pathShareId,
        importedFromChat: true,
        backendRouteId: null,
      ),
    );
  }

  WorkoutSource _resolveSource(String filePath, WorkoutMetadata metadata) {
    if (metadata.importedFromChat || p.basename(filePath).startsWith('shared_')) {
      return WorkoutSource.imported;
    }
    return WorkoutSource.fromPath(filePath);
  }

  Future<WorkoutSummary?> _enrichWithMetadata(
    WorkoutSummary summary,
    String filePath, {
    double? userWeightKg,
    int? userAge,
  }) async {
    if (filePath.isEmpty) return summary;
    final metadata = await WorkoutMetadata.loadFromGpxPath(filePath);
    if (metadata == null) {
      return WorkoutSummary(
        id: summary.id,
        title: summary.title,
        filePath: summary.filePath,
        startedAt: summary.startedAt,
        distanceMeters: summary.distanceMeters,
        duration: summary.duration,
        avgSpeedKmh: summary.avgSpeedKmh,
        elevationGainM: summary.elevationGainM,
        calories: summary.calories,
        avgHeartRate: summary.avgHeartRate,
        cadenceSpm: summary.cadenceSpm,
        points: summary.points,
        chartPoints: summary.chartPoints,
        activityType: summary.activityType,
        description: summary.description,
        tags: summary.tags,
        photoPath: summary.photoPath,
        photoUrl: summary.photoUrl,
        effortLevel: summary.effortLevel,
        notes: summary.notes,
        privacy: summary.privacy,
        source: WorkoutSource.fromPath(filePath),
        backendRouteId: summary.backendRouteId,
      );
    }

    final startedAt = metadata.startedAtIso != null
        ? DateTime.tryParse(metadata.startedAtIso!)?.toLocal()
        : summary.startedAt;

    final isImported =
        metadata.importedFromChat || _isImportedPath(filePath);

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
      avgHeartRate: _averageHeartRate(
        points: summary.points,
        distanceMeters: metadata.distanceMeters ?? summary.distanceMeters,
        duration: metadata.durationSeconds != null
            ? Duration(seconds: metadata.durationSeconds!)
            : summary.duration,
        activityType: metadata.activityType,
        avgSpeedKmh: metadata.avgSpeedKmh ?? summary.avgSpeedKmh,
        effortLevel: metadata.effortLevel,
        userWeightKg: userWeightKg,
        userAge: userAge,
      ) ??
          summary.avgHeartRate,
      cadenceSpm: summary.cadenceSpm,
      points: summary.points,
      chartPoints: summary.chartPoints,
      activityType: metadata.activityType,
      description:
          metadata.description.isEmpty ? null : metadata.description,
      tags: metadata.tags,
      photoPath: metadata.photoPath,
      photoUrl: metadata.photoUrl,
      effortLevel: metadata.effortLevel,
      notes: metadata.notes.isEmpty ? null : metadata.notes,
      privacy: isImported ? null : metadata.privacy,
      source: _resolveSource(filePath, metadata),
      backendRouteId: isImported ? null : metadata.backendRouteId,
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
    final trackPoints = _parseGpxPoints(doc, 'trkpt');
    if (trackPoints.length >= 2) return trackPoints;

    final routePoints = _parseGpxPoints(doc, 'rtept');
    if (routePoints.length >= 2) return routePoints;

    return trackPoints.length >= routePoints.length
        ? trackPoints
        : routePoints;
  }

  List<TrackPoint> _parseGpxPoints(XmlDocument doc, String tagName) {
    final result = <TrackPoint>[];
    for (final element in doc.findAllElements(tagName)) {
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
          heartRate: tagName == 'trkpt'
              ? _parseHeartRateFromTrkpt(element)
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
    if (base.startsWith('shared_')) {
      final match = RegExp(r'^shared_\d+_(.+)$').firstMatch(base);
      if (match != null) {
        final name = match.group(1)!.replaceAll('_', ' ');
        if (name.isNotEmpty && name.toLowerCase() != 'route') return name;
      }
      return 'Маршрут из чата';
    }
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

  int? _parseHeartRateFromTrkpt(XmlElement element) {
    for (final hrElement in element.findAllElements('hr')) {
      final value = int.tryParse(hrElement.innerText.trim());
      if (value != null && value >= 40 && value <= 220) {
        return value;
      }
    }
    return null;
  }

  int? _averageHeartRate({
    required List<TrackPoint> points,
    required double distanceMeters,
    Duration? duration,
    WorkoutActivityType? activityType,
    double? avgSpeedKmh,
    int? effortLevel,
    double? userWeightKg,
    int? userAge,
  }) {
    final measured = points
        .map((point) => point.heartRate)
        .whereType<int>()
        .where((hr) => hr >= 40 && hr <= 220)
        .toList();
    if (measured.isNotEmpty) {
      return (measured.reduce((a, b) => a + b) / measured.length).round();
    }

    return ActivityCalculator(
      weightKg: userWeightKg ?? 70,
      age: userAge,
    ).estimateAverageHeartRate(
      distanceMeters: distanceMeters,
      duration: duration,
      activityType: activityType,
      avgSpeedKmh: avgSpeedKmh,
      effortLevel: effortLevel,
    );
  }
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
