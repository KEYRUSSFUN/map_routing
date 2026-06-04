import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService {
  static const _pushNotificationsKey = 'settings_push_notifications';
  static const _autoPauseKey = 'settings_auto_pause';
  static const _hideMapEndpointsKey = 'settings_hide_map_endpoints';

  Future<bool> getPushNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pushNotificationsKey) ?? true;
  }

  Future<void> setPushNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pushNotificationsKey, value);
  }

  Future<bool> getAutoPauseEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoPauseKey) ?? true;
  }

  Future<void> setAutoPauseEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoPauseKey, value);
  }

  Future<bool> getHideMapEndpoints() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hideMapEndpointsKey) ?? false;
  }

  Future<void> setHideMapEndpoints(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hideMapEndpointsKey, value);
  }
}
