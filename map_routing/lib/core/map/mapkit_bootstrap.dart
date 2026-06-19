import 'dart:async';
import 'dart:ui' as ui;

import 'package:yandex_maps_mapkit/init.dart' as init;

/// Initializes Yandex MapKit once before any MapKit / Search API usage.
class MapkitBootstrap {
  MapkitBootstrap._();

  static const _apiKey = '548e7748-56df-4316-844a-fa548260d146';

  static Completer<void>? _ready;
  static bool _initialized = false;

  static String _mapkitLocale() {
    final locale = ui.PlatformDispatcher.instance.locale;
    final country = locale.countryCode;
    if (country != null && country.isNotEmpty) {
      return '${locale.languageCode}_$country';
    }
    return locale.languageCode;
  }

  static Future<void> ensureInitialized() async {
    if (_initialized) return;

    if (_ready != null) return _ready!.future;

    _ready = Completer<void>();
    try {
      await init.initMapkit(
        apiKey: _apiKey,
        locale: _mapkitLocale(),
      );
      _initialized = true;
      _ready!.complete();
    } catch (error, stackTrace) {
      _ready!.completeError(error, stackTrace);
      _ready = null;
      rethrow;
    }

    return _ready!.future;
  }
}
