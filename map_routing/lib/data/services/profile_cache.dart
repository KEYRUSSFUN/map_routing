import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ProfileCacheSnapshot {
  const ProfileCacheSnapshot({
    required this.name,
    required this.country,
    required this.avatarUrl,
    required this.distanceKm,
    required this.steps,
    required this.calories,
    required this.weeklyDistanceKm,
    required this.weekChangeLabel,
    required this.weeklyActivity,
  });

  final String name;
  final String country;
  final String avatarUrl;
  final double distanceKm;
  final int steps;
  final double calories;
  final double weeklyDistanceKm;
  final String weekChangeLabel;
  final List<double> weeklyActivity;

  Map<String, dynamic> toJson() => {
        'name': name,
        'country': country,
        'avatarUrl': avatarUrl,
        'distanceKm': distanceKm,
        'steps': steps,
        'calories': calories,
        'weeklyDistanceKm': weeklyDistanceKm,
        'weekChangeLabel': weekChangeLabel,
        'weeklyActivity': weeklyActivity,
      };

  factory ProfileCacheSnapshot.fromJson(Map<String, dynamic> json) {
    final weeklyRaw = json['weeklyActivity'];
    return ProfileCacheSnapshot(
      name: json['name']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString() ?? '',
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      steps: (json['steps'] as num?)?.toInt() ?? 0,
      calories: (json['calories'] as num?)?.toDouble() ?? 0,
      weeklyDistanceKm: (json['weeklyDistanceKm'] as num?)?.toDouble() ?? 0,
      weekChangeLabel: json['weekChangeLabel']?.toString() ?? '',
      weeklyActivity: weeklyRaw is List
          ? weeklyRaw.map((v) => (v as num).toDouble()).toList()
          : const [0, 0, 0, 0, 0, 0, 0],
    );
  }
}

class ProfileCache {
  ProfileCache._();

  static final ProfileCache instance = ProfileCache._();

  static const _cacheRootName = 'profile_snapshot';

  Future<Directory?> _cacheRoot() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, _cacheRootName));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  File? _cacheFile(Directory root, String userId) {
    final safeUserId = userId.replaceAll(RegExp(r'[^\w\-]'), '_');
    return File(p.join(root.path, '$safeUserId.json'));
  }

  Future<ProfileCacheSnapshot?> load({required String userId}) async {
    final root = await _cacheRoot();
    if (root == null) return null;

    final file = _cacheFile(root, userId);
    if (file == null || !file.existsSync()) return null;

    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map<String, dynamic>) return null;
      return ProfileCacheSnapshot.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> save({
    required String userId,
    required ProfileCacheSnapshot snapshot,
  }) async {
    final root = await _cacheRoot();
    if (root == null) return;

    final file = _cacheFile(root, userId);
    if (file == null) return;

    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(snapshot.toJson()));
  }

  Future<void> clear({required String userId}) async {
    final root = await _cacheRoot();
    if (root == null) return;

    final file = _cacheFile(root, userId);
    if (file != null && file.existsSync()) {
      await file.delete();
    }
  }
}
