import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:map_routing/data/geometry_provider.dart';
import 'package:map_routing/data/models/chat.dart';
import 'package:map_routing/data/models/route_share_snapshot.dart';
import 'package:map_routing/data/models/workout_metadata.dart';
import 'package:map_routing/data/models/workout_summary.dart';
import 'package:map_routing/data/services/chat_route_service.dart';
import 'package:map_routing/data/services/group_service.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:map_routing/features/profile/presentation/profile_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShareRouteToChatsDialog extends StatefulWidget {
  const ShareRouteToChatsDialog({
    super.key,
    required this.workout,
  });

  final WorkoutSummary workout;

  static Future<void> show(
    BuildContext context, {
    required WorkoutSummary workout,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final sheetHeight = MediaQuery.sizeOf(ctx).height * 0.85;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: SizedBox(
            height: sheetHeight,
            child: ShareRouteToChatsDialog(workout: workout),
          ),
        );
      },
    );
  }

  @override
  State<ShareRouteToChatsDialog> createState() => _ShareRouteToChatsDialogState();
}

class _ShareRouteToChatsDialogState extends State<ShareRouteToChatsDialog> {
  List<Chat> _chats = [];
  final Set<String> _selectedChatIds = {};
  bool _isLoading = true;
  bool _isSharing = false;
  String? _error;
  String? _gpxPath;

  @override
  void initState() {
    super.initState();
    _prepareAndLoad();
  }

  Future<void> _prepareAndLoad() async {
    try {
      final gpxPath = await _resolveGpxPath(widget.workout);
      if (gpxPath == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Не удалось подготовить файл маршрута';
          _isLoading = false;
        });
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'Требуется авторизация';
          _isLoading = false;
        });
        return;
      }

      final response = await GroupChatService(token: token).fetchUserChats();
      if (!mounted) return;
      setState(() {
        _gpxPath = gpxPath;
        _chats = response.chats;
        _isLoading = false;
        _error = _chats.isEmpty ? 'У вас пока нет групповых чатов' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить чаты: $e';
        _isLoading = false;
      });
    }
  }

  Future<String?> _resolveGpxPath(WorkoutSummary workout) async {
    if (workout.filePath.isNotEmpty) {
      final file = File(workout.filePath);
      if (await file.exists()) return workout.filePath;
    }

    if (workout.points.length >= 2) {
      return GeometryProvider.saveTrackedRouteAsGpx(workout.points);
    }

    return null;
  }

  void _toggleChat(String chatId) {
    setState(() {
      if (_selectedChatIds.contains(chatId)) {
        _selectedChatIds.remove(chatId);
      } else {
        _selectedChatIds.add(chatId);
      }
    });
  }

  Future<void> _shareToSelected() async {
    if (_isSharing || _gpxPath == null || _selectedChatIds.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) return;

    setState(() => _isSharing = true);

    final routeService = ChatRouteService(token: token);
    WorkoutMetadata? metadata;
    if (widget.workout.filePath.isNotEmpty) {
      metadata =
          await WorkoutMetadata.loadFromGpxPath(widget.workout.filePath);
    }
    final snapshot = metadata != null
        ? RouteShareSnapshot.fromMetadata(metadata)
        : RouteShareSnapshot.fromWorkout(widget.workout);
    final photoPath = metadata?.photoPath ?? widget.workout.photoPath;
    var successCount = 0;
    var failCount = 0;

    for (final chatId in _selectedChatIds) {
      try {
        await routeService.shareRoute(
          chatId: chatId,
          gpxPath: _gpxPath!,
          title: widget.workout.title,
          snapshot: snapshot,
          photoPath: photoPath,
        );
        successCount++;
      } catch (_) {
        failCount++;
      }
    }

    if (!mounted) return;

    if (successCount > 0 && failCount == 0) {
      AppSnackBar.show(
        context,
        successCount == 1
            ? 'Маршрут отправлен в чат'
            : 'Маршрут отправлен в $successCount чата',
        variant: AppSnackBarVariant.success,
      );
    } else if (successCount > 0) {
      AppSnackBar.show(
        context,
        'Отправлено в $successCount чат(ов), ошибок: $failCount',
      );
    } else {
      AppSnackBar.show(
        context,
        'Не удалось отправить маршрут',
        variant: AppSnackBarVariant.error,
      );
    }

    Navigator.pop(context);
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
                  onPressed: _isSharing ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  color: AuthColors.title,
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: AuthPrimaryButton(
              label: _selectedChatIds.isEmpty
                  ? 'Отправить'
                  : 'Отправить (${_selectedChatIds.length})',
              isLoading: _isSharing,
              onPressed: _selectedChatIds.isEmpty || _error != null
                  ? null
                  : _shareToSelected,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: const Color(0xFFF7F7F7),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                          widget.workout.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: authFieldStyle(),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Выберите один или несколько чатов',
                          style: authSubtitleStyle(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Групповые чаты',
            style: GoogleFonts.lexendDeca(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AuthColors.title,
            ),
          ),
          const SizedBox(height: 8),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: authSubtitleStyle(),
              ),
            )
          else
            ..._chats.map(_buildChatTile),
        ],
      ),
    );
  }

  Widget _buildChatTile(Chat chat) {
    final isSelected = _selectedChatIds.contains(chat.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected
            ? ProfileColors.primaryGreen.withValues(alpha: 0.08)
            : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isSharing ? null : () => _toggleChat(chat.id),
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
                    Icons.groups_rounded,
                    color: AuthColors.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chat.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: authFieldStyle(),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        chat.lastMessagePreview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: authSubtitleStyle(),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: isSelected ? AuthColors.primaryGreen : AuthColors.hint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
