import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:map_routing/data/models/route_share_snapshot.dart';
import 'package:map_routing/data/models/workout_metadata.dart';
import 'package:map_routing/data/services/chat_route_service.dart';
import 'package:map_routing/data/services/user_workout_storage.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:path/path.dart' as p;

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

  static Future<void> show(
    BuildContext context, {
    required String chatId,
    required ChatRouteService routeService,
    required void Function(Map<String, dynamic> message) onShared,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final sheetHeight = MediaQuery.sizeOf(ctx).height * 0.72;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: SizedBox(
            height: sheetHeight,
            child: AttachRouteDialog(
              chatId: chatId,
              routeService: routeService,
              onShared: onShared,
            ),
          ),
        );
      },
    );
  }

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
    final files = await UserWorkoutStorage.instance.listUserGpxFiles();

    final items = <LocalRouteItem>[];
    files.sort((a, b) => b.path.compareTo(a.path));

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
      final metadata = await WorkoutMetadata.loadFromGpxPath(item.path);
      final snapshot = metadata != null
          ? RouteShareSnapshot.fromMetadata(metadata)
          : null;
      final message = await widget.routeService.shareRoute(
        chatId: widget.chatId,
        gpxPath: item.path,
        title: item.title,
        snapshot: snapshot,
        photoPath: metadata?.photoPath,
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
      AppSnackBar.show(context, 'Не удалось отправить маршрут: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Поделиться маршрутом',
                    style: GoogleFonts.lexendDeca(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AuthColors.title,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _isUploading ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  color: AuthColors.title,
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_routes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AuthColors.primaryGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.route_rounded,
                size: 28,
                color: AuthColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Нет сохранённых маршрутов',
              textAlign: TextAlign.center,
              style: GoogleFonts.lexendDeca(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AuthColors.title,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Сначала сохраните GPX на карте или в истории тренировок.',
              textAlign: TextAlign.center,
              style: authSubtitleStyle(),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Выберите маршрут для отправки в чат',
            style: authSubtitleStyle(),
          ),
          const SizedBox(height: 16),
          Text(
            'Мои маршруты',
            style: GoogleFonts.lexendDeca(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AuthColors.title,
            ),
          ),
          const SizedBox(height: 8),
          ..._routes.map(_buildRouteTile),
        ],
      ),
    );
  }

  Widget _buildRouteTile(LocalRouteItem item) {
    final isUploading = _isUploading && _uploadingPath == item.path;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isUploading ? null : () => _shareRoute(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AuthColors.primaryGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.route_rounded,
                    color: AuthColors.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: authFieldStyle(),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: authSubtitleStyle(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isUploading)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    Icons.send_rounded,
                    color: _isUploading
                        ? AuthColors.hint
                        : AuthColors.primaryGreen,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
