import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserWorkoutStorage {
  UserWorkoutStorage._();

  static final UserWorkoutStorage instance = UserWorkoutStorage._();

  static const _currentUserIdKey = 'current_user_id';
  static const _workoutsRootName = 'workouts';
  static const _legacyMigratedPrefix = 'legacy_workouts_migrated_';

  Future<String?> getStoredUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentUserIdKey);
  }

  Future<void> setCurrentUserId(String userId) async {
    final normalized = userId.trim();
    if (normalized.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserIdKey, normalized);
  }

  Future<void> clearCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserIdKey);
  }

  String? userIdFromToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;

    try {
      var payload = parts[1];
      final mod = payload.length % 4;
      if (mod > 0) {
        payload += '=' * (4 - mod);
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      return map['user_id']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<String?> syncUserIdFromToken(String? token) async {
    if (token == null || token.isEmpty) {
      await clearCurrentUserId();
      return null;
    }

    final userId = userIdFromToken(token);
    if (userId == null) return await getStoredUserId();

    final previous = await getStoredUserId();
    await setCurrentUserId(userId);
    await migrateLegacyFilesIfNeeded(userId);

    if (previous != null && previous != userId) {
      // Сменился аккаунт — папка другого пользователя уже используется.
    }

    return userId;
  }

  Future<Directory?> getUserWorkoutsDirectory(String userId) async {
    final root = await getExternalStorageDirectory();
    if (root == null) return null;

    final dir = Directory(p.join(root.path, _workoutsRootName, userId));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory?> getCurrentUserWorkoutsDirectory() async {
    final userId = await getStoredUserId();
    if (userId == null || userId.isEmpty) return null;
    return getUserWorkoutsDirectory(userId);
  }

  Future<String?> newGpxFilePath(String prefix) async {
    var dir = await getCurrentUserWorkoutsDirectory();
    if (dir == null) {
      final prefs = await SharedPreferences.getInstance();
      await syncUserIdFromToken(prefs.getString('jwt_token'));
      dir = await getCurrentUserWorkoutsDirectory();
    }
    if (dir == null) return null;

    return p.join(
      dir.path,
      '${prefix}_${DateTime.now().millisecondsSinceEpoch}.gpx',
    );
  }

  Future<List<File>> listUserGpxFiles({String? userId}) async {
    final targetId = userId ?? await getStoredUserId();
    if (targetId == null || targetId.isEmpty) return [];

    await migrateLegacyFilesIfNeeded(targetId);

    final dir = await getUserWorkoutsDirectory(targetId);
    if (dir == null || !dir.existsSync()) return [];

    return dir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.gpx'))
        .toList();
  }

  Future<void> migrateLegacyFilesIfNeeded(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final flagKey = '$_legacyMigratedPrefix$userId';
    if (prefs.getBool(flagKey) == true) return;

    final root = await getExternalStorageDirectory();
    if (root == null) return;

    final userDir = await getUserWorkoutsDirectory(userId);
    if (userDir == null) return;

    final rootDir = Directory(root.path);
    if (!rootDir.existsSync()) {
      await prefs.setBool(flagKey, true);
      return;
    }

    for (final entity in rootDir.listSync()) {
      if (entity is! File) continue;

      final fileName = p.basename(entity.path);
      final lower = fileName.toLowerCase();

      if (lower.endsWith('.gpx')) {
        if (!_isWorkoutGpxName(fileName)) continue;
      } else if (lower.endsWith('.json')) {
        if (!_isWorkoutGpxName(fileName.replaceAll('.json', ''))) continue;
      } else {
        continue;
      }

      final destPath = p.join(userDir.path, fileName);
      if (File(destPath).existsSync()) continue;

      try {
        await entity.rename(destPath);
      } catch (_) {
        try {
          await entity.copy(destPath);
          await entity.delete();
        } catch (_) {}
      }
    }

    await prefs.setBool(flagKey, true);
  }

  bool _isWorkoutGpxName(String baseName) {
    return baseName.startsWith('tracked_route_') ||
        baseName.startsWith('saved_route_') ||
        baseName.startsWith('shared_');
  }

  /// Копирует фото тренировки рядом с GPX, чтобы оно не пропало из кэша галереи.
  Future<String?> persistWorkoutPhoto(String gpxPath, String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) return null;

    var ext = p.extension(sourcePath).toLowerCase();
    if (ext.isEmpty) ext = '.jpg';

    final baseName = p.basenameWithoutExtension(gpxPath);
    final destPath = p.join(p.dirname(gpxPath), '${baseName}_photo$ext');
    await source.copy(destPath);
    return destPath;
  }
}
