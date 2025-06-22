import 'package:collection/collection.dart';
import 'package:common/buttons/simple_button.dart';
import 'package:common/listeners/map_input_listener.dart';
import 'package:common/map/flutter_map_widget.dart';
import 'package:common/utils/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:map_routing/UIWidgets/tracking_button.dart';
import 'package:map_routing/data/activity_calculator.dart';
import 'package:map_routing/data/geometry_provider.dart';
import 'package:map_routing/data/routing_type.dart';
import 'package:map_routing/usersData/registration_service.dart';
import 'package:map_routing/usersData/user_service.dart';
import 'package:map_routing/utils/polyline_extensions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yandex_maps_mapkit/directions.dart';
import 'package:yandex_maps_mapkit/image.dart' as image_provider;
import 'package:yandex_maps_mapkit/mapkit.dart' hide LocationSettings;
import 'package:yandex_maps_mapkit/transport.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:flutter/material.dart' as flutter;
import 'package:flutter_compass/flutter_compass.dart';
import 'dart:math' show Point;
import 'dart:math' as math;

class MapScreen extends StatefulWidget {
  final String? gpxPath;

  const MapScreen({Key? key, this.gpxPath}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapWindow? _mapWindow;
  var _routePoints = <Point>[];
  var _drivingRoutes = <DrivingRoute>[];
  var _pedestrianRoutes = <MasstransitRoute>[];
  var _publicTransportRoutes = <MasstransitRoute>[];
  var _currentRoutingType = RoutingType.driving;

  late final MapObjectCollection _userLocationCollection;
  PlacemarkMapObject? _currentLocationPlacemark;
  late final image_provider.ImageProvider _arrowImageProvider =
      image_provider.ImageProvider.fromImageProvider(
          const AssetImage("assets/nav_icons/arrow.png"));

  bool _isTracking = false;
  StreamSubscription<Position>? _positionStream;
  final List<Point> _trackedRoutePoints = [];

  double _totalDistance = 0.0;
  double _currentSpeed = 0.0;
  bool _isPaused = false;

  late final DrivingRouter _drivingRouter;
  late final PedestrianRouter _pedestrianRouter;
  late final MasstransitRouter _publicTransportRouter;
  late final MapObjectCollection _placemarksCollection;
  late final MapObjectCollection _routesCollection;

  double? _compassHeading;
  StreamSubscription<CompassEvent>? _compassStream;

  DrivingSession? _drivingSession;
  MasstransitSession? _pedestrianSession;
  MasstransitSession? _publicTransportSession;

  late final pointImageProvider =
      image_provider.ImageProvider.fromImageProvider(
          const AssetImage("assets/start_point.png"));

  late final finishPointImageProvider =
      image_provider.ImageProvider.fromImageProvider(
          const AssetImage("assets/ic_finish_point.png"));

  late final _inputListener = MapInputListenerImpl(
    onMapTapCallback: (_, __) {},
    onMapLongTapCallback: (map, point) {
      setState(() => _routePoints = [..._routePoints, point]);
      if (_routePoints.length == 1) {
        showSnackBar(context, "Добавлена первая точка");
      }
      _onRouteParametersUpdated();
    },
  );

  late final _drivingRouteListener = DrivingSessionRouteListener(
    onDrivingRoutes: (newRoutes) {
      if (newRoutes.isEmpty) {
        showSnackBar(context, "Не возможно построить маршрут");
      }
      setState(() => _drivingRoutes = newRoutes);
      _onDrivingRoutesUpdated();
    },
    onDrivingRoutesError: (error) {
      showSnackBar(context, "Ошибка построения маршрута (авто)");
    },
  );

  late final _pedestrianRouteListener = RouteHandler(
    onMasstransitRoutes: (newRoutes) {
      if (newRoutes.isEmpty) {
        showSnackBar(context, "Не удалось построить маршрут");
      }
      setState(() => _pedestrianRoutes = newRoutes);
      _onPedestrianRoutesUpdated();
    },
    onMasstransitRoutesError: (error) {
      showSnackBar(context, "Ошибка построения маршрута (пешком)");
    },
  );

  late final _publicTransportRouteListener = RouteHandler(
    onMasstransitRoutes: (newRoutes) {
      if (newRoutes.isEmpty) {
        showSnackBar(context, "Не удалось построить маршрут");
      }
      setState(() => _publicTransportRoutes = newRoutes);
      _onPublicTransportRoutesUpdated();
    },
    onMasstransitRoutesError: (error) {
      showSnackBar(context, "Ошибка построения маршрута (транспорт)");
    },
  );

  @override
  void initState() {
    super.initState();
    _drivingRouter = DirectionsFactory.instance
        .createDrivingRouter(DrivingRouterType.Combined);
    _pedestrianRouter = TransportFactory.instance.createPedestrianRouter();
    _publicTransportRouter =
        TransportFactory.instance.createMasstransitRouter();

    _startLocationUpdates();
    _startCompassUpdates();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _compassStream?.cancel();
    _drivingSession?.cancel();
    _pedestrianSession?.cancel();
    _publicTransportSession?.cancel();
    super.dispose();
  }

  void _startCompassUpdates() {
    _compassStream = FlutterCompass.events?.listen((event) {
      final heading = event.heading;
      if (heading != null && heading.isFinite) {
        setState(() => _compassHeading = heading);
        if (_currentLocationPlacemark != null) {
          _currentLocationPlacemark!.direction = heading;
        }
      }
    });
  }

  void _startLocationUpdates() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      final requested = await Geolocator.requestPermission();
      if (requested != LocationPermission.always &&
          requested != LocationPermission.whileInUse) {
        if (mounted) showSnackBar(context, "Нет разрешения на геолокацию");
        return;
      }
    }

    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 2,
      ),
    ).listen((position) {
      final point =
          Point(latitude: position.latitude, longitude: position.longitude);
      _updateCurrentLocationMarker(point, position.heading);

      if (!_isTracking) return;

      final isStationary = position.speed < 0.3;

      setState(() {
        _currentSpeed = position.speed;
        _isPaused = isStationary;
      });

      if (!isStationary &&
          (_trackedRoutePoints.isEmpty ||
              !_isSameLocation(_trackedRoutePoints.last, point))) {
        setState(() {
          if (_trackedRoutePoints.isNotEmpty) {
            _totalDistance += Geolocator.distanceBetween(
              _trackedRoutePoints.last.latitude,
              _trackedRoutePoints.last.longitude,
              point.latitude,
              point.longitude,
            );
          }
          _trackedRoutePoints.add(point);
        });
        _drawTrackingPolyline();
        _mapWindow?.map
            .move(CameraPosition(point, zoom: 16, azimuth: 0, tilt: 0));
      }
    });
  }

  bool _isSameLocation(Point a, Point b, {double threshold = 0.00003}) {
    return (a.latitude - b.latitude).abs() < threshold &&
        (a.longitude - b.longitude).abs() < threshold;
  }

  void _updateCurrentLocationMarker(Point point, double? heading) {
    if (_currentLocationPlacemark != null) {
      _userLocationCollection.remove(_currentLocationPlacemark!);
    }

    final direction = (heading != null && heading.isFinite) ? heading : 0.0;

    _currentLocationPlacemark = _userLocationCollection.addPlacemark()
      ..geometry = point
      ..direction = direction;

    _currentLocationPlacemark!
      ..setIcon(_arrowImageProvider)
      ..setIconStyle(const IconStyle(
        scale: 0.12,
        rotationType: RotationType.Rotate,
        anchor: math.Point(0.5, 0.5),
        zIndex: 100,
      ));
    _currentLocationPlacemark!.visible = true;
  }

  void _drawTrackingPolyline() {
    _routesCollection.clear();
    if (_trackedRoutePoints.length < 2) return;
    final polyline = Polyline(_trackedRoutePoints.toList());
    final mapPolyline = _routesCollection.addPolylineWithGeometry(polyline);
    mapPolyline.applyMainRouteStyle();
  }

  void _startTracking() {
    setState(() {
      _isTracking = true;
      _trackedRoutePoints.clear();
      _totalDistance = 0.0;
      _currentSpeed = 0.0;
      _isPaused = false;
    });
  }

  Future<void> _stopTracking() async {
    setState(() {
      _isTracking = false;
      _currentSpeed = 0.0;
      _isPaused = false;
    });

    if (_trackedRoutePoints.isEmpty) return;

    final path =
        await GeometryProvider.saveTrackedRouteAsGpx(_trackedRoutePoints);

    final userInfo = await UserService().fetchUserInfo();
    if (userInfo == null || !userInfo.containsKey('weight')) {
      if (mounted) showSnackBar(context, "Ошибка: вес пользователя не найден");
      return;
    }

    final double weight = userInfo['weight'].toDouble();
    final calculator = ActivityCalculator(weightKg: weight);

    final steps = calculator.estimateStepsByDistance(_totalDistance);
    final calories = calculator.calculateWalkingCalories(
      distanceMeters: _totalDistance,
    );

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      if (mounted) showSnackBar(context, "Ошибка: токен не найден");
      return;
    }

    await RegistrationService(baseUrl: "http://192.168.1.105:5000")
        .saveTrackingData(
      distance: _totalDistance,
      steps: steps,
      calories: calories,
      token: token,
    );

    if (mounted) {
      showSnackBar(context, "Маршрут завершён и статистика сохранена");
    }

    setState(() {
      _totalDistance = 0.0;
      _trackedRoutePoints.clear();
    });
  }

  void _centerCameraOnCurrentLocation() {
    if (_currentLocationPlacemark == null || _mapWindow == null) {
      showSnackBar(context, "Местоположение недоступно");
      return;
    }
    final currentPoint = _currentLocationPlacemark!.geometry;
    _mapWindow!.map.move(
      CameraPosition(currentPoint, zoom: 16, azimuth: 0, tilt: 0),
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
      GeometryProvider.loadAndParseGPX(context, widget.gpxPath!).then((points) {
        setState(() {
          _routePoints = points;
        });
        _onRouteParametersUpdated();
      });
    }
  }

  void _onRouteParametersUpdated() {
    _placemarksCollection.clear();
    _routesCollection.clear();

    _drivingSession?.cancel();
    _pedestrianSession?.cancel();
    _publicTransportSession?.cancel();

    if (_routePoints.isEmpty) return;

    _routePoints.forEachIndexed((index, point) {
      final placemark = _placemarksCollection.addPlacemark()..geometry = point;
      placemark.setIcon(index == _routePoints.length - 1
          ? finishPointImageProvider
          : pointImageProvider);
      placemark.setIconStyle(IconStyle(
        scale: index == _routePoints.length - 1 ? 1.5 : 1.0,
        zIndex: 20.0,
      ));
    });

    if (_routePoints.length < 2) return;

    final points = [
      RequestPoint(
          _routePoints.first, RequestPointType.Waypoint, null, null, null),
      ..._routePoints.sublist(1, _routePoints.length - 1).map(
            (p) => RequestPoint(p, RequestPointType.Viapoint, null, null, null),
          ),
      RequestPoint(
          _routePoints.last, RequestPointType.Waypoint, null, null, null),
    ];

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
  }

  void _onDrivingRoutesUpdated() {
    _routesCollection.clear();
    for (var i = 0; i < _drivingRoutes.length; i++) {
      _createPolylineWithStyle(i, _drivingRoutes[i].geometry);
    }
  }

  void _onPedestrianRoutesUpdated() {
    _routesCollection.clear();
    for (var i = 0; i < _pedestrianRoutes.length; i++) {
      _createPolylineWithStyle(i, _pedestrianRoutes[i].geometry);
    }
  }

  void _onPublicTransportRoutesUpdated() {
    _routesCollection.clear();
    for (var i = 0; i < _publicTransportRoutes.length; i++) {
      _createPolylineWithStyle(i, _publicTransportRoutes[i].geometry);
    }
  }

  void _createPolylineWithStyle(int routeIndex, Polyline geometry) {
    final polyline = _routesCollection.addPolylineWithGeometry(geometry);
    routeIndex == 0
        ? polyline.applyMainRouteStyle()
        : polyline.applyAlternativeRouteStyle();
  }

  double calculateCalories({
    required double distanceMeters,
    required double weightKg,
    double met = 3.8,
  }) {
    double distanceKm = distanceMeters / 1000;
    double durationHours = distanceKm / 5.0;
    return met * weightKg * durationHours;
  }

  Widget _buildInfoColumn(String label, String value, {Color? color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: flutter.TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: flutter.TextStyle(
            color: color ?? Colors.grey[800],
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 32,
      color: Colors.grey[300],
    );
  }

  Widget _iconActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        icon: Icon(icon, color: Colors.grey[800]),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMapWidget(
          onMapCreated: _createMapObjects,
          onMapDispose: () =>
              _mapWindow?.map.removeInputListener(_inputListener),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildInfoColumn(
                    "СКОРОСТЬ", "${_currentSpeed.toStringAsFixed(1)} М/С"),
                _verticalDivider(),
                _buildInfoColumn(
                    "СТАТУС",
                    _isTracking
                        ? (_isPaused ? "⏸ ПАУЗА" : "В ДВИЖЕНИИ")
                        : "НА МЕСТЕ",
                    color: _isTracking
                        ? (_isPaused ? Colors.orange : Colors.green)
                        : Colors.blue),
                _verticalDivider(),
                _buildInfoColumn("РАССТОЯНИЕ",
                    "${(_totalDistance / 1000).toStringAsFixed(2)} КМ"),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  const SizedBox(height: 130),
                  _iconActionButton(
                    icon: Icons.delete_outline,
                    tooltip: "Очистить маршруты",
                    onPressed: () {
                      setState(() => _routePoints = []);
                      showSnackBar(context, "Все маршруты очищены");
                      _onRouteParametersUpdated();
                    },
                  ),
                ],
              ),
              Column(
                children: [
                  const SizedBox(height: 105),
                  TrackingButton(
                    isTracking: _isTracking,
                    onPressed: () async {
                      _isTracking ? await _stopTracking() : _startTracking();
                    },
                  ),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  _iconActionButton(
                    icon: Icons.swap_horiz,
                    tooltip: "Сменить тип маршрута",
                    onPressed: () {
                      setState(() {
                        _currentRoutingType = RoutingType.values[
                            (_currentRoutingType.index + 1) %
                                RoutingType.values.length];
                      });
                      _onRouteParametersUpdated();
                    },
                  ),
                  const SizedBox(height: 12),
                  _iconActionButton(
                    icon: Icons.my_location,
                    tooltip: "Вернуться к текущему местоположению",
                    onPressed: _centerCameraOnCurrentLocation,
                  ),
                  const SizedBox(height: 12),
                  _iconActionButton(
                    icon: Icons.save_alt,
                    tooltip: "Сохранить маршрут",
                    onPressed: () async {
                      String? path;
                      if (_isTracking && _trackedRoutePoints.isNotEmpty) {
                        path = await GeometryProvider.saveTrackedRouteAsGpx(
                            _trackedRoutePoints);
                        final prefs = await SharedPreferences.getInstance();
                        final token = prefs.getString('jwt_token');
                        if (token == null) {
                          showSnackBar(context, "Ошибка: токен не найден");
                          return;
                        }
                        showSnackBar(context, "Данные сохранены");
                        _trackedRoutePoints.clear();
                        _routePoints.clear();
                        _totalDistance = 0.0;
                      } else if (_routePoints.isNotEmpty) {
                        path =
                            await GeometryProvider.saveRouteAsGpx(_routePoints);
                      }
                      if (path != null && context.mounted) {
                        showSnackBar(context, "Сохранено в файл:\n$path");
                      } else if (!_isTracking || _trackedRoutePoints.isEmpty) {
                        showSnackBar(context, "Нет данных для сохранения");
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
