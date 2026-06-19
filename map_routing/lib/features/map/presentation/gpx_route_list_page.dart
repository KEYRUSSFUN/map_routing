import 'dart:io';

import 'package:flutter/material.dart';
import 'package:map_routing/main.dart';
import 'package:map_routing/data/services/user_workout_storage.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

class GpxRouteListPage extends StatefulWidget {
  const GpxRouteListPage({super.key});

  @override
  State<GpxRouteListPage> createState() => _GpxRouteListPageState();
}

class _GpxRouteListPageState extends State<GpxRouteListPage> {
  List<_GpxRoute> _routes = [];
  bool _loadingDetails = false;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    final gpxFiles = await UserWorkoutStorage.instance.listUserGpxFiles();

    final placeholders = gpxFiles
        .map(
          (file) => _GpxRoute(
            name: p.basenameWithoutExtension(file.path),
            path: file.path,
          ),
        )
        .toList();

    if (!mounted) return;
    setState(() {
      _routes = placeholders;
      _loadingDetails = placeholders.isNotEmpty;
    });

    if (placeholders.isEmpty) return;

    for (var i = 0; i < placeholders.length; i++) {
      if (!mounted) break;
      final enriched = await _loadRouteDetails(placeholders[i]);
      if (!mounted) break;
      setState(() {
        _routes[i] = enriched;
      });
    }

    if (mounted) {
      setState(() => _loadingDetails = false);
    }
  }

  Future<_GpxRoute> _loadRouteDetails(_GpxRoute route) async {
    try {
      final filePath = route.path;
      if (!await File(filePath).exists()) return route;

      final xmlString = await File(filePath).readAsString();
      final doc = XmlDocument.parse(xmlString);

      final trkpts = doc.findAllElements('trkpt');
      final times = trkpts
          .map((pt) => pt.getElement('time')?.innerText)
          .where((t) => t != null)
          .map((t) => DateTime.tryParse(t!))
          .whereType<DateTime>()
          .toList();

      Duration? duration;
      DateTime? metadataTime;

      final metadataTimeStr = doc
          .findAllElements('metadata')
          .expand((m) => m.findElements('time'))
          .map((e) => e.innerText)
          .firstWhere((t) => t.isNotEmpty, orElse: () => '');

      if (metadataTimeStr.isNotEmpty) {
        metadataTime = DateTime.tryParse(metadataTimeStr);
      }

      if (times.length >= 2) {
        duration = times.last.difference(times.first);
      }

      return _GpxRoute(
        name: route.name,
        duration: duration,
        path: filePath,
        date: metadataTime,
      );
    } catch (_) {
      return route;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Список маршрутов'),
        actions: [
          if (_loadingDetails)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: _routes.isEmpty
          ? const Center(child: Text('Нет сохранённых маршрутов'))
          : ListView.builder(
              itemCount: _routes.length,
              itemBuilder: (context, index) {
                final route = _routes[index];
                return ListTile(
                  leading: const Icon(Icons.route),
                  title: Text(route.name),
                  subtitle: route.duration != null
                      ? Text('Длительность: ${_formatDuration(route.duration!)}')
                      : route.date != null
                          ? Text('Дата: ${_formatDate(route.date!)}')
                          : const Text('Загрузка деталей...'),
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MapkitFlutterApp(initialGpxPath: route.path),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    return '$hoursч $minutesм';
  }
}

class _GpxRoute {
  final String name;
  final Duration? duration;
  final String path;
  final DateTime? date;

  _GpxRoute({
    required this.name,
    required this.path,
    this.duration,
    this.date,
  });
}
