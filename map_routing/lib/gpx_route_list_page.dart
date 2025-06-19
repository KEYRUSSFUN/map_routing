import 'dart:io';
import 'package:flutter/material.dart';
import 'package:map_routing/main.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';
import 'package:path/path.dart' as p;

class GpxRouteListPage extends StatefulWidget {
  const GpxRouteListPage({super.key});

  @override
  State<GpxRouteListPage> createState() => _GpxRouteListPageState();
}

class _GpxRouteListPageState extends State<GpxRouteListPage> {
  List<_GpxRoute> _routes = [];

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    final directory = await getExternalStorageDirectory();
    if (directory == null) {
      print("Не удалось получить доступ к внешнему хранилищу.");
      return;
    }
    final userpath = directory.path;

    final dir = Directory(userpath);
    final gpxFiles =
        dir.listSync().where((file) => file.path.endsWith('.gpx')).toList();

    final routes = <_GpxRoute>[];

    for (var file in gpxFiles) {
      final filePath = file.path;

      // Проверяем, существует ли файл
      final fileExists = await File(filePath).exists();
      if (!fileExists) {
        print("Файл не существует: $filePath");
        continue;
      }

      final xmlString = await File(filePath).readAsString();
      final doc = XmlDocument.parse(xmlString);

      final name = p.basenameWithoutExtension(filePath);

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

      routes.add(_GpxRoute(
        name: name,
        duration: duration,
        path: filePath,
        date: metadataTime,
      ));
    }

    setState(() {
      _routes = routes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Список маршрутов')),
      body: ListView.builder(
        itemCount: _routes.length,
        itemBuilder: (context, index) {
          final route = _routes[index];
          return ListTile(
              leading: const Icon(Icons.route),
              title: Text(route.name),
              subtitle: route.duration != null
                  ? Text("Длительность: ${_formatDuration(route.duration!)}")
                  : route.date != null
                      ? Text("Дата: ${_formatDate(route.date!)}")
                      : const Text("Время не указано"),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) {
                      print(
                          "Открываю маршрут с путем: ${route.path}"); // Лог пути
                      return MapkitFlutterApp(initialGpxPath: route.path);
                    },
                  ),
                );
              });
        },
      ),
    );
  }

  String _formatDate(DateTime d) {
    return "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    return "$hoursч $minutesм";
  }
}

class _GpxRoute {
  final String name;
  final Duration? duration;
  final DateTime? date;
  final String path;

  _GpxRoute({
    required this.name,
    this.duration,
    this.date,
    required this.path,
  });
}
