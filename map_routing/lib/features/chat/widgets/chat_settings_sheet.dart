import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:map_routing/data/services/group_service.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';

class ChatSettingsSheet extends StatefulWidget {
  const ChatSettingsSheet({
    super.key,
    required this.chatId,
    required this.chatTitle,
    required this.photoUrl,
    required this.notificationsMuted,
    required this.isCreator,
    required this.chatService,
    required this.onUpdated,
  });

  final String chatId;
  final String chatTitle;
  final String? photoUrl;
  final bool notificationsMuted;
  final bool isCreator;
  final GroupChatService chatService;
  final void Function({
    String? title,
    String? photoUrl,
    bool? notificationsMuted,
  })
  onUpdated;

  static Future<void> show(
    BuildContext context, {
    required String chatId,
    required String chatTitle,
    required String? photoUrl,
    required bool notificationsMuted,
    required bool isCreator,
    required GroupChatService chatService,
    required void Function({
      String? title,
      String? photoUrl,
      bool? notificationsMuted,
    })
    onUpdated,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AuthColors.scaffoldBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: ChatSettingsSheet(
          chatId: chatId,
          chatTitle: chatTitle,
          photoUrl: photoUrl,
          notificationsMuted: notificationsMuted,
          isCreator: isCreator,
          chatService: chatService,
          onUpdated: onUpdated,
        ),
      ),
    );
  }

  @override
  State<ChatSettingsSheet> createState() => _ChatSettingsSheetState();
}

class _ChatSettingsSheetState extends State<ChatSettingsSheet> {
  late final TextEditingController _titleController;
  late bool _notificationsMuted;
  String _savedTitle = '';
  String? _photoUrl;
  bool _savingTitle = false;
  bool _uploadingPhoto = false;
  bool _savingMute = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.chatTitle);
    _savedTitle = widget.chatTitle;
    _notificationsMuted = widget.notificationsMuted;
    _photoUrl = widget.photoUrl;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _saveTitle() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      AppSnackBar.show(context, 'Введите название чата');
      return;
    }
    if (title == _savedTitle) return;

    setState(() => _savingTitle = true);
    try {
      await widget.chatService.updateChatTitle(widget.chatId, title);
      _savedTitle = title;
      widget.onUpdated(title: title);
      if (!mounted) return;
      AppSnackBar.show(context, 'Название обновлено');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _savingTitle = false);
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final url = await widget.chatService.uploadChatPhoto(
        widget.chatId,
        File(file.path),
      );
      setState(() => _photoUrl = url);
      widget.onUpdated(photoUrl: url);
      if (!mounted) return;
      AppSnackBar.show(context, 'Фото группы обновлено');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    if (_savingMute) return;
    setState(() {
      _notificationsMuted = value;
      _savingMute = true;
    });
    try {
      await widget.chatService.updateNotificationsMuted(widget.chatId, value);
      widget.onUpdated(notificationsMuted: value);
    } catch (e) {
      if (!mounted) return;
      setState(() => _notificationsMuted = !value);
      AppSnackBar.show(context, 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _savingMute = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AuthColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Настройки чата', style: authTitleStyle()),
            const SizedBox(height: 20),
            if (widget.isCreator) ...[
              Text('Фото группы', style: authLabelStyle()),
              const SizedBox(height: 10),
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _photoUrl != null && _photoUrl!.isNotEmpty
                          ? Image.network(
                              _photoUrl!,
                              key: ValueKey(_photoUrl),
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _photoPlaceholder(),
                            )
                          : _photoPlaceholder(),
                    ),
                    if (_uploadingPhoto)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      ),
                    IconButton.filled(
                      onPressed: _uploadingPhoto ? null : _pickPhoto,
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 0, 230, 119),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AuthTextField(
                label: 'Название группы',
                controller: _titleController,
                hint: 'Например, Бегуны района',
              ),
              const SizedBox(height: 12),
              AuthPrimaryButton(
                label: 'Сохранить название',
                isLoading: _savingTitle,
                onPressed: _savingTitle ? null : _saveTitle,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(height: 1, color: AuthColors.border),
              ),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE7E7E7)),
              ),
              child: SwitchListTile(
                value: _notificationsMuted,
                onChanged: _savingMute ? null : _toggleNotifications,
                activeThumbColor: AuthColors.primaryGreen,
                title: Text(
                  'Отключить уведомления',
                  style: GoogleFonts.lexendDeca(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AuthColors.title,
                  ),
                ),
                subtitle: Text(
                  'Не показывать push-уведомления для этого чата',
                  style: authSubtitleStyle(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      width: 96,
      height: 96,
      color: AuthColors.primaryGreen.withValues(alpha: 0.14),
      child: const Icon(
        Icons.groups_rounded,
        size: 40,
        color: AuthColors.primaryGreen,
      ),
    );
  }
}
