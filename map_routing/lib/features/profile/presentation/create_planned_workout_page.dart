import 'dart:async';

import 'package:common/listeners/map_input_listener.dart';
import 'package:common/map/flutter_map_widget.dart';
import 'package:flutter/material.dart' hide Animation;
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/map/mapkit_bootstrap.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:map_routing/data/models/workout_activity_type.dart';
import 'package:map_routing/data/services/pedestrian_route_planner.dart';
import 'package:map_routing/data/services/planned_workout_service.dart';
import 'package:map_routing/data/services/user_workout_storage.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:map_routing/features/profile/presentation/profile_ui.dart';
import 'package:map_routing/data/geometry_provider.dart';
import 'package:map_routing/features/profile/widgets/workout_route_map_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yandex_maps_mapkit/image.dart' as image_provider;
import 'package:yandex_maps_mapkit/mapkit.dart' hide Icon, Map;

enum _RoutePointSelection { start, end }

class CreatePlannedWorkoutPage extends StatefulWidget {
  const CreatePlannedWorkoutPage({super.key});

  @override
  State<CreatePlannedWorkoutPage> createState() =>
      _CreatePlannedWorkoutPageState();
}

class _CreatePlannedWorkoutPageState extends State<CreatePlannedWorkoutPage> {
  Point? _startPoint;
  Point? _endPoint;
  String _startLabel = 'Моё местоположение';
  String _endLabel = 'Выберите на карте';
  _RoutePointSelection _activeSelection = _RoutePointSelection.end;
  List<Point> _routePoints = const [];
  WorkoutActivityType _activityType = WorkoutActivityType.run;
  DateTime _scheduledAt = DateTime.now().add(const Duration(hours: 1));
  PlannedWorkoutEstimates? _estimates;
  bool _routing = false;
  bool _saving = false;
  bool _loadingLocation = true;
  MapWindow? _mapWindow;
  MapObjectCollection? _routesCollection;
  MapObjectCollection? _placemarksCollection;
  late final Future<void> _mapInitFuture;
  late final MapInputListenerImpl _inputListener;

  @override
  void initState() {
    super.initState();
    _mapInitFuture = MapkitBootstrap.ensureInitialized();
    _inputListener = MapInputListenerImpl(
      onMapTapCallback: (_, point) => _onMapTap(point),
      onMapLongTapCallback: (_, point) => _onMapTap(point),
    );
    unawaited(_loadCurrentLocation());
  }

  @override
  void dispose() {
    final mapWindow = _mapWindow;
    if (mapWindow != null) {
      mapWindow.map.removeInputListener(_inputListener);
    }
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _startPoint = Point(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        _loadingLocation = false;
      });
      _refreshRoute();
      _redrawMap();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingLocation = false);
    }
  }

  Future<void> _refreshRoute() async {
    final start = _startPoint;
    final end = _endPoint;
    if (start == null || end == null) {
      setState(() {
        _routePoints = const [];
        _estimates = null;
      });
      _redrawMap();
      return;
    }

    setState(() => _routing = true);
    try {
      final route = await PedestrianRoutePlanner.planRoute(start: start, end: end);
      if (!mounted) return;
      final estimates = await PlannedWorkoutService.instance.estimate(
        activityType: _activityType,
        routePoints: route,
      );
      if (!mounted) return;
      setState(() {
        _routePoints = route;
        _estimates = estimates;
        _routing = false;
      });
      _redrawMap();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _routing = false;
        _routePoints = [start, end];
        _estimates = null;
      });
      AppSnackBar.show(context, 'Не удалось построить маршрут');
      _redrawMap();
    }
  }

  void _onMapTap(Point point) {
    setState(() {
      if (_activeSelection == _RoutePointSelection.start) {
        _startPoint = point;
        _startLabel = _formatCoords(point);
      } else {
        _endPoint = point;
        _endLabel = _formatCoords(point);
      }
    });
    unawaited(_refreshRoute());
  }

  String _formatCoords(Point point) {
    return '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null || !mounted) return;

    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (_startPoint == null || _endPoint == null) {
      AppSnackBar.show(context, 'Выберите точки маршрута');
      return;
    }
    if (_routePoints.length < 2) {
      AppSnackBar.show(context, 'Дождитесь построения маршрута');
      return;
    }
    if (!_scheduledAt.isAfter(DateTime.now())) {
      AppSnackBar.show(context, 'Выберите время в будущем');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final userId = await UserWorkoutStorage.instance.syncUserIdFromToken(token);
    if (userId == null) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Не удалось определить пользователя');
      return;
    }

    setState(() => _saving = true);
    try {
      final estimates = _estimates ??
          await PlannedWorkoutService.instance.estimate(
            activityType: _activityType,
            routePoints: _routePoints,
          );
      final title =
          '${_activityType.labelRu} · ${formatPlannedWorkoutSchedule(_scheduledAt)}';

      await PlannedWorkoutService.instance.save(
        userId: userId,
        title: title,
        scheduledAt: _scheduledAt,
        activityType: _activityType,
        startPoint: _startPoint!,
        endPoint: _endPoint!,
        startLabel: _startLabel,
        endLabel: _endLabel,
        routePoints: _routePoints,
        estimates: estimates,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackBar.show(context, 'Не удалось сохранить: $e');
    }
  }

  void _redrawMap() {
    final mapWindow = _mapWindow;
    if (mapWindow == null) return;

    _routesCollection?.clear();
    _placemarksCollection?.clear();

    final points = _routePoints.length >= 2
        ? _routePoints
        : [
            if (_startPoint != null) _startPoint!,
            if (_endPoint != null) _endPoint!,
          ];

    if (points.length >= 2) {
      drawRouteOnMapWindow(
        mapWindow,
        points: points,
        routes: _routesCollection,
        placemarks: _placemarksCollection,
      );
      return;
    }

    if (_startPoint != null) {
      _drawPointMarker(_startPoint!, isFinish: false);
    }
    if (_endPoint != null) {
      _drawPointMarker(_endPoint!, isFinish: true);
    }

    final focus = _endPoint ?? _startPoint;
    if (focus != null) {
      mapWindow.map.move(
        CameraPosition(focus, zoom: 14, azimuth: 0, tilt: 0),
      );
    } else {
      mapWindow.map.move(GeometryProvider.startPosition);
    }
  }

  void _drawPointMarker(Point point, {required bool isFinish}) {
    final collection = _placemarksCollection;
    if (collection == null) return;

    final placemark = collection.addPlacemark()..geometry = point;
    placemark.setIcon(
      image_provider.ImageProvider.fromImageProvider(
        AssetImage(
          isFinish ? 'assets/ic_finish_point.png' : 'assets/start_point.png',
        ),
      ),
    );
    placemark.setIconStyle(
      IconStyle(scale: isFinish ? 1.5 : 1.0, zIndex: 20.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final distanceKm = (_estimates?.distanceMeters ?? 0) / 1000;
    final durationMin = (_estimates?.durationSeconds ?? 0) ~/ 60;
    final calories = _estimates?.calories ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F7),
      appBar: AppBar(
        title: Text(
          'Создать тренировку',
          style: GoogleFonts.lexendDeca(
            fontWeight: FontWeight.w700,
            color: AuthColors.title,
          ),
        ),
        backgroundColor: const Color(0xFFF2F5F7),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AuthColors.title),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 260,
                child: _loadingLocation
                    ? const ColoredBox(
                        color: Color(0xFFEEF4F0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : FutureBuilder<void>(
                        future: _mapInitFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState != ConnectionState.done) {
                            return const ColoredBox(
                              color: Color(0xFFEEF4F0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return Stack(
                            children: [
                              FlutterMapWidget(
                                key: const ValueKey('planned_workout_map'),
                                onMapCreated: (mapWindow) {
                                  if (_mapWindow != null) {
                                    _mapWindow!.map.removeInputListener(
                                      _inputListener,
                                    );
                                  }
                                  _mapWindow = mapWindow;
                                  _routesCollection =
                                      mapWindow.map.mapObjects.addCollection();
                                  _placemarksCollection =
                                      mapWindow.map.mapObjects.addCollection();
                                  mapWindow.map.addInputListener(_inputListener);
                                  _redrawMap();
                                },
                              ),
                              if (_routing)
                                const ColoredBox(
                                  color: Color(0x44FFFFFF),
                                  child: Center(
                                    child: SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Нажмите или удерживайте палец на карте, чтобы выбрать '
              '${_activeSelection == _RoutePointSelection.start ? 'старт' : 'финиш'}',
              style: profileSubtitleStyle(),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _RoutePointSelector(
                  startLabel: _startLabel,
                  endLabel: _endLabel,
                  active: _activeSelection,
                  onStartTap: () => setState(
                    () => _activeSelection = _RoutePointSelection.start,
                  ),
                  onEndTap: () => setState(
                    () => _activeSelection = _RoutePointSelection.end,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Вид тренировки', style: profileSectionTitleStyle()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: WorkoutActivityType.values.map((type) {
              final selected = type == _activityType;
              return ChoiceChip(
                label: Text(type.labelRu),
                selected: selected,
                onSelected: (_) {
                  setState(() => _activityType = type);
                  unawaited(_refreshRoute());
                },
                selectedColor: ProfileColors.primaryGreen.withValues(alpha: 0.2),
                labelStyle: GoogleFonts.lexendDeca(
                  color: selected ? ProfileColors.title : ProfileColors.body,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDateTime,
            borderRadius: BorderRadius.circular(14),
            child: ProfileCard(
              child: Row(
                children: [
                  const Icon(Icons.event_outlined, color: ProfileColors.primaryGreen),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Дата и время', style: profileSubtitleStyle()),
                        const SizedBox(height: 4),
                        Text(
                          formatPlannedWorkoutSchedule(_scheduledAt),
                          style: profileTitleStyle(size: 15),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: ProfileColors.body),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ProfileCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Оценка нагрузки', style: profileSectionTitleStyle()),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _EstimateTile(
                        label: 'Дистанция',
                        value: distanceKm > 0
                            ? '${distanceKm.toStringAsFixed(1)} км'
                            : '—',
                      ),
                    ),
                    Expanded(
                      child: _EstimateTile(
                        label: 'Время',
                        value: durationMin > 0 ? '~$durationMin мин' : '—',
                      ),
                    ),
                    Expanded(
                      child: _EstimateTile(
                        label: 'Калории',
                        value: calories > 0 ? '~$calories' : '—',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AuthColors.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Запланировать тренировку',
                      style: GoogleFonts.lexendDeca(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePointSelector extends StatelessWidget {
  const _RoutePointSelector({
    required this.startLabel,
    required this.endLabel,
    required this.active,
    required this.onStartTap,
    required this.onEndTap,
  });

  final String startLabel;
  final String endLabel;
  final _RoutePointSelection active;
  final VoidCallback onStartTap;
  final VoidCallback onEndTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PointTile(
            title: 'Откуда',
            value: startLabel,
            selected: active == _RoutePointSelection.start,
            icon: Icons.radio_button_checked,
            onTap: onStartTap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PointTile(
            title: 'Куда',
            value: endLabel,
            selected: active == _RoutePointSelection.end,
            icon: Icons.flag_outlined,
            onTap: onEndTap,
          ),
        ),
      ],
    );
  }
}

class _PointTile extends StatelessWidget {
  const _PointTile({
    required this.title,
    required this.value,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String value;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: profileElevatedDecoration(
          backgroundColor:
              selected ? const Color(0xFFE8FBF1) : ProfileColors.cardBg,
          borderColor: selected
              ? ProfileColors.primaryGreen
              : const Color(0xFFE8E8E8),
          radius: 14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? ProfileColors.primaryGreen : ProfileColors.body,
                ),
                const SizedBox(width: 6),
                Text(title, style: profileSubtitleStyle()),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: profileTitleStyle(size: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstimateTile extends StatelessWidget {
  const _EstimateTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: profileTitleStyle(size: 16)),
        const SizedBox(height: 2),
        Text(label, style: profileSubtitleStyle()),
      ],
    );
  }
}
