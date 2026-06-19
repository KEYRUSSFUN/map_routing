import 'dart:convert';
import 'dart:io';

import 'package:map_routing/data/models/planned_workout.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PlannedWorkoutStorage {
  PlannedWorkoutStorage._();

  static final PlannedWorkoutStorage instance = PlannedWorkoutStorage._();

  static const _rootName = 'planned_workouts';

  Future<Directory?> _userDirectory(String userId) async {
    final root = await getExternalStorageDirectory();
    if (root == null) return null;

    final dir = Directory(p.join(root.path, _rootName, userId));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<List<PlannedWorkout>> loadAll(String userId) async {
    final dir = await _userDirectory(userId);
    if (dir == null) return [];

    final workouts = <PlannedWorkout>[];
    for (final entity in dir.listSync().whereType<File>()) {
      if (!entity.path.endsWith('.json')) continue;
      try {
        final raw = jsonDecode(await entity.readAsString());
        if (raw is Map) {
          workouts.add(
            PlannedWorkout.fromJson(Map<String, dynamic>.from(raw)),
          );
        }
      } catch (_) {}
    }

    workouts.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return workouts;
  }

  Future<void> save(String userId, PlannedWorkout workout) async {
    final dir = await _userDirectory(userId);
    if (dir == null) return;

    final file = File(p.join(dir.path, '${workout.id}.json'));
    await file.writeAsString(jsonEncode(workout.toJson()));
  }

  Future<void> delete(String userId, String workoutId) async {
    final dir = await _userDirectory(userId);
    if (dir == null) return;

    final file = File(p.join(dir.path, '$workoutId.json'));
    if (await file.exists()) {
      await file.delete();
    }
  }
}
