import 'dart:async';
import 'dart:math' as math;

import 'package:common/map/flutter_map_widget.dart';
import 'package:flutter/material.dart' hide Animation;
import 'package:map_routing/core/map/mapkit_bootstrap.dart';
import 'package:map_routing/data/geometry_provider.dart';
import 'package:map_routing/data/models/track_point.dart';
import 'package:map_routing/data/services/app_settings_service.dart';
import 'package:map_routing/features/profile/presentation/profile_ui.dart';
import 'package:map_routing/shared/utils/polyline_extensions.dart';
import 'package:yandex_maps_mapkit/image.dart' as image_provider;
import 'package:yandex_maps_mapkit/mapkit.dart' hide Icon;

List<Point> trackPointsToMapPoints(List<TrackPoint> points) {
  return points
      .map((point) => Point(latitude: point.latitude, longitude: point.longitude))
      .toList();
}

CameraPosition cameraPositionForRoute(List<Point> points, {double paddingFactor = 1.25}) {
  if (points.isEmpty) {
    return GeometryProvider.startPosition;
  }

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

  final latSpan = math.max(maxLat - minLat, 1e-6) * paddingFactor;
  final lonSpan = math.max(maxLon - minLon, 1e-6) * paddingFactor;
  final span = math.max(latSpan, lonSpan);

  final center = Point(
    latitude: (minLat + maxLat) / 2,
    longitude: (minLon + maxLon) / 2,
  );
  final zoom = span <= 0.001
      ? 15.0
      : (math.log(360 / span) / math.ln2).clamp(10.0, 17.0).toDouble();

  return CameraPosition(center, zoom: zoom, azimuth: 0, tilt: 0);
}

void drawRouteOnMapWindow(
  MapWindow mapWindow, {
  required List<Point> points,
  MapObjectCollection? placemarks,
  MapObjectCollection? routes,
  bool hideEndpoints = false,
}) {
  if (points.length < 2) return;

  final routeCollection = routes ?? mapWindow.map.mapObjects.addCollection();
  final placemarkCollection = placemarks ?? mapWindow.map.mapObjects.addCollection();

  if (!hideEndpoints) {
    final start = placemarkCollection.addPlacemark()..geometry = points.first;
    start.setIcon(
      image_provider.ImageProvider.fromImageProvider(
        const AssetImage('assets/start_point.png'),
      ),
    );
    start.setIconStyle(const IconStyle(scale: 1.0, zIndex: 20.0));

    final finish = placemarkCollection.addPlacemark()..geometry = points.last;
    finish.setIcon(
      image_provider.ImageProvider.fromImageProvider(
        const AssetImage('assets/ic_finish_point.png'),
      ),
    );
    finish.setIconStyle(const IconStyle(scale: 1.5, zIndex: 20.0));
  }

  routeCollection
      .addPolylineWithGeometry(Polyline(points))
      .applyMainRouteStyle();

  mapWindow.map.move(cameraPositionForRoute(points));
}

class WorkoutRouteMapPreview extends StatefulWidget {
  const WorkoutRouteMapPreview({
    super.key,
    required this.points,
    this.filePath,
    this.height = 180,
    this.borderRadius = 16,
    this.interactive = false,
    this.showExpandButton = true,
  });

  final List<TrackPoint> points;
  final String? filePath;
  final double height;
  final double borderRadius;
  final bool interactive;
  final bool showExpandButton;

  @override
  State<WorkoutRouteMapPreview> createState() => _WorkoutRouteMapPreviewState();
}

class _WorkoutRouteMapPreviewState extends State<WorkoutRouteMapPreview> {
  List<Point> _routePoints = const [];
  bool _loadingPoints = false;

  @override
  void initState() {
    super.initState();
    _routePoints = trackPointsToMapPoints(widget.points);
    if (_routePoints.length < 2) {
      unawaited(_loadPointsFromFile());
    }
  }

  @override
  void didUpdateWidget(covariant WorkoutRouteMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points || oldWidget.filePath != widget.filePath) {
      _routePoints = trackPointsToMapPoints(widget.points);
      if (_routePoints.length < 2) {
        unawaited(_loadPointsFromFile());
      }
    }
  }

  Future<void> _loadPointsFromFile() async {
    final path = widget.filePath?.trim();
    if (path == null || path.isEmpty || _loadingPoints) return;

    setState(() => _loadingPoints = true);
    try {
      final loaded = await GeometryProvider.loadAndParseGPX(path);
      if (!mounted) return;
      setState(() {
        _routePoints = loaded;
        _loadingPoints = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPoints = false);
    }
  }

  void _openFullscreen() {
    if (_routePoints.length < 2) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutRouteMapPage(points: _routePoints),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_routePoints.length < 2) {
      return _RoutePlaceholder(
        height: widget.height,
        borderRadius: widget.borderRadius,
        loading: _loadingPoints,
      );
    }

    final map = FutureBuilder<void>(
      future: MapkitBootstrap.ensureInitialized(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _RoutePlaceholder(
            height: widget.height,
            borderRadius: widget.borderRadius,
            loading: true,
          );
        }

        if (snapshot.hasError) {
          return _RoutePlaceholder(
            height: widget.height,
            borderRadius: widget.borderRadius,
          );
        }

        final mapWidget = ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: FlutterMapWidget(
              onMapCreated: (mapWindow) {
                drawRouteOnMapWindow(
                  mapWindow,
                  points: _routePoints,
                  hideEndpoints:
                      AppSettingsService.instance.hideMapEndpoints,
                );
              },
            ),
          ),
        );

        if (widget.interactive) return mapWidget;

        return IgnorePointer(child: mapWidget);
      },
    );

    if (!widget.showExpandButton) return map;

    return Stack(
      children: [
        map,
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: Colors.white.withValues(alpha: 0.92),
            shape: const CircleBorder(),
            elevation: 2,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _openFullscreen,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.open_in_full_rounded,
                  size: 18,
                  color: ProfileColors.title,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class WorkoutRouteMapPage extends StatelessWidget {
  const WorkoutRouteMapPage({super.key, required this.points});

  final List<Point> points;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F7),
      body: Stack(
        children: [
          FutureBuilder<void>(
            future: MapkitBootstrap.ensureInitialized(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              return FlutterMapWidget(
                onMapCreated: (mapWindow) {
                  drawRouteOnMapWindow(
                    mapWindow,
                    points: points,
                    hideEndpoints:
                        AppSettingsService.instance.hideMapEndpoints,
                  );
                },
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Material(
                color: Colors.white.withValues(alpha: 0.92),
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.close_rounded, color: ProfileColors.title),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePlaceholder extends StatelessWidget {
  const _RoutePlaceholder({
    required this.height,
    required this.borderRadius,
    this.loading = false,
  });

  final double height;
  final double borderRadius;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDCEFE2), Color(0xFFF4F8F5)],
        ),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Icon(
              Icons.map_outlined,
              size: 36,
              color: ProfileColors.body.withValues(alpha: 0.55),
            ),
    );
  }
}
