import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/data/models/workout_metadata.dart';
import 'package:map_routing/data/services/chat_route_service.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocalRouteItem {
  const LocalRouteItem({
    required this.path,
    required this.fileName,
    required this.title,
  });

  final String path;
  final String fileName;
  final String title;
}

class AttachRouteDialog extends StatefulWidget {
  const AttachRouteDialog({
    super.key,
    required this.chatId,
    required this.routeService,
    required this.onShared,
  });

  final String chatId;
  final ChatRouteService routeService;
  final void Function(Map<String, dynamic> message) onShared;

  @override
  State<AttachRouteDialog> createState() => _AttachRouteDialogState();
}

class _AttachRouteDialogState extends State<AttachRouteDialog> {
  List<LocalRouteItem> _routes = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String? _uploadingPath;

  @override
  void initState() {
    super.initState();
    _loadGpxFiles();
  }

  Future<void> _loadGpxFiles() async {
    final directory = await getExternalStorageDirectory();
    if (directory == null) {
      if (!mounted) return;
      setState(() {
        _routes = [];
        _isLoading = false;
      });
      return;
    }

    final files = Directory(directory.path)
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.gpx'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));

    final items = <LocalRouteItem>[];
    for (final file in files) {
      final fileName = p.basename(file.path);
      final metadata = await WorkoutMetadata.loadFromGpxPath(file.path);
      items.add(
        LocalRouteItem(
          path: file.path,
          fileName: fileName,
          title: metadata?.title ?? fileName,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _routes = items;
      _isLoading = false;
    });
  }

  Future<void> _shareRoute(LocalRouteItem item) async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
      _uploadingPath = item.path;
    });

    try {
      final message = await widget.routeService.shareRoute(
        chatId: widget.chatId,
        gpxPath: item.path,
        title: item.title,
      );
      if (!mounted) return;
      widget.onShared(message);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _uploadingPath = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отправить маршрут: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Поделиться маршрутом',
        style: GoogleFonts.lexendDeca(
          fontWeight: FontWeight.w700,
          color: AuthColors.title,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 320,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _routes.isEmpty
                ? Center(
                    child: Text(
                      'Нет сохранённых маршрутов.\nСначала сохраните GPX на карте или в тренировке.',
                      textAlign: TextAlign.center,
                      style: authSubtitleStyle(),
                    ),
                  )
                : ListView.separated(
                    itemCount: _routes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _routes[index];
                      final isUploading =
                          _isUploading && _uploadingPath == item.path;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AuthColors.primaryGreen
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.route_rounded,
                            color: AuthColors.primaryGreen,
                          ),
                        ),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: authFieldStyle(),
                        ),
                        subtitle: Text(
                          item.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: authSubtitleStyle(),
                        ),
                        trailing: isUploading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded,
                                color: AuthColors.primaryGreen),
                        onTap: _isUploading ? null : () => _shareRoute(item),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
      ],
    );
  }
}
