import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService extends ChangeNotifier {
  AppSettingsService._();

  static final AppSettingsService instance = AppSettingsService._();

  static const _pushNotificationsKey = 'settings_push_notifications';
  static const _autoPauseKey = 'settings_auto_pause';
  static const _hideMapEndpointsKey = 'settings_hide_map_endpoints';

  bool pushNotificationsEnabled = true;
  bool autoPauseEnabled = true;
  bool hideMapEndpoints = false;

  bool _loaded = false;
  Future<void>? _loading;

  Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    pushNotificationsEnabled = prefs.getBool(_pushNotificationsKey) ?? true;
    autoPauseEnabled = prefs.getBool(_autoPauseKey) ?? true;
    hideMapEndpoints = prefs.getBool(_hideMapEndpointsKey) ?? false;
    _loaded = true;
  }

  Future<bool> getPushNotificationsEnabled() async {
    await ensureLoaded();
    return pushNotificationsEnabled;
  }

  Future<void> setPushNotificationsEnabled(bool value) async {
    await ensureLoaded();
    if (pushNotificationsEnabled == value) return;

    pushNotificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pushNotificationsKey, value);
    notifyListeners();
  }

  Future<bool> getAutoPauseEnabled() async {
    await ensureLoaded();
    return autoPauseEnabled;
  }

  Future<void> setAutoPauseEnabled(bool value) async {
    await ensureLoaded();
    if (autoPauseEnabled == value) return;

    autoPauseEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoPauseKey, value);
    notifyListeners();
  }

  Future<bool> getHideMapEndpoints() async {
    await ensureLoaded();
    return hideMapEndpoints;
  }

  Future<void> setHideMapEndpoints(bool value) async {
    await ensureLoaded();
    if (hideMapEndpoints == value) return;

    hideMapEndpoints = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hideMapEndpointsKey, value);
    notifyListeners();
  }
}
