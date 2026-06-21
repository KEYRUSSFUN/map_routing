import 'package:shared_preferences/shared_preferences.dart';

class AchievementSeenStorage {
  AchievementSeenStorage._();

  static final AchievementSeenStorage instance = AchievementSeenStorage._();

  static const _key = 'achievement_badges_seen';

  Future<Set<String>> loadSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key)?.toSet() ?? {};
  }

  Future<void> markSeen(String achievementId) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList(_key)?.toSet() ?? {};
    if (seen.add(achievementId)) {
      await prefs.setStringList(_key, seen.toList());
    }
  }
}
