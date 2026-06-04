import 'package:shared_preferences/shared_preferences.dart';

class AuthLocalStorage {
  static const _pendingFullNameKey = 'pending_full_name';

  static Future<void> savePendingFullName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingFullNameKey, name.trim());
  }

  static Future<String?> getPendingFullName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingFullNameKey);
  }

  static Future<void> clearPendingFullName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingFullNameKey);
  }
}
