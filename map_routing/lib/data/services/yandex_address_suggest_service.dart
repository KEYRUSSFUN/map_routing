import 'dart:async';

import 'package:map_routing/core/map/mapkit_bootstrap.dart';
import 'package:map_routing/data/models/address_suggestion.dart';
import 'package:yandex_maps_mapkit/mapkit.dart';
import 'package:yandex_maps_mapkit/search.dart';

class YandexAddressSuggestService {
  SearchManager? _searchManager;
  SearchSuggestSession? _suggestSession;
  SearchSession? _resolveSession;
  Future<void>? _initFuture;

  Future<void> ensureInitialized() {
    return _initFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    await MapkitBootstrap.ensureInitialized();
    _searchManager ??=
        SearchFactory.instance.createSearchManager(SearchManagerType.Online);
    _suggestSession ??= _searchManager!.createSuggestSession();
  }

  void suggest({
    required String text,
    required BoundingBox window,
    Point? userPosition,
    required void Function(List<AddressSuggestion> suggestions) onResult,
  }) {
    unawaited(_suggest(
      text: text,
      window: window,
      userPosition: userPosition,
      onResult: onResult,
    ));
  }

  Future<void> _suggest({
    required String text,
    required BoundingBox window,
    Point? userPosition,
    required void Function(List<AddressSuggestion> suggestions) onResult,
  }) async {
    if (text.trim().isEmpty) {
      onResult(const []);
      return;
    }

    try {
      await ensureInitialized();
    } catch (_) {
      onResult(const []);
      return;
    }

    _suggestSession!.suggest(
      window,
      SuggestOptions(
        suggestTypes: SuggestType.Geo | SuggestType.Biz,
        userPosition: userPosition,
      ),
      SearchSuggestSessionSuggestListener(
        onResponse: (response) {
          onResult(
            response.items
                .where((item) => item.action != SuggestItemAction.FollowLink)
                .map(_mapSuggestItem)
                .toList(),
          );
        },
        onError: (_) => onResult(const []),
      ),
      text: text,
    );
  }

  Future<Point?> resolvePoint(
    AddressSuggestion suggestion,
    BoundingBox window, {
    Point? userPosition,
  }) async {
    if (suggestion.center != null) {
      return suggestion.center;
    }

    await ensureInitialized();

    final completer = Completer<Point?>();
    _resolveSession?.cancel();

    final listener = SearchSessionSearchListener(
      onSearchResponse: (response) {
        if (!completer.isCompleted) {
          completer.complete(_extractPointFromResponse(response));
        }
      },
      onSearchError: (_) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
    );

    final options = SearchOptions(
      userPosition: userPosition,
      geometry: true,
    );

    if (suggestion.uri != null && suggestion.uri!.isNotEmpty) {
      _resolveSession = _searchManager!.resolveURI(
        options,
        listener,
        uri: suggestion.uri!,
      );
    } else {
      _resolveSession = _searchManager!.submit(
        Geometry.fromBoundingBox(window),
        options,
        listener,
        text: suggestion.searchText,
      );
    }

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => null,
    );
  }

  void dispose() {
    _resolveSession?.cancel();
    _suggestSession?.reset();
    _initFuture = null;
    _searchManager = null;
    _suggestSession = null;
  }

  AddressSuggestion _mapSuggestItem(SuggestItem item) {
    return AddressSuggestion(
      title: item.title.text,
      subtitle: item.subtitle?.text,
      searchText: item.displayText ?? item.searchText,
      center: item.center,
      uri: item.uri,
      action: item.action,
      isWordItem: item.isWordItem,
    );
  }

  Point? _extractPointFromResponse(SearchResponse response) {
    for (final child in response.collection.children) {
      final geoObject = child.asGeoObject();
      if (geoObject == null) continue;

      final point = _extractPointFromGeoObject(geoObject);
      if (point != null) return point;
    }
    return null;
  }

  Point? _extractPointFromGeoObject(GeoObject geoObject) {
    for (final geometry in geoObject.geometry) {
      final point = geometry.asPoint();
      if (point != null) return point;

      final circle = geometry.asCircle();
      if (circle != null) return circle.center;
    }

    final bounds = geoObject.boundingBox;
    if (bounds != null) {
      return Point(
        latitude: (bounds.southWest.latitude + bounds.northEast.latitude) / 2,
        longitude: (bounds.southWest.longitude + bounds.northEast.longitude) / 2,
      );
    }

    return null;
  }
}
