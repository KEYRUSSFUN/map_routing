import 'dart:io';
import 'package:flutter/material.dart';
import 'package:map_routing/usersData/group_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AttachRouteDialog extends StatefulWidget {
  const AttachRouteDialog({super.key});

  @override
  State<AttachRouteDialog> createState() => _AttachRouteDialogState();
}

class _AttachRouteDialogState extends State<AttachRouteDialog> {
  List<FileSystemEntity> gpxFiles = [];

  @override
  void initState() {
    super.initState();
    _loadGpxFiles();
  }

  Future<void> _loadGpxFiles() async {
    final dir = await getApplicationDocumentsDirectory(); // или другой путь
    final files = Directory(dir.path)
        .listSync()
        .where((f) => f.path.endsWith('.gpx'))
        .toList();
    setState(() {
      gpxFiles = files;
    });
  }

  Future<void> _uploadGpx(String path) async {
    // Заменить на твой метод

    Navigator.pop(context); // Закрыть диалог
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Выберите маршрут для отправки'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: gpxFiles.isEmpty
            ? const Center(child: Text('Нет сохранённых маршрутов'))
            : ListView.builder(
                itemCount: gpxFiles.length,
                itemBuilder: (context, index) {
                  final file = gpxFiles[index];
                  return ListTile(
                    leading: const Icon(Icons.map),
                    title: Text(p.basename(file.path)),
                    onTap: () => _uploadGpx(file.path),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
      ],
    );
  }
}
