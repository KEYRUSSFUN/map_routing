import 'dart:convert';

import 'package:map_routing/data/models/workout_activity_type.dart';
import 'package:map_routing/data/models/workout_metadata.dart';
import 'package:map_routing/data/models/workout_summary.dart';

/// Снимок маршрута при шаринге в чат — трек + метаданные тренировки.
class RouteShareSnapshot {
  const RouteShareSnapshot({
    this.activityType,
    this.distanceMeters,
    this.durationSeconds,
    this.elevationGainM,
    this.avgSpeedKmh,
    this.calories,
    this.startedAtIso,
    this.description,
    this.tags = const [],
    this.effortLevel,
    this.notes,
    this.photoUrl,
    this.hasPhoto = false,
  });

  final WorkoutActivityType? activityType;
  final double? distanceMeters;
  final int? durationSeconds;
  final double? elevationGainM;
  final double? avgSpeedKmh;
  final int? calories;
  final String? startedAtIso;
  final String? description;
  final List<String> tags;
  final int? effortLevel;
  final String? notes;
  final String? photoUrl;
  final bool hasPhoto;

  factory RouteShareSnapshot.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RouteShareSnapshot();
    return RouteShareSnapshot(
      activityType: _parseActivityType(
        json['activity_type'] ?? json['activityType'],
      ),
      distanceMeters: _parseDouble(json['distance'] ?? json['distanceMeters']),
      durationSeconds:
          _parseInt(json['duration_seconds'] ?? json['durationSeconds']),
      elevationGainM:
          _parseDouble(json['elevation_gain_m'] ?? json['elevationGainM']),
      avgSpeedKmh: _parseDouble(json['avg_speed_kmh'] ?? json['avgSpeedKmh']),
      calories: _parseInt(json['calories']),
      startedAtIso: _parseString(json['started_at'] ?? json['startedAtIso']),
      description: _parseString(json['description']),
      tags: _parseTags(json['tags']),
      effortLevel: _parseInt(json['effort_level'] ?? json['effortLevel']),
      notes: _parseString(json['notes']),
      photoUrl: _parseString(json['photo_url'] ?? json['photoUrl']),
      hasPhoto: _parseBool(json['hasPhoto']),
    );
  }

  factory RouteShareSnapshot.fromMetadata(WorkoutMetadata metadata) {
    return RouteShareSnapshot(
      activityType: metadata.activityType,
      distanceMeters: metadata.distanceMeters,
      durationSeconds: metadata.durationSeconds,
      elevationGainM: metadata.elevationGainM,
      avgSpeedKmh: metadata.avgSpeedKmh,
      calories: metadata.calories,
      startedAtIso: metadata.startedAtIso,
      description:
          metadata.description.isEmpty ? null : metadata.description,
      tags: metadata.tags,
      effortLevel: metadata.effortLevel,
      notes: metadata.notes.isEmpty ? null : metadata.notes,
      hasPhoto: metadata.photoPath?.isNotEmpty ?? false,
    );
  }

  factory RouteShareSnapshot.fromWorkout(WorkoutSummary workout) {
    return RouteShareSnapshot(
      activityType: workout.activityType,
      distanceMeters: workout.distanceMeters,
      durationSeconds: workout.duration?.inSeconds,
      elevationGainM: workout.elevationGainM,
      avgSpeedKmh: workout.avgSpeedKmh,
      calories: workout.calories,
      startedAtIso: workout.startedAt?.toUtc().toIso8601String(),
      description: workout.description,
      tags: workout.tags,
      effortLevel: workout.effortLevel,
      notes: workout.notes,
      photoUrl: workout.photoUrl,
      hasPhoto: (workout.photoPath?.isNotEmpty ?? false) ||
          (workout.photoUrl?.isNotEmpty ?? false),
    );
  }

  /// Объединяет snapshot из сообщения чата с данными route_share.
  factory RouteShareSnapshot.fromShareMessage(
    Map<String, dynamic> routeShare,
  ) {
    final snapshotMap = _snapshotMapFromShare(routeShare['snapshot']);
    final base = snapshotMap != null
        ? RouteShareSnapshot.fromJson(snapshotMap)
        : const RouteShareSnapshot();
    final photoUrl =
        _parseString(routeShare['photoUrl']) ?? base.photoUrl;
    return RouteShareSnapshot(
      activityType: base.activityType,
      distanceMeters: base.distanceMeters,
      durationSeconds: base.durationSeconds,
      elevationGainM: base.elevationGainM,
      avgSpeedKmh: base.avgSpeedKmh,
      calories: base.calories,
      startedAtIso: base.startedAtIso,
      description: base.description,
      tags: base.tags,
      effortLevel: base.effortLevel,
      notes: base.notes,
      photoUrl: photoUrl,
      hasPhoto: _parseBool(routeShare['hasPhoto'], fallback: base.hasPhoto),
    );
  }

  static Map<String, dynamic>? _snapshotMapFromShare(dynamic snapshotJson) {
    if (snapshotJson == null) return null;
    if (snapshotJson is Map) {
      return Map<String, dynamic>.from(snapshotJson);
    }
    if (snapshotJson is String && snapshotJson.trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(snapshotJson);
        if (parsed is Map) {
          return Map<String, dynamic>.from(parsed);
        }
      } catch (_) {}
    }
    return null;
  }

  static WorkoutActivityType? _parseActivityType(dynamic value) {
    final id = _parseString(value);
    if (id == null || id.isEmpty) return null;
    return WorkoutActivityType.fromId(id);
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static String? _parseString(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return value.toString();
  }

  static bool _parseBool(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return fallback;
  }

  static List<String> _parseTags(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(raw);
        if (parsed is List) {
          return parsed
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      } catch (_) {
        return raw
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }
    return const [];
  }

  Map<String, String> toFormFields() {
    final fields = <String, String>{};
    if (activityType != null) {
      fields['activity_type'] = activityType!.id;
    }
    if (distanceMeters != null) {
      fields['distance'] = distanceMeters!.toString();
    }
    if (durationSeconds != null) {
      fields['duration_seconds'] = durationSeconds!.toString();
    }
    if (elevationGainM != null) {
      fields['elevation_gain_m'] = elevationGainM!.toString();
    }
    if (avgSpeedKmh != null) {
      fields['avg_speed_kmh'] = avgSpeedKmh!.toString();
    }
    if (calories != null) {
      fields['calories'] = calories!.toString();
    }
    if (startedAtIso != null && startedAtIso!.isNotEmpty) {
      fields['started_at'] = startedAtIso!;
    }
    if (description != null && description!.trim().isNotEmpty) {
      fields['description'] = description!.trim();
    }
    if (tags.isNotEmpty) {
      fields['tags'] = jsonEncode(tags);
    }
    if (effortLevel != null) {
      fields['effort_level'] = effortLevel!.toString();
    }
    if (notes != null && notes!.trim().isNotEmpty) {
      fields['notes'] = notes!.trim();
    }
    return fields;
  }
}
