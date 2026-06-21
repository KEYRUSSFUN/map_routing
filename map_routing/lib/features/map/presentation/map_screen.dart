import 'package:collection/collection.dart';
import 'package:common/listeners/map_input_listener.dart';
import 'package:common/map/flutter_map_widget.dart';
import 'package:map_routing/core/map/mapkit_bootstrap.dart';
import 'package:map_routing/core/widgets/app_confirm_dialog.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:flutter/material.dart' hide Animation;
import 'package:map_routing/data/activity_calculator.dart';
import 'package:map_routing/data/geometry_provider.dart';
import 'package:map_routing/data/models/address_suggestion.dart';
import 'package:map_routing/data/models/track_point.dart';
import 'package:map_routing/data/models/workout_activity_type.dart';
import 'package:map_routing/data/models/workout_session_data.dart';
import 'package:map_routing/data/models/planned_workout.dart';
import 'package:map_routing/data/models/workout_summary.dart';
import 'package:map_routing/data/route_progress_tracker.dart';
import 'package:map_routing/data/routing_type.dart';
import 'package:map_routing/data/services/app_settings_service.dart';
import 'package:map_routing/data/services/gps_track_processor.dart';
import 'package:map_routing/data/services/user_service.dart';
import 'package:map_routing/data/services/yandex_address_suggest_service.dart';
import 'package:map_routing/features/map/presentation/map_ui_styles.dart';
import 'package:map_routing/features/map/presentation/save_workout_page.dart';
import 'package:map_routing/features/map/presentation/widgets/map_idle_overlay.dart';
import 'package:map_routing/features/map/presentation/widgets/map_location_marker_icon.dart';
import 'package:map_routing/features/map/presentation/widgets/map_route_marker_icons.dart';
import 'package:map_routing/features/map/presentation/widgets/map_workout_overlay.dart';
import 'package:map_routing/features/map/presentation/widgets/workout_metrics_sheet.dart';
import 'package:map_routing/features/map/services/workout_location_settings.dart';
import 'package:map_routing/shared/utils/polyline_extensions.dart';
import 'package:geolocator/geolocator.dart';
import 'package:yandex_maps_mapkit/image.dart' as image_provider;
import 'package:yandex_maps_mapkit/mapkit.dart' hide LocationSettings, Icon;
import 'package:yandex_maps_mapkit/transport.dart';
import 'dart:async';
import 'package:flutter_compass/flutter_compass.dart';
import 'dart:math' as math;

typedef WorkoutUiChangedCallback = void Function({
  required bool isActive,
  required bool isFullscreen,
});

class MapScreen extends StatefulWidget {
  const MapScreen({
    Key? key,
    this.gpxPath,
    this.onWorkoutUiChanged,
    this.onWorkoutSaved,
    this.bottomNavPadding = 0,
    this.isTabActive = true,
  }) : super(key: key);

  final String? gpxPath;
  final WorkoutUiChangedCallback? onWorkoutUiChanged;
  final VoidCallback? onWorkoutSaved;
  final double bottomNavPadding;
  final bool isTabActive;

  @override
  State<MapScreen> createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  MapWindow? _mapWindow;
  MapObjectCollection? _userLocationCollection;
  MapObjectCollection? _placemarksCollection;
  MapObjectCollection? _routesCollection;
  Point? _lastKnownPoint;
  double? _lastKnownHeading;
  bool _appInForeground = true;
  DateTime? _lastTrackingUiUpdate;
  static const _trackingUiInterval = Duration(milliseconds: 500);
  var _routePoints = <Point>[];
  List<Point>? _savedRouteTrackPoints;
  var _pedestrianRoutes = <MasstransitRoute>[];
  var _publicTransportRoutes = <MasstransitRoute>[];
  var _currentRoutingType = RoutingType.pedestrian;

  PlacemarkMapObject? _currentLocationPlacemark;
  PlacemarkMapObject? _routeStartPlacemark;
  PlacemarkMapObject? _routeFinishPlacemark;
  image_provider.ImageProvider? _locationMarkerProvider;
  image_provider.ImageProvider? _startPointMarkerProvider;
  image_provider.ImageProvider? _finishPointMarkerProvider;

  bool _isTracking = false;
  bool _isMinimized = false;
  bool _isLocked = false;
  bool _isManualPaused = false;
  bool _isAutoPaused = false;
  DateTime? _autoPauseCandidateSince;
  DateTime? _autoResumeCandidateSince;
  static const _autoPauseSpeedMs = 0.3;
  static const _autoResumeSpeedMs = 0.5;
  static const _autoPauseDelay = Duration(seconds: 8);
  static const _autoResumeDelay = Duration(seconds: 3);
  StreamSubscription<Position>? _positionStream;
  final List<TrackPoint> _trackedRoutePoints = [];
  final GpsTrackProcessor _gpsTrackProcessor = GpsTrackProcessor();

  double _totalDistance = 0.0;
  double _currentSpeedMs = 0.0;
  double _maxSpeedMs = 0.0;
  double _elevationGainM = 0.0;
  double? _lastElevation;
  double _userWeightKg = 70;
  double? _userHeightCm;
  int? _userAge;
  double _mapZoom = 16;
  bool _hasInitialCameraFocused = false;

  static const _initialCameraAnimation = Animation(
    type: AnimationType.Smooth,
    duration: 0.85,
  );

  WorkoutActivityType _selectedActivity = WorkoutActivityType.run;
  DateTime? _workoutStartedAt;
  Duration _accumulatedPause = Duration.zero;
  DateTime? _pauseStartedAt;
  Timer? _tickTimer;
  Duration _elapsed = Duration.zero;
  final DraggableScrollableController _metricsSheetController =
      DraggableScrollableController();

  RouteProgressTracker? _routeProgressTracker;
  RouteProgressTracker? _approachProgressTracker;
  List<Point>? _approachRoutePoints;
  bool _hasReachedWorkoutStart = true;
  bool _isGuidedWorkout = false;
  double _guidedRemainingM = 0;
  double _guidedProgress = 0;
  bool _isOffRoute = false;
  static const _workoutStartThresholdM = 35.0;
  static const _workoutCompleteProgress = 0.995;
  bool _workoutAutoFinishing = false;
  double? _lastAcceptedProjectedMeters;

  late PedestrianRouter _pedestrianRouter;
  late MasstransitRouter _publicTransportRouter;

  StreamSubscription<CompassEvent>? _compassStream;
  bool _sensorsActive = false;
  bool _compassActive = false;
  bool _mapSurfaceMounted = false;
  bool _routersReady = false;
  bool _mapRefreshScheduled = false;
  Timer? _sensorPauseTimer;
  Timer? _mapSurfaceTimer;

  MasstransitSession? _pedestrianSession;
  MasstransitSession? _publicTransportSession;
  MasstransitSession? _approachPedestrianSession;
  MasstransitSession? _approachPublicTransportSession;

  final _addressSuggestService = YandexAddressSuggestService();

  bool get isTrackingActive => _isTracking;
  bool get isWorkoutFullscreen => _isTracking && !_isMinimized;

  bool get _isWorkoutPaused => _isManualPaused || _isAutoPaused;

  bool get _hideMapEndpoints => AppSettingsService.instance.hideMapEndpoints;

  bool get _isMapReady =>
      _mapWindow != null &&
      _userLocationCollection != null &&
      _routesCollection != null &&
      _placemarksCollection != null &&
      widget.isTabActive;

  void _scheduleMapRefresh() {
    if (!_isMapReady || _mapWindow == null || _mapRefreshScheduled) return;
    _mapRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapRefreshScheduled = false;
      if (!mounted || _mapWindow == null || !widget.isTabActive) return;
      _requestMapRefresh();
    });
  }

  void _requestMapRefresh() {
    final mapWindow = _mapWindow;
    if (mapWindow == null) return;
    mapWindow.map.move(mapWindow.map.cameraPosition);
  }

  late final pointImageProvider =
      image_provider.ImageProvider.fromImageProvider(
          const AssetImage('assets/start_point.png'));

  late final finishPointImageProvider =
      image_provider.ImageProvider.fromImageProvider(
          const AssetImage('assets/ic_finish_point.png'));

  image_provider.ImageProvider _resolveStartMarkerProvider() =>
      _startPointMarkerProvider ?? pointImageProvider;

  image_provider.ImageProvider _resolveFinishMarkerProvider() =>
      _finishPointMarkerProvider ?? finishPointImageProvider;

  void _clearRouteEndpointMarkers() {
    final collection = _placemarksCollection;
    if (_routeStartPlacemark != null) {
      try {
        collection?.remove(_routeStartPlacemark!);
      } catch (_) {}
      _routeStartPlacemark = null;
    }
    if (_routeFinishPlacemark != null) {
      try {
        collection?.remove(_routeFinishPlacemark!);
      } catch (_) {}
      _routeFinishPlacemark = null;
    }
  }

  void _discardRouteEndpointMarkers() {
    _routeStartPlacemark = null;
    _routeFinishPlacemark = null;
  }

  void _setRouteEndpointMarkers({Point? start, Point? finish}) {
    _clearRouteEndpointMarkers();
    if (_hideMapEndpoints) return;

    final collection = _placemarksCollection;
    if (collection == null) return;

    if (start != null) {
      _routeStartPlacemark = collection.addPlacemark()..geometry = start;
      _routeStartPlacemark!
        ..setIcon(_resolveStartMarkerProvider())
        ..setIconStyle(
          const IconStyle(
            scale: MapRouteMarkerIcons.startIconScale,
            zIndex: 120,
          ),
        );
    }

    if (finish != null) {
      _routeFinishPlacemark = collection.addPlacemark()..geometry = finish;
      _routeFinishPlacemark!
        ..setIcon(_resolveFinishMarkerProvider())
        ..setIconStyle(
          const IconStyle(
            scale: MapRouteMarkerIcons.finishIconScale,
            zIndex: 120,
          ),
        );
    }
  }

  late final _inputListener = MapInputListenerImpl(
    onMapTapCallback: (_, __) {},
    onMapLongTapCallback: (map, point) {
      if (_isTracking || !_isMapReady || _routePoints.length >= 2) return;
      _addRoutePoint(point);
    },
  );

  late final _pedestrianRouteListener = RouteHandler(
    onMasstransitRoutes: (newRoutes) {
      if (newRoutes.isEmpty) {
        AppSnackBar.show(context, 'Не удалось построить маршрут');
      }
      setState(() => _pedestrianRoutes = newRoutes);
      _onPedestrianRoutesUpdated();
    },
    onMasstransitRoutesError: (error) {
      AppSnackBar.show(context, 'Ошибка построения маршрута (пешком)');
    },
  );

  late final _publicTransportRouteListener = RouteHandler(
    onMasstransitRoutes: (newRoutes) {
      if (newRoutes.isEmpty) {
        AppSnackBar.show(context, 'Не удалось построить маршрут');
      }
      setState(() => _publicTransportRoutes = newRoutes);
      _onPublicTransportRoutesUpdated();
    },
    onMasstransitRoutesError: (error) {
      AppSnackBar.show(context, 'Ошибка построения маршрута (транспорт)');
    },
  );

  late final _approachPedestrianRouteListener = RouteHandler(
    onMasstransitRoutes: (newRoutes) {
      if (newRoutes.isEmpty || !mounted) return;
      _onApproachRouteResolved(newRoutes.first.geometry.points);
    },
    onMasstransitRoutesError: (_) {},
  );

  late final _approachPublicTransportRouteListener = RouteHandler(
    onMasstransitRoutes: (newRoutes) {
      if (newRoutes.isEmpty || !mounted) return;
      _onApproachRouteResolved(newRoutes.first.geometry.points);
    },
    onMasstransitRoutesError: (_) {},
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(AppSettingsService.instance.ensureLoaded());
    AppSettingsService.instance.addListener(_onAppSettingsChanged);
    unawaited(_ensureRoutersReady());
    unawaited(_loadUserProfile());
    _loadLocationMarkerIcon();
    _loadRouteMarkerIcons();
    if (widget.isTabActive) {
      _onTabBecameActive();
    }
  }

  Future<void> _ensureRoutersReady() async {
    if (_routersReady) return;
    await MapkitBootstrap.ensureInitialized();
    if (!mounted) return;
    await _addressSuggestService.ensureInitialized();
    if (!mounted) return;
    _pedestrianRouter = TransportFactory.instance.createPedestrianRouter();
    _publicTransportRouter =
        TransportFactory.instance.createMasstransitRouter();
    _routersReady = true;
  }

  bool get _needsSensors => widget.isTabActive || _isTracking;

  void _onTabBecameActive() {
    _scheduleMapSurface();
    _scheduleSensorStart();
  }

  void _onTabBecameInactive() {
    _scheduleSensorPause();
  }

  void _scheduleMapSurface() {
    if (_mapSurfaceMounted || !widget.isTabActive) return;
    _mapSurfaceTimer?.cancel();
    _mapSurfaceTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted || !widget.isTabActive || _mapSurfaceMounted) return;
      setState(() => _mapSurfaceMounted = true);
    });
  }

  void _scheduleSensorStart() {
    if (!_needsSensors || _sensorsActive) return;
    _sensorPauseTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_needsSensors) return;
      _ensureLocationActive();
    });
  }

  void _scheduleSensorPause() {
    _sensorPauseTimer?.cancel();
    _sensorPauseTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted || _needsSensors) return;
      _pauseSensors();
    });
  }

  void _ensureLocationActive() {
    if (_sensorsActive || !_needsSensors) return;
    _sensorsActive = true;
    _startLocationUpdates();
  }

  void _ensureCompassActive() {
    if (_compassActive || !_needsSensors || !_isMapReady) return;
    _compassActive = true;
    _startCompassUpdates();
  }

  void _pauseSensors() {
    _sensorPauseTimer?.cancel();
    if (!_sensorsActive && !_compassActive) return;
    _sensorsActive = false;
    _compassActive = false;
    _positionStream?.cancel();
    _positionStream = null;
    _compassStream?.cancel();
    _compassStream = null;
  }

  void _syncSensorsState() {
    if (_needsSensors) {
      _scheduleSensorStart();
    } else {
      _scheduleSensorPause();
    }
  }

  Future<void> _loadLocationMarkerIcon() async {
    final bytes = await MapLocationMarkerIcon.toPngBytes();
    if (!mounted) return;

    _locationMarkerProvider =
        image_provider.ImageProvider.fromImageProvider(MemoryImage(bytes));

    if (_isMapReady && _lastKnownPoint != null) {
      _updateCurrentLocationMarker(_lastKnownPoint!, _lastKnownHeading);
    }
  }

  Future<void> _loadRouteMarkerIcons() async {
    final results = await Future.wait([
      MapRouteMarkerIcons.startPointPng(),
      MapRouteMarkerIcons.finishPointPng(),
    ]);
    if (!mounted) return;

    _startPointMarkerProvider =
        image_provider.ImageProvider.fromImageProvider(MemoryImage(results[0]));
    _finishPointMarkerProvider =
        image_provider.ImageProvider.fromImageProvider(MemoryImage(results[1]));

    if (_isMapReady) {
      _onRouteParametersUpdated();
    }
  }

  @override
  void dispose() {
    AppSettingsService.instance.removeListener(_onAppSettingsChanged);
    _mapSurfaceTimer?.cancel();
    _sensorPauseTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _positionStream?.cancel();
    _compassStream?.cancel();
    _tickTimer?.cancel();
    _metricsSheetController.dispose();
    _pedestrianSession?.cancel();
    _publicTransportSession?.cancel();
    _clearApproachRoute();
    _addressSuggestService.dispose();
    super.dispose();
  }

  void _onAppSettingsChanged() {
    if (!_isAutoPaused && !AppSettingsService.instance.autoPauseEnabled) {
      _autoPauseCandidateSince = null;
      _autoResumeCandidateSince = null;
    }
    if (_isMapReady) {
      _onRouteParametersUpdated();
    }
  }

  void _evaluateAutoPause(double speedMs) {
    if (!_isTracking || _isManualPaused) {
      _autoPauseCandidateSince = null;
      _autoResumeCandidateSince = null;
      return;
    }

    if (!AppSettingsService.instance.autoPauseEnabled) {
      if (_isAutoPaused) {
        _exitAutoPause();
      }
      _autoPauseCandidateSince = null;
      _autoResumeCandidateSince = null;
      return;
    }

    final now = DateTime.now();

    if (_isAutoPaused) {
      if (speedMs >= _autoResumeSpeedMs) {
        _autoResumeCandidateSince ??= now;
        if (now.difference(_autoResumeCandidateSince!) >= _autoResumeDelay) {
          _exitAutoPause();
        }
      } else {
        _autoResumeCandidateSince = null;
      }
      return;
    }

    if (speedMs < _autoPauseSpeedMs) {
      _autoPauseCandidateSince ??= now;
      if (now.difference(_autoPauseCandidateSince!) >= _autoPauseDelay) {
        _enterAutoPause();
      }
    } else {
      _autoPauseCandidateSince = null;
    }
  }

  void _enterAutoPause() {
    if (!_isTracking || _isWorkoutPaused) return;
    setState(() {
      _isAutoPaused = true;
      _pauseStartedAt = DateTime.now();
      _autoPauseCandidateSince = null;
      _autoResumeCandidateSince = null;
    });
  }

  void _exitAutoPause() {
    if (!_isAutoPaused) return;
    setState(() {
      if (_pauseStartedAt != null) {
        _accumulatedPause += DateTime.now().difference(_pauseStartedAt!);
      }
      _pauseStartedAt = null;
      _isAutoPaused = false;
      _autoResumeCandidateSince = null;
    });
  }

  void _clearSavedRoutePreview() {
    _savedRouteTrackPoints = null;
  }

  void _addRoutePoint(Point point) {
    if (_isTracking || _routePoints.length >= 2) return;

    _clearSavedRoutePreview();
    _routePoints = [..._routePoints, point];
    final isFirstPoint = _routePoints.length == 1;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (isFirstPoint) {
        AppSnackBar.show(
          context,
          'Маршрут до точки. Добавьте финиш или нажмите ▶',
        );
      } else if (_routePoints.length == 2) {
        AppSnackBar.show(
          context,
          'Маршрут между точками готов. Нажмите ▶ для старта',
        );
      }
      setState(() {});
      _onRouteParametersUpdated();
    });
  }

  BoundingBox _getSearchBoundingBox() {
    if (_mapWindow != null) {
      return VisibleRegionUtils.getBounds(_mapWindow!.map.visibleRegion);
    }
    return const BoundingBox(
      Point(latitude: 53.34, longitude: 83.72),
      Point(latitude: 53.38, longitude: 83.80),
    );
  }

  Future<void> _onAddressSelected(AddressSuggestion suggestion) async {
    await _applyAddressSuggestion(
      suggestion,
      role: _RouteAddressRole.destination,
    );
  }

  Future<void> _onStartAddressSelected(AddressSuggestion suggestion) async {
    await _applyAddressSuggestion(
      suggestion,
      role: _RouteAddressRole.start,
    );
  }

  Future<void> _onEndAddressSelected(AddressSuggestion suggestion) async {
    await _applyAddressSuggestion(
      suggestion,
      role: _RouteAddressRole.end,
    );
  }

  Future<void> _applyAddressSuggestion(
    AddressSuggestion suggestion, {
    required _RouteAddressRole role,
  }) async {
    if (_isTracking || !_isMapReady) return;

    FocusManager.instance.primaryFocus?.unfocus();

    final point = await _addressSuggestService.resolvePoint(
      suggestion,
      _getSearchBoundingBox(),
      userPosition: _lastKnownPoint,
    );

    if (!mounted) return;
    if (point == null) {
      AppSnackBar.show(context, 'Не удалось определить координаты адреса');
      return;
    }

    setState(() {
      _clearSavedRoutePreview();
      _pedestrianRoutes = [];
      _publicTransportRoutes = [];

      switch (role) {
        case _RouteAddressRole.destination:
          _routePoints = [point];
        case _RouteAddressRole.start:
          if (_routePoints.length >= 2) {
            _routePoints = [point, _routePoints.last];
          } else if (_routePoints.length == 1) {
            _routePoints = [point, _routePoints.first];
          } else {
            _routePoints = [point];
          }
        case _RouteAddressRole.end:
          if (_routePoints.isEmpty) {
            _routePoints = [point];
          } else if (_routePoints.length == 1) {
            _routePoints = [_routePoints.first, point];
          } else {
            _routePoints = [_routePoints.first, point];
          }
      }
    });

    _animateCameraToPoint(point);
    _onRouteParametersUpdated();

    final message = switch (role) {
      _RouteAddressRole.destination => 'Маршрут до адреса построен',
      _RouteAddressRole.start => 'Точка старта установлена',
      _RouteAddressRole.end => _routePoints.length >= 2
          ? 'Маршрут между точками готов'
          : 'Точка назначения установлена',
    };
    AppSnackBar.show(context, message);
  }

  void _animateCameraToPoint(Point point, {double? zoom}) {
    if (_mapWindow == null) return;
    _mapWindow!.map.move(
      CameraPosition(point, zoom: zoom ?? _mapZoom, azimuth: 0, tilt: 0),
      animation: _initialCameraAnimation,
    );
  }

  Future<void> loadSavedRoute(WorkoutSummary workout) async {
    if (_isTracking) {
      AppSnackBar.show(context, 'Завершите тренировку перед загрузкой маршрута');
      return;
    }

    var trackPoints = <Point>[];
    if (workout.filePath.isNotEmpty) {
      trackPoints =
          await GeometryProvider.loadAndParseGPX(workout.filePath);
    }
    if (trackPoints.length < 2 && workout.points.length >= 2) {
      trackPoints = workout.points
          .map((p) => Point(latitude: p.latitude, longitude: p.longitude))
          .toList();
    }

    if (!mounted) return;
    if (trackPoints.length < 2) {
      AppSnackBar.show(context, 'Не удалось загрузить маршрут');
      return;
    }

    _pedestrianSession?.cancel();
    _publicTransportSession?.cancel();
    _pedestrianSession = null;
    _publicTransportSession = null;

    setState(() {
      _savedRouteTrackPoints = trackPoints;
      _routePoints = [trackPoints.first, trackPoints.last];
      _pedestrianRoutes = [];
      _publicTransportRoutes = [];
    });
    _clearApproachRoute();

    _onRouteParametersUpdated();
    _fitCameraToTrack(trackPoints);
    AppSnackBar.show(context, 'Маршрут «${workout.title}» на карте');
  }

  Future<void> loadPlannedWorkout(PlannedWorkout workout) async {
    if (_isTracking) {
      AppSnackBar.show(
        context,
        'Завершите тренировку перед загрузкой маршрута',
      );
      return;
    }

    final trackPoints = workout.displayRoutePoints;
    if (trackPoints.length < 2) {
      AppSnackBar.show(context, 'Не удалось загрузить маршрут');
      return;
    }

    _pedestrianSession?.cancel();
    _publicTransportSession?.cancel();
    _pedestrianSession = null;
    _publicTransportSession = null;

    setState(() {
      _savedRouteTrackPoints = trackPoints;
      _routePoints = [workout.startPoint, workout.endPoint];
      _selectedActivity = workout.activityType;
      _pedestrianRoutes = [];
      _publicTransportRoutes = [];
    });
    _clearApproachRoute();

    _onRouteParametersUpdated();
    _fitCameraToTrack(trackPoints);
    AppSnackBar.show(
      context,
      'Запланированная тренировка «${workout.title}» на карте',
    );
  }

  void _fitCameraToTrack(List<Point> points) {
    if (_mapWindow == null || points.isEmpty) return;

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLon = points.first.longitude;
    var maxLon = points.first.longitude;

    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLon = math.min(minLon, point.longitude);
      maxLon = math.max(maxLon, point.longitude);
    }

    final center = Point(
      latitude: (minLat + maxLat) / 2,
      longitude: (minLon + maxLon) / 2,
    );
    final span = math.max(maxLat - minLat, maxLon - minLon);
    final zoom = span <= 0.001
        ? _mapZoom
        : (math.log(360 / span) / math.ln2).clamp(10.0, 17.0).toDouble();

    _mapZoom = zoom;
    _animateCameraToPoint(center, zoom: zoom);
  }

  void _tryInitialCameraFocus() {
    if (_hasInitialCameraFocused ||
        widget.gpxPath != null ||
        _isTracking ||
        _lastKnownPoint == null ||
        !_isMapReady) {
      return;
    }

    _hasInitialCameraFocused = true;
    _animateCameraToPoint(_lastKnownPoint!);
  }

  Future<void> _loadUserProfile() async {
    final info = await UserService().fetchUserInfo();
    if (!mounted || info == null) return;

    final weight = (info['weight'] as num?)?.toDouble();
    final height = (info['height'] as num?)?.toDouble();
    final ageRaw = info['age'] ?? info['Age'];
    final age = ageRaw is int ? ageRaw : int.tryParse(ageRaw?.toString() ?? '');

    setState(() {
      if (weight != null && weight > 0) {
        _userWeightKg = weight;
      }
      if (height != null && height > 0) {
        _userHeightCm = height;
      }
      if (age != null && age > 0) {
        _userAge = age;
      }
    });
  }

  ActivityCalculator get _activityCalculator => ActivityCalculator(
        weightKg: _userWeightKg,
        heightCm: _userHeightCm,
        age: _userAge,
      );

  bool get _isWorkoutMetricsActive =>
      !_isGuidedWorkout || _hasReachedWorkoutStart;

  void _resetWorkoutMetricsAtRouteStart() {
    _totalDistance = 0;
    _trackedRoutePoints.clear();
    _elevationGainM = 0;
    _lastElevation = null;
    _workoutStartedAt = DateTime.now();
    _accumulatedPause = Duration.zero;
    _pauseStartedAt = null;
    _isManualPaused = false;
    _isAutoPaused = false;
    _autoPauseCandidateSince = null;
    _autoResumeCandidateSince = null;
    _elapsed = Duration.zero;
    _maxSpeedMs = 0;
    _currentSpeedMs = 0;
    _gpsTrackProcessor.reset();
    _lastAcceptedProjectedMeters = null;
  }

  void _notifyWorkoutUi() {
    widget.onWorkoutUiChanged?.call(
      isActive: _isTracking,
      isFullscreen: isWorkoutFullscreen,
    );
  }

  WorkoutMotionStatus get _motionStatus {
    if (_isWorkoutPaused) return WorkoutMotionStatus.paused;
    if (_currentSpeedMs < 0.3) return WorkoutMotionStatus.stationary;
    return WorkoutMotionStatus.moving;
  }

  void _updateElapsed() {
    if (!_isTracking || _workoutStartedAt == null) {
      _elapsed = Duration.zero;
      return;
    }
    var elapsed = DateTime.now().difference(_workoutStartedAt!);
    elapsed -= _accumulatedPause;
    if (_isWorkoutPaused && _pauseStartedAt != null) {
      elapsed -= DateTime.now().difference(_pauseStartedAt!);
    }
    _elapsed = elapsed.isNegative ? Duration.zero : elapsed;
  }

  double get _currentSpeedKmh => _currentSpeedMs * 3.6;

  double get _avgSpeedKmh {
    if (_elapsed.inSeconds <= 0) return 0;
    return (_totalDistance / 1000) / (_elapsed.inSeconds / 3600);
  }

  double get _calories {
    if (!_isWorkoutMetricsActive) return 0;
    return _activityCalculator.calculateCalories(
      activityType: _selectedActivity,
      duration: _elapsed,
      distanceMeters: _totalDistance,
      avgSpeedKmh: _avgSpeedKmh,
    );
  }

  int get _steps {
    if (!_isWorkoutMetricsActive) return 0;
    return _activityCalculator.estimateStepsByDistance(_totalDistance);
  }

  int get _cadence {
    if (_elapsed.inMinutes <= 0) return 0;
    return (_steps / _elapsed.inMinutes).round();
  }

  bool get _isWorkoutRouteComplete =>
      _isGuidedWorkout &&
      _hasReachedWorkoutStart &&
      _guidedProgress >= _workoutCompleteProgress;

  double get _workoutCompletionPercent {
    if (!_isGuidedWorkout) return 100;

    final routeTracker = _routeProgressTracker;
    if (routeTracker == null) return 100;

    if (!_hasReachedWorkoutStart) {
      final approachTracker = _approachProgressTracker;
      if (approachTracker != null) {
        final total = approachTracker.totalMeters + routeTracker.totalMeters;
        if (total <= 0) return 0;
        return (approachTracker.completedMeters / total * 100).clamp(0, 99);
      }
      return 0;
    }

    return (_guidedProgress * 100).clamp(0, 100);
  }

  bool _isNearFinishPoint(double latitude, double longitude) {
    final points = _getActivePlannedRoutePoints();
    if (points.length < 2) return false;
    final finish = points.last;
    return Geolocator.distanceBetween(
          latitude,
          longitude,
          finish.latitude,
          finish.longitude,
        ) <=
        _workoutStartThresholdM;
  }

  void _checkAutoFinishWorkout(
    double latitude,
    double longitude,
    RouteProgressSnapshot? snapshot,
  ) {
    if (!_isTracking ||
        _isWorkoutPaused ||
        _workoutAutoFinishing ||
        !_isGuidedWorkout ||
        !_hasReachedWorkoutStart) {
      return;
    }

    final progress = snapshot?.progress ?? _guidedProgress;
    if (progress < _workoutCompleteProgress &&
        !_isNearFinishPoint(latitude, longitude)) {
      return;
    }

    _workoutAutoFinishing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isTracking) {
        _workoutAutoFinishing = false;
        return;
      }
      unawaited(_completeWorkout());
    });
  }

  Future<bool> _confirmIncompleteWorkoutSave(double percent) async {
    final percentLabel =
        percent >= 10 ? '${percent.round()}' : percent.toStringAsFixed(1);

    final result = await AppConfirmDialog.show(
      context,
      title: 'Тренировка не завершена',
      message:
          'Вы прошли $percentLabel% маршрута.\n\n'
          'Вы не закончили тренировку. Сохранить результат?',
      cancelLabel: 'Продолжить',
      confirmLabel: 'Сохранить',
      icon: Icons.flag_outlined,
    );

    return result;
  }

  Future<void> _onStopWorkoutPressed() async {
    if (!_isTracking || _isLocked) return;

    if (_isGuidedWorkout && !_isWorkoutRouteComplete) {
      final save = await _confirmIncompleteWorkoutSave(_workoutCompletionPercent);
      if (!mounted || !save) return;
    }

    await _completeWorkout();
  }

  void _startCompassUpdates() {
    _compassStream?.cancel();
    _compassStream = FlutterCompass.events?.listen((event) {
      final heading = event.heading;
      if (heading != null &&
          heading.isFinite &&
          _isMapReady &&
          _currentLocationPlacemark != null) {
        _currentLocationPlacemark!.direction = heading;
      }
    });
  }

  void _mutateState(VoidCallback fn) {
    if (!_appInForeground || !mounted) {
      fn();
      return;
    }

    if (_isTracking) {
      final now = DateTime.now();
      if (_lastTrackingUiUpdate != null &&
          now.difference(_lastTrackingUiUpdate!) < _trackingUiInterval) {
        fn();
        return;
      }
      _lastTrackingUiUpdate = now;
    }

    setState(fn);
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isTabActive != widget.isTabActive) {
      if (widget.isTabActive) {
        _onTabBecameActive();
      } else {
        _onTabBecameInactive();
      }
    }

    if (!oldWidget.isTabActive && widget.isTabActive && _isMapReady) {
      if (_lastKnownPoint != null) {
        _updateCurrentLocationMarker(_lastKnownPoint!, _lastKnownHeading);
      }
      _tryInitialCameraFocus();
      if (_isTracking) {
        _redrawWorkoutRoutes();
      }
      if (_isTracking) {
        setState(_updateElapsed);
      }
    }
  }

  Future<void> _startLocationUpdates({bool refreshCurrentPosition = true}) async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      final requested = await Geolocator.requestPermission();
      if (requested != LocationPermission.always &&
          requested != LocationPermission.whileInUse) {
        if (mounted) AppSnackBar.show(context, 'Нет разрешения на геолокацию');
        return;
      }
    }

    if (_isTracking) {
      final workoutPermission =
          await WorkoutLocationSettings.ensureWorkoutPermission();
      if (!workoutPermission) {
        if (mounted) {
          AppSnackBar.show(
            context,
            'Для тренировки с выключенным экраном разрешите доступ к геолокации',
          );
        }
      }
    }

    await _restartLocationStream(refreshCurrentPosition: refreshCurrentPosition);
  }

  LocationSettings get _locationSettings => _isTracking
      ? WorkoutLocationSettings.forTracking()
      : WorkoutLocationSettings.forIdle();

  Future<void> _restartLocationStream({
    required bool refreshCurrentPosition,
  }) async {
    _positionStream?.cancel();
    _positionStream = null;

    if (refreshCurrentPosition) {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: _locationSettings,
        );
        if (mounted) {
          _lastKnownPoint = Point(
            latitude: position.latitude,
            longitude: position.longitude,
          );
          _lastKnownHeading = position.heading;
          if (_isMapReady) {
            _updateCurrentLocationMarker(_lastKnownPoint!, _lastKnownHeading);
          }
          _tryInitialCameraFocus();
        }
      } catch (_) {}
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: _locationSettings,
    ).listen(_handlePositionUpdate);
  }

  void _handlePositionUpdate(Position position) {
      final point =
          Point(latitude: position.latitude, longitude: position.longitude);
      _lastKnownPoint = point;
      _lastKnownHeading = position.heading;
      if (_isMapReady) {
        _updateCurrentLocationMarker(point, position.heading);
      }

      if (!_isTracking) {
        _tryInitialCameraFocus();
      }

      if (!_isTracking &&
          _routePoints.length == 1 &&
          !_hasPlannedRouteGeometry()) {
        _onRouteParametersUpdated();
      }

      if (!_isTracking) return;

      _mutateState(() {
        _currentSpeedMs = position.speed >= 0 ? position.speed : 0;
        if (_currentSpeedMs > _maxSpeedMs) _maxSpeedMs = _currentSpeedMs;

        if (_isWorkoutMetricsActive) {
          final ele = position.altitude;
          if (_lastElevation != null && ele > _lastElevation!) {
            _elevationGainM += ele - _lastElevation!;
          }
          _lastElevation = ele;
        }
      });

      final speedMs = (position.speed >= 0 ? position.speed : 0).toDouble();
      _evaluateAutoPause(speedMs);

      if (_isWorkoutPaused) return;

      RouteProgressSnapshot? guidedProgress;
      PathSnapResult? routeSnap;
      if (_isGuidedWorkout && _routeProgressTracker != null) {
        if (_routePoints.length >= 2 && !_hasReachedWorkoutStart) {
          final distToStart = Geolocator.distanceBetween(
            point.latitude,
            point.longitude,
            _routePoints.first.latitude,
            _routePoints.first.longitude,
          );

          if (distToStart <= _workoutStartThresholdM) {
            _mutateState(() {
              _hasReachedWorkoutStart = true;
              _approachRoutePoints = null;
              _approachProgressTracker = null;
              _resetWorkoutMetricsAtRouteStart();
            });
            _redrawWorkoutRoutes();
            guidedProgress = _routeProgressTracker!.update(
              point.latitude,
              point.longitude,
            );
            routeSnap = _routeProgressTracker!.lastPathSnap;
          } else if (_approachProgressTracker != null) {
            final approachProgress = _approachProgressTracker!.update(
              point.latitude,
              point.longitude,
            );
            routeSnap = _approachProgressTracker!.lastPathSnap;
            guidedProgress = RouteProgressSnapshot(
              totalMeters: approachProgress.totalMeters +
                  _routeProgressTracker!.totalMeters,
              completedMeters: approachProgress.completedMeters,
              remainingMeters: approachProgress.remainingMeters +
                  _routeProgressTracker!.totalMeters,
              progress: 0,
              isOffRoute: approachProgress.isOffRoute,
              offRouteDistanceM: approachProgress.offRouteDistanceM,
            );
          } else {
            guidedProgress = RouteProgressSnapshot(
              totalMeters: distToStart + _routeProgressTracker!.totalMeters,
              completedMeters: 0,
              remainingMeters: distToStart + _routeProgressTracker!.totalMeters,
              progress: 0,
              isOffRoute: false,
              offRouteDistanceM: 0,
            );
          }
        } else {
          guidedProgress = _routeProgressTracker!.update(
            point.latitude,
            point.longitude,
          );
          routeSnap = _routeProgressTracker!.lastPathSnap;
        }
      }

      final acceptResults = _isWorkoutMetricsActive
          ? _gpsTrackProcessor.acceptTrackPoints(
              position: position,
              routeSnap: routeSnap,
              preferRouteSnap: _isGuidedWorkout,
              routeGapPoints: _routeGapPointsForPosition(routeSnap),
            )
          : const <GpsTrackAcceptResult>[];
      final progressSnapshot = guidedProgress;

      if (acceptResults.isNotEmpty || progressSnapshot != null) {
        _mutateState(() {
          for (final acceptResult in acceptResults) {
            _totalDistance += acceptResult.addedDistanceM;
            _trackedRoutePoints.add(acceptResult.trackPoint);
          }

          if (progressSnapshot != null) {
            _guidedRemainingM = progressSnapshot.remainingMeters;
            _guidedProgress = progressSnapshot.progress;
            _isOffRoute = progressSnapshot.isOffRoute;
            if (routeSnap != null && !routeSnap.isOffRoute) {
              _lastAcceptedProjectedMeters = routeSnap.projectedMeters;
            }
          }
        });

        if (acceptResults.isNotEmpty) {
          _redrawWorkoutRoutes();
        }
      }

      if (progressSnapshot != null) {
        _checkAutoFinishWorkout(
          point.latitude,
          point.longitude,
          progressSnapshot,
        );
      }

      if (acceptResults.isNotEmpty && _isMapReady && !_isMinimized) {
        final trackedPoint = acceptResults.last.trackPoint;
        _mapWindow!.map.move(
          CameraPosition(
            Point(
              latitude: trackedPoint.latitude,
              longitude: trackedPoint.longitude,
            ),
            zoom: _mapZoom,
            azimuth: 0,
            tilt: 0,
          ),
        );
      }
  }

  List<Point>? _routeGapPointsForPosition(PathSnapResult? routeSnap) {
    if (!_isGuidedWorkout ||
        _routeProgressTracker == null ||
        routeSnap == null ||
        routeSnap.isOffRoute ||
        _lastAcceptedProjectedMeters == null) {
      return null;
    }

    final from = _lastAcceptedProjectedMeters!;
    final to = routeSnap.projectedMeters;
    if (to <= from + 5) return null;

    return _routeProgressTracker!.collectPathPointsBetween(from, to);
  }

  void _updateCurrentLocationMarker(Point point, double? heading) {
    final collection = _userLocationCollection;
    final markerIcon = _locationMarkerProvider;
    if (!_isMapReady || collection == null || markerIcon == null) return;

    if (_currentLocationPlacemark != null) {
      collection.remove(_currentLocationPlacemark!);
    }

    final direction = (heading != null && heading.isFinite) ? heading : 0.0;

    _currentLocationPlacemark = collection.addPlacemark()
      ..geometry = point
      ..direction = direction;

    _currentLocationPlacemark!
      ..setIcon(markerIcon)
      ..setIconStyle(const IconStyle(
        scale: MapLocationMarkerIcon.mapScale,
        rotationType: RotationType.Rotate,
        zIndex: 100,
      ));
    _currentLocationPlacemark!.visible = true;
  }

  List<Point> _getActivePlannedRoutePoints() {
    if (_savedRouteTrackPoints != null && _savedRouteTrackPoints!.length >= 2) {
      return List<Point>.from(_savedRouteTrackPoints!);
    }

    final geometry = _getActivePlannedRouteGeometry();
    if (geometry != null && geometry.points.isNotEmpty) {
      return List<Point>.from(geometry.points);
    }

    if (_routePoints.length >= 2) {
      return List<Point>.from(_routePoints);
    }

    return const [];
  }

  Polyline? _getActivePlannedRouteGeometry() {
    switch (_currentRoutingType) {
      case RoutingType.pedestrian:
        if (_pedestrianRoutes.isNotEmpty) {
          return _pedestrianRoutes.first.geometry;
        }
        break;
      case RoutingType.publicTransport:
        if (_publicTransportRoutes.isNotEmpty) {
          return _publicTransportRoutes.first.geometry;
        }
        break;
    }
    return null;
  }

  bool _hasPlannedRouteGeometry() => _getActivePlannedRouteGeometry() != null;

  List<RequestPoint>? _buildRoutingRequestPoints() {
    if (_routePoints.isEmpty) return null;

    if (_routePoints.length == 1) {
      if (_lastKnownPoint == null) return null;
      return [
        RequestPoint(
          _lastKnownPoint!,
          RequestPointType.Waypoint,
          null,
          null,
          null,
        ),
        RequestPoint(
          _routePoints.first,
          RequestPointType.Waypoint,
          null,
          null,
          null,
        ),
      ];
    }

    return [
      RequestPoint(
        _routePoints.first,
        RequestPointType.Waypoint,
        null,
        null,
        null,
      ),
      ..._routePoints
          .sublist(1, _routePoints.length - 1)
          .map(
            (p) => RequestPoint(p, RequestPointType.Viapoint, null, null, null),
          ),
      RequestPoint(
        _routePoints.last,
        RequestPointType.Waypoint,
        null,
        null,
        null,
      ),
    ];
  }

  void _cancelApproachRouteRequest() {
    _approachPedestrianSession?.cancel();
    _approachPublicTransportSession?.cancel();
    _approachPedestrianSession = null;
    _approachPublicTransportSession = null;
  }

  void _clearApproachRoute() {
    _cancelApproachRouteRequest();
    _approachRoutePoints = null;
    _approachProgressTracker = null;
  }

  void _onApproachRouteResolved(List<Point> points) {
    if (points.length < 2) return;

    setState(() {
      _approachRoutePoints = List<Point>.from(points);
      _approachProgressTracker = RouteProgressTracker(_approachRoutePoints!);
    });

    if (_isTracking) {
      _redrawWorkoutRoutes();
    }
  }

  void _requestApproachRoute() {
    if (_lastKnownPoint == null || _routePoints.isEmpty) return;
    if (!_routersReady) {
      unawaited(_ensureRoutersReady().then((_) {
        if (mounted) _requestApproachRoute();
      }));
      return;
    }

    final distToStart = Geolocator.distanceBetween(
      _lastKnownPoint!.latitude,
      _lastKnownPoint!.longitude,
      _routePoints.first.latitude,
      _routePoints.first.longitude,
    );
    if (distToStart <= _workoutStartThresholdM) return;

    _cancelApproachRouteRequest();

    final points = [
      RequestPoint(
        _lastKnownPoint!,
        RequestPointType.Waypoint,
        null,
        null,
        null,
      ),
      RequestPoint(
        _routePoints.first,
        RequestPointType.Waypoint,
        null,
        null,
        null,
      ),
    ];

    try {
      switch (_currentRoutingType) {
        case RoutingType.pedestrian:
          _approachPedestrianSession = _pedestrianRouter.requestRoutes(
            const TimeOptions(),
            const RouteOptions(FitnessOptions(avoidSteep: false)),
            _approachPedestrianRouteListener,
            points: points,
          );
          break;
        case RoutingType.publicTransport:
          _approachPublicTransportSession =
              _publicTransportRouter.requestRoutes(
            const TransitOptions(TimeOptions()),
            const RouteOptions(FitnessOptions(avoidSteep: false)),
            _approachPublicTransportRouteListener,
            points: points,
          );
          break;
      }
    } catch (_) {}
  }

  void _redrawWorkoutRoutes() {
    final routes = _routesCollection;
    if (!_isMapReady || routes == null) return;
    routes.clear();

    if (_approachRoutePoints != null &&
        _approachRoutePoints!.length >= 2 &&
        !_hasReachedWorkoutStart) {
      routes
          .addPolylineWithGeometry(Polyline(_approachRoutePoints!))
          .applyAlternativeRouteStyle();
    }

    if (_isGuidedWorkout && _routeProgressTracker != null) {
      final planned = Polyline(_routeProgressTracker!.pathPoints);
      routes.addPolylineWithGeometry(planned).applyMainRouteStyle();
    }

    if (_trackedRoutePoints.length < 2) {
      _scheduleMapRefresh();
      return;
    }

    final tracked = Polyline(
      _trackedRoutePoints
          .map((p) => Point(latitude: p.latitude, longitude: p.longitude))
          .toList(),
    );
    routes.addPolylineWithGeometry(tracked).applyTrackedWorkoutPathStyle();

    if (_trackedRoutePoints.isNotEmpty) {
      final first = _trackedRoutePoints.first;
      final start = Point(
        latitude: first.latitude,
        longitude: first.longitude,
      );
      Point? finish;
      if (_isGuidedWorkout &&
          _routeProgressTracker != null &&
          _routeProgressTracker!.pathPoints.isNotEmpty) {
        finish = _routeProgressTracker!.pathPoints.last;
      } else if (_trackedRoutePoints.length >= 2) {
        final last = _trackedRoutePoints.last;
        finish = Point(
          latitude: last.latitude,
          longitude: last.longitude,
        );
      }
      _setRouteEndpointMarkers(start: start, finish: finish);
    }

    _scheduleMapRefresh();
  }

  void startTracking() => _startTracking();

  void _startTracking() {
    _sensorPauseTimer?.cancel();
    if (_routePoints.isEmpty) {
      AppSnackBar.show(context, 'Поставьте точку на карте');
      return;
    }

    if (_routePoints.length == 1 && _lastKnownPoint != null) {
      _onRouteParametersUpdated();
    }

    final plannedPoints = _getActivePlannedRoutePoints();
    if (plannedPoints.length < 2) {
      AppSnackBar.show(
        context,
        _routePoints.length == 1
            ? 'Дождитесь построения маршрута от вас до точки'
            : 'Поставьте точки на карте и дождитесь построения маршрута',
      );
      return;
    }

    final tracker = RouteProgressTracker(plannedPoints);
    final needsApproach = _routePoints.length >= 2 && _lastKnownPoint != null;
    final distToStart = needsApproach
        ? Geolocator.distanceBetween(
            _lastKnownPoint!.latitude,
            _lastKnownPoint!.longitude,
            _routePoints.first.latitude,
            _routePoints.first.longitude,
          )
        : 0.0;
    final reachedStart = !needsApproach || distToStart <= _workoutStartThresholdM;
    final initialRemaining = reachedStart
        ? tracker.totalMeters
        : distToStart + tracker.totalMeters;

    setState(() {
      _isTracking = true;
      _isGuidedWorkout = true;
      _routeProgressTracker = tracker;
      _hasReachedWorkoutStart = reachedStart;
      _guidedRemainingM = initialRemaining;
      _guidedProgress = 0;
      _isOffRoute = false;
      _isMinimized = false;
      _isLocked = false;
      _isManualPaused = false;
      _isAutoPaused = false;
      _autoPauseCandidateSince = null;
      _autoResumeCandidateSince = null;
      _trackedRoutePoints.clear();
      _totalDistance = 0.0;
      _currentSpeedMs = 0.0;
      _maxSpeedMs = 0.0;
      _elevationGainM = 0.0;
      _lastElevation = null;
      _workoutStartedAt = reachedStart ? DateTime.now() : null;
      _accumulatedPause = Duration.zero;
      _pauseStartedAt = null;
      _elapsed = Duration.zero;
      _approachRoutePoints = null;
      _approachProgressTracker = null;
      _workoutAutoFinishing = false;
    });

    _gpsTrackProcessor.reset();
    _lastAcceptedProjectedMeters = null;
    if (_sensorsActive) {
      unawaited(
        _restartLocationStream(refreshCurrentPosition: false),
      );
    } else {
      _sensorsActive = true;
      unawaited(
        _startLocationUpdates(refreshCurrentPosition: false),
      );
    }

    if (!reachedStart) {
      _requestApproachRoute();
    }
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isTracking) return;
      _updateElapsed();
      if (widget.isTabActive && _appInForeground) {
        setState(() {});
      }
    });
    _redrawWorkoutRoutes();
    _notifyWorkoutUi();
  }

  void minimizeWorkout() {
    if (!_isTracking) return;
    setState(() => _isMinimized = true);
    _notifyWorkoutUi();
  }

  void expandWorkout() {
    if (!_isTracking) return;
    setState(() => _isMinimized = false);
    _notifyWorkoutUi();
  }

  void handleAppLifecycleResume() {
    if (!mounted) return;
    setState(() {});
    _notifyWorkoutUi();
    if (_lastKnownPoint != null) {
      _updateCurrentLocationMarker(_lastKnownPoint!, _lastKnownHeading);
    }
    if (_isTracking) {
      _redrawWorkoutRoutes();
      if (_sensorsActive) {
        unawaited(
          _restartLocationStream(refreshCurrentPosition: false),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _appInForeground;
    _appInForeground = state == AppLifecycleState.resumed;
    if (!wasForeground && _appInForeground) {
      handleAppLifecycleResume();
    }
  }

  WorkoutSessionData _buildSessionData() {
    _updateElapsed();
    return WorkoutSessionData(
      points: List<TrackPoint>.from(_trackedRoutePoints),
      distanceMeters: _totalDistance,
      duration: _elapsed,
      elevationGainM: _elevationGainM,
      calories: _calories,
      activityType: _selectedActivity,
      startedAt: _workoutStartedAt ?? DateTime.now(),
      avgSpeedKmh: _avgSpeedKmh,
      currentSpeedKmh: _currentSpeedKmh,
    );
  }

  Future<void> _completeWorkout() async {
    if (!_isTracking) return;
    _tickTimer?.cancel();
    final session = _buildSessionData();

    setState(() {
      _isTracking = false;
      _isGuidedWorkout = false;
      _routeProgressTracker = null;
      _hasReachedWorkoutStart = true;
      _guidedRemainingM = 0;
      _guidedProgress = 0;
      _isOffRoute = false;
      _isMinimized = false;
      _isLocked = false;
      _isManualPaused = false;
      _isAutoPaused = false;
      _autoPauseCandidateSince = null;
      _autoResumeCandidateSince = null;
      _workoutAutoFinishing = false;
    });
    _clearApproachRoute();
    _notifyWorkoutUi();
    _lastAcceptedProjectedMeters = null;
    if (_sensorsActive) {
      unawaited(
        _restartLocationStream(refreshCurrentPosition: false),
      );
    } else {
      _syncSensorsState();
    }

    if (session.points.length < 2) {
      setState(() {
        _trackedRoutePoints.clear();
        _totalDistance = 0;
      });
      AppSnackBar.show(context, 'Слишком короткая тренировка для сохранения');
      return;
    }

    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => SaveWorkoutPage(
          session: session,
          onWorkoutSaved: widget.onWorkoutSaved,
        ),
      ),
    );

    setState(() {
      _trackedRoutePoints.clear();
      _totalDistance = 0;
      _elapsed = Duration.zero;
      _routesCollection?.clear();
    });
  }

  void _toggleManualPause() {
    if (!_isTracking || _isLocked) return;
    setState(() {
      if (_isManualPaused) {
        if (_pauseStartedAt != null) {
          _accumulatedPause += DateTime.now().difference(_pauseStartedAt!);
        }
        _pauseStartedAt = null;
        _isManualPaused = false;
        _isAutoPaused = false;
        _autoPauseCandidateSince = null;
        _autoResumeCandidateSince = null;
      } else {
        _isAutoPaused = false;
        _autoPauseCandidateSince = null;
        _autoResumeCandidateSince = null;
        _pauseStartedAt = DateTime.now();
        _isManualPaused = true;
      }
    });
  }

  void _centerCameraOnCurrentLocation() {
    if (_currentLocationPlacemark == null || _mapWindow == null) {
      AppSnackBar.show(context, 'Местоположение недоступно');
      return;
    }
    _animateCameraToPoint(_currentLocationPlacemark!.geometry);
  }

  void _adjustZoom(double delta) {
    if (_mapWindow == null) return;
    final current = _mapWindow!.map.cameraPosition;
    final newZoom = (current.zoom + delta).clamp(3.0, 20.0);
    _mapZoom = newZoom;
    _mapWindow!.map.move(
      CameraPosition(
        current.target,
        zoom: newZoom,
        azimuth: current.azimuth,
        tilt: current.tilt,
      ),
      animation: _initialCameraAnimation,
    );
  }

  void _createMapObjects(MapWindow mapWindow) {
    _mapWindow = mapWindow;
    mapWindow.map.move(GeometryProvider.startPosition);
    mapWindow.map.addInputListener(_inputListener);
    _placemarksCollection = mapWindow.map.mapObjects.addCollection();
    _routesCollection = mapWindow.map.mapObjects.addCollection();
    _userLocationCollection = mapWindow.map.mapObjects.addCollection();

    if (widget.gpxPath != null) {
      GeometryProvider.loadAndParseGPX(widget.gpxPath!).then((points) {
        if (!mounted) return;
        setState(() => _routePoints = points);
        _onRouteParametersUpdated();
      });
    } else if (_routePoints.isNotEmpty) {
      _onRouteParametersUpdated();
    }

    if (_isTracking) {
      _redrawWorkoutRoutes();
    }

    if (_lastKnownPoint != null) {
      _updateCurrentLocationMarker(_lastKnownPoint!, _lastKnownHeading);
      _tryInitialCameraFocus();
    }
    _ensureCompassActive();
  }

  void _onRouteParametersUpdated() {
    if (!_isMapReady) return;
    if (!_routersReady) {
      unawaited(_ensureRoutersReady().then((_) {
        if (mounted) _onRouteParametersUpdated();
      }));
      return;
    }

    final placemarks = _placemarksCollection;
    final routes = _routesCollection;
    if (placemarks == null || routes == null) return;

    if (_isTracking) {
      _redrawWorkoutRoutes();
      _scheduleMapRefresh();
      return;
    }

    _pedestrianSession?.cancel();
    _publicTransportSession?.cancel();
    _pedestrianSession = null;
    _publicTransportSession = null;

    _discardRouteEndpointMarkers();
    placemarks.clear();
    routes.clear();

    if (_routePoints.isEmpty) {
      _scheduleMapRefresh();
      return;
    }

    if (_savedRouteTrackPoints != null &&
        _savedRouteTrackPoints!.length >= 2 &&
        !_isTracking) {
      _setRouteEndpointMarkers(
        start: _savedRouteTrackPoints!.first,
        finish: _savedRouteTrackPoints!.last,
      );

      routes
          .addPolylineWithGeometry(Polyline(_savedRouteTrackPoints!))
          .applyMainRouteStyle();
      _scheduleMapRefresh();
      return;
    }

    _routePoints.forEachIndexed((index, point) {
      final isFinish =
          _routePoints.length == 1 || index == _routePoints.length - 1;
      final isStart = index == 0;
      if (isStart || isFinish) return;
      if (_hideMapEndpoints) return;

      final placemark = placemarks.addPlacemark()..geometry = point;
      placemark.setIcon(_resolveStartMarkerProvider());
      placemark.setIconStyle(
        const IconStyle(
          scale: MapRouteMarkerIcons.startIconScale * 0.7,
          zIndex: 18,
        ),
      );
    });

    if (_routePoints.length >= 1) {
      _setRouteEndpointMarkers(
        start: _routePoints.first,
        finish: _routePoints.length >= 2 ? _routePoints.last : null,
      );
    }

    final points = _buildRoutingRequestPoints();
    if (points == null) {
      if (_routePoints.length == 1 && mounted) {
        AppSnackBar.show(context, 'Ожидание GPS для построения маршрута');
      }
      _scheduleMapRefresh();
      return;
    }

    try {
      switch (_currentRoutingType) {
        case RoutingType.pedestrian:
          _pedestrianSession = _pedestrianRouter.requestRoutes(
            const TimeOptions(),
            const RouteOptions(FitnessOptions(avoidSteep: false)),
            _pedestrianRouteListener,
            points: points,
          );
          break;
        case RoutingType.publicTransport:
          _publicTransportSession = _publicTransportRouter.requestRoutes(
            const TransitOptions(TimeOptions()),
            const RouteOptions(FitnessOptions(avoidSteep: false)),
            _publicTransportRouteListener,
            points: points,
          );
          break;
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, 'Не удалось построить маршрут');
      }
    }
    _scheduleMapRefresh();
  }

  void _onPedestrianRoutesUpdated() {
    if (_isTracking || !_isMapReady) return;
    _routesCollection!.clear();
    for (var i = 0; i < _pedestrianRoutes.length; i++) {
      _createPolylineWithStyle(i, _pedestrianRoutes[i].geometry);
    }
    if (_pedestrianRoutes.isNotEmpty) {
      final points = _pedestrianRoutes.first.geometry.points;
      if (points.length >= 2) {
        _setRouteEndpointMarkers(start: points.first, finish: points.last);
      }
    }
    _scheduleMapRefresh();
  }

  void _onPublicTransportRoutesUpdated() {
    if (_isTracking || !_isMapReady) return;
    _routesCollection!.clear();
    for (var i = 0; i < _publicTransportRoutes.length; i++) {
      _createPolylineWithStyle(i, _publicTransportRoutes[i].geometry);
    }
    if (_publicTransportRoutes.isNotEmpty) {
      final points = _publicTransportRoutes.first.geometry.points;
      if (points.length >= 2) {
        _setRouteEndpointMarkers(start: points.first, finish: points.last);
      }
    }
    _scheduleMapRefresh();
  }

  void _createPolylineWithStyle(int routeIndex, Polyline geometry) {
    final routes = _routesCollection;
    if (routes == null) return;
    final polyline = routes.addPolylineWithGeometry(geometry);
    routeIndex == 0
        ? polyline.applyMainRouteStyle()
        : polyline.applyAlternativeRouteStyle();
  }

  void _openMetricsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.3,
        maxChildSize: 0.75,
        expand: false,
        builder: (_, controller) => WorkoutMetricsSheet(
          avgSpeedKmh: _avgSpeedKmh,
          maxSpeedKmh: _maxSpeedMs * 3.6,
          steps: _steps,
          cadence: _cadence,
          ascentRate: _elapsed.inHours > 0
              ? _elevationGainM / _elapsed.inHours
              : _elevationGainM,
          activityLabel: _selectedActivity.labelRu,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showWorkoutUi = widget.isTabActive && _isTracking && !_isMinimized;
    final bottomPad = showWorkoutUi ? 0.0 : widget.bottomNavPadding;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_mapSurfaceMounted)
          Offstage(
            offstage: !widget.isTabActive,
            child: TickerMode(
              enabled: widget.isTabActive,
              child: RepaintBoundary(
                child: FlutterMapWidget(
                  onMapCreated: _createMapObjects,
                  onMapDispose: () {
                    _mapWindow?.map.removeInputListener(_inputListener);
                    _mapWindow = null;
                    _userLocationCollection = null;
                    _placemarksCollection = null;
                    _routesCollection = null;
                    _currentLocationPlacemark = null;
                  },
                ),
              ),
            ),
          )
        else
          const ColoredBox(color: Color(0xFFF2F5F7)),
        if (showWorkoutUi)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color.fromARGB(255, 0, 0, 0).withValues(alpha: 0.15),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
          ),
        if (widget.isTabActive && !_isTracking)
          Positioned.fill(
            child: MapIdleOverlay(
              selectedActivity: _selectedActivity,
              onActivitySelected: (t) => setState(() => _selectedActivity = t),
              onStartWorkout: _startTracking,
              onCenterLocation: _centerCameraOnCurrentLocation,
              onZoomIn: () => _adjustZoom(1),
              onZoomOut: () => _adjustZoom(-1),
              onClearRoutes: () {
                setState(() {
                  _routePoints = [];
                  _savedRouteTrackPoints = null;
                });
                _clearApproachRoute();
                AppSnackBar.show(context, 'Все маршруты очищены');
                _onRouteParametersUpdated();
              },
              onSwitchRoutingType: () {
                setState(() {
                  _currentRoutingType = RoutingType.values[
                      (_currentRoutingType.index + 1) %
                          RoutingType.values.length];
                });
                _onRouteParametersUpdated();
              },
              bottomPadding: bottomPad,
              addressSearchService: _addressSuggestService,
              getSearchBounds: _getSearchBoundingBox,
              getUserPosition: () => _lastKnownPoint,
              onAddressSelected: _onAddressSelected,
              onStartAddressSelected: _onStartAddressSelected,
              onEndAddressSelected: _onEndAddressSelected,
            ),
          )
        else if (widget.isTabActive && _isMinimized)
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomPad + 8,
            child: Material(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              elevation: 4,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: expandWorkout,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(_selectedActivity.icon,
                          color: MapUiColors.primaryGreen),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatWorkoutDuration(_elapsed),
                              style: mapMetricValueStyle(size: 18),
                            ),
                            Text(
                              _isGuidedWorkout
                                  ? 'Осталось ${formatDistanceKm(_guidedRemainingM)} км • ${_currentSpeedKmh.toStringAsFixed(1)} км/ч'
                                  : '${formatDistanceKm(_totalDistance)} км • ${_currentSpeedKmh.toStringAsFixed(1)} км/ч',
                              style: mapMetricLabelStyle(),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.open_in_full_rounded),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (showWorkoutUi)
          MapWorkoutOverlay(
            speedKmh: _currentSpeedKmh,
            distanceKm: _totalDistance / 1000,
            duration: _elapsed,
            calories: _calories,
            elevationM: _elevationGainM,
            motionStatus: _motionStatus,
            isGuided: _isGuidedWorkout,
            routeRemainingKm: _guidedRemainingM / 1000,
            routeProgress: _guidedProgress,
            isOffRoute: _isOffRoute,
            isLocked: _isLocked,
            isManualPaused: _isWorkoutPaused,
            onStop: _onStopWorkoutPressed,
            onStatusTap: _toggleManualPause,
            onToggleLock: () => setState(() => _isLocked = !_isLocked),
            onMinimize: minimizeWorkout,
            onSwipeUpHint: _openMetricsSheet,
            metricsSheetProgress: 0,
          ),
      ],
    );
  }
}

enum _RouteAddressRole {
  destination,
  start,
  end,
}
