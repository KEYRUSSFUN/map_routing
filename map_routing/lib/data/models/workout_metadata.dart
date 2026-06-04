import 'dart:convert';
import 'dart:io';

import 'package:map_routing/data/models/workout_activity_type.dart';

class WorkoutMetadata {
  const WorkoutMetadata({
    required this.title,
    required this.activityType,
    this.description = '',
    this.photoPath,
    this.tags = const [],
    this.effortLevel = 3,
    this.notes = '',
    this.privacy = WorkoutPrivacy.friends,
    this.distanceMeters,
    this.durationSeconds,
    this.calories,
    this.elevationGainM,
    this.avgSpeedKmh,
    this.startedAtIso,
  });

  final String title;
  final WorkoutActivityType activityType;
  final String description;
  final String? photoPath;
  final List<String> tags;
  final int effortLevel;
  final String notes;
  final WorkoutPrivacy privacy;
  final double? distanceMeters;
  final int? durationSeconds;
  final int? calories;
  final double? elevationGainM;
  final double? avgSpeedKmh;
  final String? startedAtIso;

  Map<String, dynamic> toJson() => {
        'title': title,
        'activityType': activityType.id,
        'description': description,
        'photoPath': photoPath,
        'tags': tags,
        'effortLevel': effortLevel,
        'notes': notes,
        'privacy': privacy.id,
        if (distanceMeters != null) 'distanceMeters': distanceMeters,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
        if (calories != null) 'calories': calories,
        if (elevationGainM != null) 'elevationGainM': elevationGainM,
        if (avgSpeedKmh != null) 'avgSpeedKmh': avgSpeedKmh,
        if (startedAtIso != null) 'startedAtIso': startedAtIso,
      };

  factory WorkoutMetadata.fromJson(Map<String, dynamic> json) {
    return WorkoutMetadata(
      title: json['title'] as String? ?? 'Тренировка',
      activityType: WorkoutActivityType.fromId(json['activityType'] as String?),
      description: json['description'] as String? ?? '',
      photoPath: json['photoPath'] as String?,
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      effortLevel: json['effortLevel'] as int? ?? 3,
      notes: json['notes'] as String? ?? '',
      privacy: WorkoutPrivacy.fromId(json['privacy'] as String?),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      durationSeconds: json['durationSeconds'] as int?,
      calories: json['calories'] as int?,
      elevationGainM: (json['elevationGainM'] as num?)?.toDouble(),
      avgSpeedKmh: (json['avgSpeedKmh'] as num?)?.toDouble(),
      startedAtIso: json['startedAtIso'] as String?,
    );
  }

  static Future<void> saveToFile(String gpxPath, WorkoutMetadata metadata) async {
    final metaPath = gpxPath.replaceAll('.gpx', '.json');
    await File(metaPath).writeAsString(jsonEncode(metadata.toJson()));
  }

  static Future<WorkoutMetadata?> loadFromGpxPath(String gpxPath) async {
    final metaPath = gpxPath.replaceAll('.gpx', '.json');
    final file = File(metaPath);
    if (!await file.exists()) return null;
    try {
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return WorkoutMetadata.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}
