import 'dart:convert';
import 'dart:io';

import 'package:map_routing/data/models/workout_activity_type.dart';
import 'package:path/path.dart' as p;

class WorkoutMetadata {
  const WorkoutMetadata({
    required this.title,
    required this.activityType,
    this.description = '',
    this.photoPath,
    this.photoUrl,
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
    this.startedAtLocalHour,
    this.backendRouteId,
    this.importedFromChat = false,
    this.shareId,
    this.sharedByUserId,
    this.sharedByUserName,
    this.sharedByAvatarUrl,
  });

  final String title;
  final WorkoutActivityType activityType;
  final String description;
  final String? photoPath;
  final String? photoUrl;
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
  final int? startedAtLocalHour;
  final int? backendRouteId;
  final bool importedFromChat;
  final int? shareId;
  final String? sharedByUserId;
  final String? sharedByUserName;
  final String? sharedByAvatarUrl;

  factory WorkoutMetadata.imported({
    required String title,
    required int shareId,
    WorkoutActivityType activityType = WorkoutActivityType.run,
    double? distanceMeters,
    int? durationSeconds,
    int? calories,
    double? elevationGainM,
    double? avgSpeedKmh,
    String? startedAtIso,
    int? startedAtLocalHour,
    String description = '',
    List<String> tags = const [],
    int effortLevel = 3,
    String notes = '',
    String? photoPath,
    String? photoUrl,
    String? sharedByUserId,
    String? sharedByUserName,
    String? sharedByAvatarUrl,
  }) {
    return WorkoutMetadata(
      title: title.trim().isEmpty ? 'Маршрут из чата' : title.trim(),
      activityType: activityType,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      calories: calories,
      elevationGainM: elevationGainM,
      avgSpeedKmh: avgSpeedKmh,
      startedAtIso: startedAtIso,
      startedAtLocalHour: startedAtLocalHour,
      importedFromChat: true,
      shareId: shareId,
      description: description,
      tags: tags,
      notes: notes,
      effortLevel: effortLevel,
      photoPath: photoPath,
      photoUrl: photoUrl,
      sharedByUserId: sharedByUserId,
      sharedByUserName: sharedByUserName,
      sharedByAvatarUrl: sharedByAvatarUrl,
    );
  }

  WorkoutMetadata copyWith({
    String? title,
    WorkoutActivityType? activityType,
    String? description,
    String? photoPath,
    String? photoUrl,
    List<String>? tags,
    int? effortLevel,
    String? notes,
    WorkoutPrivacy? privacy,
    double? distanceMeters,
    int? durationSeconds,
    int? calories,
    double? elevationGainM,
    double? avgSpeedKmh,
    String? startedAtIso,
    int? startedAtLocalHour,
    int? backendRouteId,
    bool? importedFromChat,
    int? shareId,
    String? sharedByUserId,
    String? sharedByUserName,
    String? sharedByAvatarUrl,
  }) {
    return WorkoutMetadata(
      title: title ?? this.title,
      activityType: activityType ?? this.activityType,
      description: description ?? this.description,
      photoPath: photoPath ?? this.photoPath,
      photoUrl: photoUrl ?? this.photoUrl,
      tags: tags ?? this.tags,
      effortLevel: effortLevel ?? this.effortLevel,
      notes: notes ?? this.notes,
      privacy: privacy ?? this.privacy,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      calories: calories ?? this.calories,
      elevationGainM: elevationGainM ?? this.elevationGainM,
      avgSpeedKmh: avgSpeedKmh ?? this.avgSpeedKmh,
      startedAtIso: startedAtIso ?? this.startedAtIso,
      startedAtLocalHour: startedAtLocalHour ?? this.startedAtLocalHour,
      backendRouteId: backendRouteId ?? this.backendRouteId,
      importedFromChat: importedFromChat ?? this.importedFromChat,
      shareId: shareId ?? this.shareId,
      sharedByUserId: sharedByUserId ?? this.sharedByUserId,
      sharedByUserName: sharedByUserName ?? this.sharedByUserName,
      sharedByAvatarUrl: sharedByAvatarUrl ?? this.sharedByAvatarUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'activityType': activityType.id,
        'description': description,
        if (photoPath != null) 'photoPath': photoPath,
        if (photoUrl != null) 'photoUrl': photoUrl,
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
        if (startedAtLocalHour != null) 'startedAtLocalHour': startedAtLocalHour,
        if (backendRouteId != null && !importedFromChat)
          'backendRouteId': backendRouteId,
        if (importedFromChat) 'importedFromChat': true,
        if (shareId != null) 'shareId': shareId,
        if (sharedByUserId != null) 'sharedByUserId': sharedByUserId,
        if (sharedByUserName != null) 'sharedByUserName': sharedByUserName,
        if (sharedByAvatarUrl != null) 'sharedByAvatarUrl': sharedByAvatarUrl,
      };

  factory WorkoutMetadata.fromJson(Map<String, dynamic> json) {
    final imported = json['importedFromChat'] as bool? ?? false;
    return WorkoutMetadata(
      title: json['title'] as String? ?? 'Тренировка',
      activityType: WorkoutActivityType.fromId(json['activityType'] as String?),
      description: json['description'] as String? ?? '',
      photoPath: json['photoPath'] as String?,
      photoUrl: json['photoUrl'] as String?,
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
      startedAtLocalHour: json['startedAtLocalHour'] as int?,
      backendRouteId:
          imported ? null : (json['backendRouteId'] as num?)?.toInt(),
      importedFromChat: imported,
      shareId: (json['shareId'] as num?)?.toInt(),
      sharedByUserId: json['sharedByUserId'] as String?,
      sharedByUserName: json['sharedByUserName'] as String?,
      sharedByAvatarUrl: json['sharedByAvatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toBackendPayload() => {
        'title': title,
        'activity_type': activityType.id,
        'description': description,
        'tags': tags,
        'effort_level': effortLevel,
        'notes': notes,
        'privacy': privacy.id,
        if (distanceMeters != null) 'distance': distanceMeters,
        if (durationSeconds != null) 'duration_seconds': durationSeconds,
        if (calories != null) 'calories': calories,
        if (elevationGainM != null) 'elevation_gain_m': elevationGainM,
        if (avgSpeedKmh != null) 'avg_speed_kmh': avgSpeedKmh,
        if (startedAtIso != null) 'started_at': startedAtIso,
        if (startedAtLocalHour != null)
          'started_at_local_hour': startedAtLocalHour,
      };

  static String metaPathForGpx(String gpxPath) =>
      p.setExtension(gpxPath, '.json');

  static Future<void> saveToFile(
    String gpxPath,
    WorkoutMetadata metadata,
  ) async {
    final metaPath = metaPathForGpx(gpxPath);
    await File(metaPath).writeAsString(jsonEncode(metadata.toJson()));
  }

  static Future<WorkoutMetadata?> loadFromGpxPath(String gpxPath) async {
    final metaPath = metaPathForGpx(gpxPath);
    final file = File(metaPath);
    if (!await file.exists()) return null;
    try {
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return WorkoutMetadata.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}
