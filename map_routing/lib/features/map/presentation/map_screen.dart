import 'package:collection/collection.dart';
import 'package:common/listeners/map_input_listener.dart';
import 'package:common/map/flutter_map_widget.dart';
import 'package:common/utils/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:map_routing/data/activity_calculator.dart';
import 'package:map_routing/data/geometry_provider.dart';
import 'package:map_routing/data/models/track_point.dart';
import 'package:map_routing/data/models/workout_activity_type.dart';
import 'package:map_routing/data/models/workout_session_data.dart';
import 'package:map_routing/data/route_progress_tracker.dart';
import 'package:map_routing/data/routing_type.dart';
import 'package:map_routing/data/services/user_service.dart';
import 'package:map_routing/features/map/presentation/map_ui_styles.dart';
import 'package:map_routing/features/map/presentation/save_workout_page.dart';
import 'package:map_routing/features/map/presentation/widgets/map_idle_overlay.dart';
import 'package:map_routing/features/map/presentation/widgets/map_location_marker_icon.dart';
import 'package:map_routing/features/map/presentation/widgets/map_workout_overlay.dart';
import 'package:map_routing/features/map/presentation/widgets/workout_metrics_sheet.dart';
import 'package:map_routing/shared/utils/polyline_extensions.dart';
import 'package:geolocator/geolocator.dart';
import 'package:yandex_maps_mapkit/directions.dart';
import 'package:yandex_maps_mapkit/image.dart' as image_provider;
import 'package:yandex_maps_mapkit/mapkit.dart' hide LocationSettings;
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
  var _drivingRoutes = <DrivingRoute>[];
  var _pedestrianRoutes = <MasstransitRoute>[];
  var _publicTransportRoutes = <MasstransitRoute>[];
  var _currentRoutingType = RoutingType.driving;

  PlacemarkMapObject? _currentLocationPlacemark;
  image_provider.ImageProvider? _locationMarkerProvider;

  bool _isTracking = false;
  bool _isMinimized = false;
  bool _isLocked = false;
  bool _isManualPaused = false;
  StreamSubscription<Position>? _positionStream;
  final List<TrackPoint> _trackedRoutePoints = [];

  double _totalDistance = 0.0;
  double _currentSpeedMs = 0.0;
  double _maxSpeedMs = 0.0;
  double _elevationGainM = 0.0;
  double? _lastElevation;
  double _userWeightKg = 70;
  double _mapZoom = 16;

  WorkoutActivityType _selectedActivity = WorkoutActivityType.run;
  DateTime? _workoutStartedAt;
  Duration _accumulatedPause = Duration.zero;
  DateTime? _pauseStartedAt;
  Timer? _tickTimer;
  Duration _elapsed = Duration.zero;
  final DraggableScrollableController _metricsSheetController =
      DraggableScrollableController();

  RouteProgressTracker? _routeProgressTracker;
  bool _isGuidedWorkout = false;
  double _guidedRemainingM = 0;
  double _guidedProgress = 0;
  bool _isOffRoute = false;

  late final DrivingRouter _drivingRouter;
  late final PedestrianRouter _pedestrianRouter;
  late final MasstransitRouter _publicTransportRouter;

  StreamSubscription<CompassEvent>? _compassStream;

  DrivingSession? _drivingSession;
  MasstransitSession? _pedestrianSession;
  MasstransitSession? _publicTransportSession;

  bool get isTrackingActive => _isTracking;
  bool get isWorkoutFullscreen => _isTracking && !_isMinimized;

  bool get _isMapReady =>
      _mapWindow != null &&
      _userLocationCollection != null &&
      _routesCollection != null &&
      _placemarksCollection != null &&
      widget.isTabActive;

  late final pointImageProvider =
      image_provider.ImageProvider.fromImageProvider(
          const AssetImage('assets/start_point.png'));

  late final finishPointImageProvider =
      image_provider.ImageProvider.fromImageProvider(
          const AssetImage('assets/ic_finish_point.png'));

  late final _inputListener = MapInputListenerImpl(
    onMapTapCallback: (_, __) {},
    onMapLongTapCallback: (map, point) {
      if (_isTracking || !_isMapReady) return;

      _routePoints = [..._routePoints, point];
      final isFirstPoint = _routePoints.length == 1;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (isFirstPoint) {
          showSnackBar(context, 'Старт маршрута. Поставьте финишную точку');
        } else if (_routePoints.length == 2) {
          showSnackBar(context, 'Маршрут готов. Нажмите ▶ для старта тренировки');
        }
        setState(() {});
        _onRouteParametersUpdated();
      });
    },
  );

  late final _drivingRouteListener = DrivingSessionRouteListener(
    onDrivingRoutes: (newRoutes) {
      if (newRoutes.isEmpty) {
        showSnackBar(context, 'Не возможно построить маршрут');
      }
      setState(() => _drivingRoutes = newRoutes);
      _onDrivingRoutesUpdated();
    },
    onDrivingRoutesError: (error) {
      showSnackBar(context, 'Ошибка построения маршрута (авто)');
    },
  );

  late final _pedestrianRouteListener = RouteHandler(
    onMasstransitRoutes: (newRoutes) {
      if (newRoutes.isEmpty) {
        showSnackBar(context, 'Не удалось построить маршрут');
      }
      setState(() => _pedestrianRoutes = newRoutes);
      _onPedestrianRoutesUpdated();
    },
    onMasstransitRoutesError: (error) {
      showSnackBar(context, 'Ошибка построения маршрута (пешком)');
    },
  );

  late final _publicTransportRouteListener = RouteHandler(
    onMasstransitRoutes: (newRoutes) {
      if (newRoutes.isEmpty) {
        showSnackBar(context, 'Не удалось построить маршрут');
      }
      setState(() => _publicTransportRoutes = newRoutes);
      _onPublicTransportRoutesUpdated();
    },
    onMasstransitRoutesError: (error) {
      showSnackBar(context, 'Ошибка построения маршрута (транспорт)');
    },
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _drivingRouter = DirectionsFactory.instance
        .createDrivingRouter(DrivingRouterType.Combined);
    _pedestrianRouter = TransportFactory.instance.createPedestrianRouter();
    _publicTransportRouter =
        TransportFactory.instance.createMasstransitRouter();
    _loadUserWeight();
    _loadLocationMarkerIcon();
    _startLocationUpdates();
    _startCompassUpdates();
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionStream?.cancel();
    _compassStream?.cancel();
    _tickTimer?.cancel();
    _metricsSheetController.dispose();
    _drivingSession?.cancel();
    _pedestrianSession?.cancel();
    _publicTransportSession?.cancel();
    super.dispose();
  }

  Future<void> _loadUserWeight() async {
    final info = await UserService().fetchUserInfo();
    final weight = (info?['weight'] as num?)?.toDouble();
    if (weight != null && weight > 0 && mounted) {
      setState(() => _userWeightKg = weight);
    }
  }

  void _notifyWorkoutUi() {
    widget.onWorkoutUiChanged?.call(
      isActive: _isTracking,
      isFullscreen: isWorkoutFullscreen,
    );
  }

  WorkoutMotionStatus get _motionStatus {
    if (_isManualPaused) return WorkoutMotionStatus.paused;
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
    if (_isManualPaused && _pauseStartedAt != null) {
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
    final calculator = ActivityCalculator(weightKg: _userWeightKg);
    return calculator.calculateWalkingCalories(
      distanceMeters: _totalDistance,
      met: _selectedActivity.met,
      averageSpeedKmH: _avgSpeedKmh > 0 ? _avgSpeedKmh : 5,
    );
  }

  int get _steps => ActivityCalculator(weightKg: _userWeightKg)
      .estimateStepsByDistance(_totalDistance);

  int get _cadence {
    if (_elapsed.inMinutes <= 0) return 0;
    return (_steps / _elapsed.inMinutes).round();
  }

  void _startCompassUpdates() {
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
    if (!oldWidget.isTabActive && widget.isTabActive && _isMapReady) {
      if (_lastKnownPoint != null) {
        _updateCurrentLocationMarker(_lastKnownPoint!, _lastKnownHeading);
      }
      if (_isTracking) {
        _redrawWorkoutRoutes();
      }
      if (_isTracking) {
        setState(_updateElapsed);
      }
    }
  }

  void _startLocationUpdates() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      final requested = await Geolocator.requestPermission();
      if (requested != LocationPermission.always &&
          requested != LocationPermission.whileInUse) {
        if (mounted) showSnackBar(context, 'Нет разрешения на геолокацию');
        return;
      }
    }

    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: _isTracking ? 2 : 8,
      ),
    ).listen((position) {
      final point =
          Point(latitude: position.latitude, longitude: position.longitude);
      _lastKnownPoint = point;
      _lastKnownHeading = position.heading;
      if (_isMapReady) {
        _updateCurrentLocationMarker(point, position.heading);
      }

      if (!_isTracking) return;

      _mutateState(() {
        _currentSpeedMs = position.speed >= 0 ? position.speed : 0;
        if (_currentSpeedMs > _maxSpeedMs) _maxSpeedMs = _currentSpeedMs;

        final ele = position.altitude;
        if (_lastElevation != null && ele > _lastElevation!) {
          _elevationGainM += ele - _lastElevation!;
        }
        _lastElevation = ele;
      });

      if (_isManualPaused) return;

      RouteProgressSnapshot? guidedProgress;
      if (_isGuidedWorkout && _routeProgressTracker != null) {
        guidedProgress = _routeProgressTracker!.update(
          point.latitude,
          point.longitude,
        );
      }

      final isStationary = position.speed < 0.3;
      final shouldRecordPoint = !isStationary &&
          (_trackedRoutePoints.isEmpty ||
              !_isSameLocation(_trackedRoutePoints.last, point));

      if (shouldRecordPoint || guidedProgress != null) {
        _mutateState(() {
          if (shouldRecordPoint) {
            if (_trackedRoutePoints.isNotEmpty) {
              _totalDistance += Geolocator.distanceBetween(
                _trackedRoutePoints.last.latitude,
                _trackedRoutePoints.last.longitude,
                point.latitude,
                point.longitude,
              );
            }
            _trackedRoutePoints.add(
              TrackPoint(
                latitude: point.latitude,
                longitude: point.longitude,
                time: position.timestamp,
                elevation: position.altitude,
              ),
            );
          }

          if (guidedProgress != null) {
            _guidedRemainingM = guidedProgress.remainingMeters;
            _guidedProgress = guidedProgress.progress;
            _isOffRoute = guidedProgress.isOffRoute;
          }
        });

        if (shouldRecordPoint) {
          _redrawWorkoutRoutes();
        }
      }

      if (shouldRecordPoint && _isMapReady && !_isMinimized) {
        _mapWindow!.map.move(
          CameraPosition(point, zoom: _mapZoom, azimuth: 0, tilt: 0),
        );
      }
    });
  }

  bool _isSameLocation(TrackPoint a, Point b, {double threshold = 0.00003}) {
    return (a.latitude - b.latitude).abs() < threshold &&
        (a.longitude - b.longitude).abs() < threshold;
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
        scale: 0.14,
        rotationType: RotationType.Rotate,
        anchor: math.Point(0.5, 0.5),
        zIndex: 100,
      ));
    _currentLocationPlacemark!.visible = true;
  }

  List<Point> _getActivePlannedRoutePoints() {
    Polyline? geometry;
    switch (_currentRoutingType) {
      case RoutingType.driving:
        if (_drivingRoutes.isNotEmpty) {
          geometry = _drivingRoutes.first.geometry;
        }
        break;
      case RoutingType.pedestrian:
        if (_pedestrianRoutes.isNotEmpty) {
          geometry = _pedestrianRoutes.first.geometry;
        }
        break;
      case RoutingType.publicTransport:
        if (_publicTransportRoutes.isNotEmpty) {
          geometry = _publicTransportRoutes.first.geometry;
        }
        break;
    }

    if (geometry != null && geometry.points.isNotEmpty) {
      return List<Point>.from(geometry.points);
    }

    if (_routePoints.length >= 2) {
      return List<Point>.from(_routePoints);
    }

    return const [];
  }

  void _redrawWorkoutRoutes() {
    final routes = _routesCollection;
    if (!_isMapReady || routes == null) return;
    routes.clear();

    if (_isGuidedWorkout && _routeProgressTracker != null) {
      final planned = Polyline(_routeProgressTracker!.pathPoints);
      routes.addPolylineWithGeometry(planned).applyMainRouteStyle();
    }

    if (_trackedRoutePoints.length < 2) return;

    final tracked = Polyline(
      _trackedRoutePoints
          .map((p) => Point(latitude: p.latitude, longitude: p.longitude))
          .toList(),
    );
    routes.addPolylineWithGeometry(tracked).applyTrackedWorkoutPathStyle();
  }

  void startTracking() => _startTracking();

  void _startTracking() {
    final plannedPoints = _getActivePlannedRoutePoints();
    if (plannedPoints.length < 2) {
      showSnackBar(
        context,
        'Поставьте две точки на карте и дождитесь построения маршрута',
      );
      return;
    }

    final tracker = RouteProgressTracker(plannedPoints);

    setState(() {
      _isTracking = true;
      _isGuidedWorkout = true;
      _routeProgressTracker = tracker;
      _guidedRemainingM = tracker.totalMeters;
      _guidedProgress = 0;
      _isOffRoute = false;
      _isMinimized = false;
      _isLocked = false;
      _isManualPaused = false;
      _trackedRoutePoints.clear();
      _totalDistance = 0.0;
      _currentSpeedMs = 0.0;
      _maxSpeedMs = 0.0;
      _elevationGainM = 0.0;
      _lastElevation = null;
      _workoutStartedAt = DateTime.now();
      _accumulatedPause = Duration.zero;
      _pauseStartedAt = null;
      _elapsed = Duration.zero;
    });
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
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
    if (_appInForeground) {
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

  Future<void> _finishWorkout() async {
    if (!_isTracking) return;
    _tickTimer?.cancel();
    final session = _buildSessionData();

    setState(() {
      _isTracking = false;
      _isGuidedWorkout = false;
      _routeProgressTracker = null;
      _guidedRemainingM = 0;
      _guidedProgress = 0;
      _isOffRoute = false;
      _isMinimized = false;
      _isLocked = false;
      _isManualPaused = false;
    });
    _notifyWorkoutUi();

    if (session.points.length < 2) {
      setState(() {
        _trackedRoutePoints.clear();
        _totalDistance = 0;
      });
      showSnackBar(context, 'Слишком короткая тренировка для сохранения');
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
      } else {
        _pauseStartedAt = DateTime.now();
        _isManualPaused = true;
      }
    });
  }

  void _centerCameraOnCurrentLocation() {
    if (_currentLocationPlacemark == null || _mapWindow == null) {
      showSnackBar(context, 'Местоположение недоступно');
      return;
    }
    _mapWindow!.map.move(
      CameraPosition(_currentLocationPlacemark!.geometry,
          zoom: _mapZoom, azimuth: 0, tilt: 0),
    );
  }

  void _adjustZoom(double delta) {
    _mapZoom = (_mapZoom + delta).clamp(3.0, 20.0);
    _centerCameraOnCurrentLocation();
  }

  void _createMapObjects(MapWindow mapWindow) {
    _mapWindow = mapWindow;
    mapWindow.map.move(GeometryProvider.startPosition);
    mapWindow.map.addInputListener(_inputListener);
    _placemarksCollection = mapWindow.map.mapObjects.addCollection();
    _routesCollection = mapWindow.map.mapObjects.addCollection();
    _userLocationCollection = mapWindow.map.mapObjects.addCollection();

    if (widget.gpxPath != null) {
      GeometryProvider.loadAndParseGPX(context, widget.gpxPath!).then((points) {
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
    }
  }

  void _onRouteParametersUpdated() {
    if (!_isMapReady) return;

    final placemarks = _placemarksCollection;
    final routes = _routesCollection;
    if (placemarks == null || routes == null) return;

    _drivingSession?.cancel();
    _pedestrianSession?.cancel();
    _publicTransportSession?.cancel();
    _drivingSession = null;
    _pedestrianSession = null;
    _publicTransportSession = null;

    placemarks.clear();
    if (!_isTracking) routes.clear();

    if (_routePoints.isEmpty) return;

    _routePoints.forEachIndexed((index, point) {
      final isFinish = index == _routePoints.length - 1;
      final placemark = placemarks.addPlacemark()..geometry = point;
      placemark.setIcon(
        isFinish ? finishPointImageProvider : pointImageProvider,
      );
      placemark.setIconStyle(IconStyle(
        scale: isFinish ? 1.5 : 1.0,
        zIndex: 20.0,
      ));
    });

    if (_routePoints.length < 2) return;

    final points = <RequestPoint>[
      RequestPoint(
        _routePoints.first,
        RequestPointType.Waypoint,
        null,
        null,
        null,
      ),
      ..._routePoints
          .sublist(1, _routePoints.length - 1)
          .map((p) => RequestPoint(p, RequestPointType.Viapoint, null, null, null)),
      RequestPoint(
        _routePoints.last,
        RequestPointType.Waypoint,
        null,
        null,
        null,
      ),
    ];

    try {
      switch (_currentRoutingType) {
        case RoutingType.driving:
          _drivingSession = _drivingRouter.requestRoutes(
            const DrivingOptions(routesCount: 3),
            const DrivingVehicleOptions(),
            _drivingRouteListener,
            points: points,
          );
          break;
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
        showSnackBar(context, 'Не удалось построить маршрут');
      }
    }
  }

  void _onDrivingRoutesUpdated() {
    if (_isTracking || !_isMapReady) return;
    _routesCollection!.clear();
    for (var i = 0; i < _drivingRoutes.length; i++) {
      _createPolylineWithStyle(i, _drivingRoutes[i].geometry);
    }
  }

  void _onPedestrianRoutesUpdated() {
    if (_isTracking || !_isMapReady) return;
    _routesCollection!.clear();
    for (var i = 0; i < _pedestrianRoutes.length; i++) {
      _createPolylineWithStyle(i, _pedestrianRoutes[i].geometry);
    }
  }

  void _onPublicTransportRoutesUpdated() {
    if (_isTracking || !_isMapReady) return;
    _routesCollection!.clear();
    for (var i = 0; i < _publicTransportRoutes.length; i++) {
      _createPolylineWithStyle(i, _publicTransportRoutes[i].geometry);
    }
  }

  void _createPolylineWithStyle(int routeIndex, Polyline geometry) {
    final routes = _routesCollection;
    if (routes == null) return;
    final polyline = routes.addPolylineWithGeometry(geometry);
    routeIndex == 0
        ? polyline.applyMainRouteStyle()
        : polyline.applyAlternativeRouteStyle();
  }

  Future<void> _saveRouteQuick() async {
    String? path;
    if (_isTracking && _trackedRoutePoints.isNotEmpty) {
      path = await GeometryProvider.saveTrackedRouteAsGpx(_trackedRoutePoints);
      if (path != null && mounted) {
        showSnackBar(context, 'Трек сохранён локально');
      }
    } else if (_routePoints.isNotEmpty) {
      path = await GeometryProvider.saveRouteAsGpx(_routePoints);
      if (path != null && mounted) {
        showSnackBar(context, 'Маршрут сохранён:\n$path');
      }
    } else if (mounted) {
      showSnackBar(context, 'Нет данных для сохранения');
    }
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
        Offstage(
          offstage: !widget.isTabActive,
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
          MapIdleOverlay(
            selectedActivity: _selectedActivity,
            onActivitySelected: (t) => setState(() => _selectedActivity = t),
            onStartWorkout: _startTracking,
            onCenterLocation: _centerCameraOnCurrentLocation,
            onZoomIn: () => _adjustZoom(1),
            onZoomOut: () => _adjustZoom(-1),
            onClearRoutes: () {
              setState(() => _routePoints = []);
              showSnackBar(context, 'Все маршруты очищены');
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
            onSaveRoute: _saveRouteQuick,
            bottomPadding: bottomPad,
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
            isManualPaused: _isManualPaused,
            onStop: _finishWorkout,
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
