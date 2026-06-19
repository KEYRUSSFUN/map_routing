import 'dart:async';

import 'package:flutter/material.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/navigation/open_user_profile.dart';
import 'package:map_routing/core/widgets/user_avatar.dart';
import 'package:map_routing/data/models/chat_participant.dart';
import 'package:map_routing/data/services/group_service.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:map_routing/features/chat/widgets/add_chat_members_sheet.dart';
import 'package:map_routing/features/chat/widgets/chat_confirm_dialog.dart';
import 'package:map_routing/features/profile/presentation/user_profile_page.dart';

class ChatParticipantsSheet extends StatefulWidget {
  const ChatParticipantsSheet({
    super.key,
    required this.title,
    required this.chatId,
    required this.chatService,
    required this.participants,
    required this.creatorId,
    this.creatorName,
    required this.currentUserId,
    this.onParticipantsChanged,
    this.onChatDeleted,
  });

  final String title;
  final String chatId;
  final GroupChatService chatService;
  final List<ChatParticipant> participants;
  final int? creatorId;
  final String? creatorName;
  final String? currentUserId;
  final VoidCallback? onParticipantsChanged;
  final void Function(String chatId)? onChatDeleted;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String chatId,
    required GroupChatService chatService,
    required List<ChatParticipant> participants,
    required int? creatorId,
    String? creatorName,
    required String? currentUserId,
    VoidCallback? onParticipantsChanged,
    void Function(String chatId)? onChatDeleted,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ChatParticipantsSheet(
        title: title,
        chatId: chatId,
        chatService: chatService,
        participants: participants,
        creatorId: creatorId,
        creatorName: creatorName,
        currentUserId: currentUserId,
        onParticipantsChanged: onParticipantsChanged,
        onChatDeleted: onChatDeleted,
      ),
    );
  }

  @override
  State<ChatParticipantsSheet> createState() => _ChatParticipantsSheetState();
}

class _ChatParticipantsSheetState extends State<ChatParticipantsSheet> {
  late List<ChatParticipant> _participants;
  bool _isProcessing = false;

  bool get _isCreator {
    final creatorId = widget.creatorId?.toString();
    final currentUserId = widget.currentUserId;
    return creatorId != null &&
        currentUserId != null &&
        creatorId == currentUserId;
  }

  @override
  void initState() {
    super.initState();
    _participants = List<ChatParticipant>.from(widget.participants);
    unawaited(_reloadParticipants());
  }

  Future<void> _reloadParticipants() async {
    try {
      final details = await widget.chatService.getChatDetails(widget.chatId);
      if (!mounted) return;
      setState(() {
        _participants = ChatParticipant.fromJsonList(
          details['participants'],
          creatorId: widget.creatorId,
        );
      });
    } catch (_) {}
  }

  Future<void> _openAddMembers() async {
    if (_isProcessing) return;

    final existingIds = _participants
        .map((participant) => participant.userId)
        .whereType<String>()
        .toSet();

    await AddChatMembersSheet.show(
      context,
      chatId: widget.chatId,
      chatService: widget.chatService,
      existingMemberIds: existingIds,
      onMembersAdded: () async {
        await _reloadParticipants();
        widget.onParticipantsChanged?.call();
      },
    );

    if (!mounted) return;
    await _reloadParticipants();
  }

  Future<void> _removeMember(ChatParticipant participant) async {
    final memberId = participant.userId;
    if (memberId == null || _isProcessing) return;

    final confirmed = await ChatConfirmDialog.show(
      context,
      title: 'Исключить участника?',
      message: '${participant.name} будет удалён из группы.',
      confirmLabel: 'Исключить',
      destructive: true,
      icon: Icons.person_remove_outlined,
    );

    if (!confirmed || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      await widget.chatService.removeMember(widget.chatId, memberId);
      if (!mounted) return;
      setState(() {
        _participants.removeWhere((p) => p.userId == memberId);
        _isProcessing = false;
      });
      widget.onParticipantsChanged?.call();
      AppSnackBar.show(context, 'Участник исключён');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      AppSnackBar.show(context, 'Ошибка: $e');
    }
  }

  Future<void> _deleteChat() async {
    if (_isProcessing) return;

    final confirmed = await ChatConfirmDialog.show(
      context,
      title: 'Удалить группу?',
      message:
          'Чат «${widget.title}» и все сообщения будут удалены без возможности восстановления.',
      confirmLabel: 'Удалить',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );

    if (!confirmed || !mounted) return;

    final snackHost = AppSnackBarHost.maybeOf(context);
    setState(() => _isProcessing = true);
    try {
      await widget.chatService.deleteChat(widget.chatId);
      if (!mounted) return;

      final chatId = widget.chatId;
      Navigator.pop(context);
      widget.onChatDeleted?.call(chatId);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        snackHost?.show(
          'Группа удалена',
          variant: AppSnackBarVariant.success,
          displayDuration: const Duration(milliseconds: 2800),
          fadeInDuration: const Duration(milliseconds: 280),
          fadeOutDuration: const Duration(milliseconds: 420),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      final message = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : e.toString();
      AppSnackBar.show(context, 'Не удалось удалить группу: $message');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: GoogleFonts.lexendDeca(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AuthColors.title,
                    ),
                  ),
                ),
                Material(
                  color: AuthColors.primaryGreen.withValues(alpha: 0.14),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _isProcessing ? null : _openAddMembers,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.person_add_outlined,
                        color: AuthColors.primaryGreen,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_participants.isEmpty)
              Text('Нет данных по участникам', style: authSubtitleStyle())
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _participants.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AuthColors.divider),
                  itemBuilder: (context, index) {
                    final participant = _participants[index];
                    final canRemove = _isCreator &&
                        !participant.isCreator &&
                        participant.userId != null;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: SizedBox(
                        width: 40,
                        height: 40,
                        child: UserAvatar(
                          name: participant.name,
                          avatarUrl: participant.avatarUrl,
                          radius: 20,
                          onTap: participant.userId == null
                              ? null
                              : () => openUserProfile(
                                    context,
                                    participant.userId!,
                                  ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              participant.name,
                              style: GoogleFonts.lexendDeca(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AuthColors.title,
                              ),
                            ),
                          ),
                          if (participant.isCreator)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AuthColors.primaryGreen
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Создатель',
                                style: GoogleFonts.lexendDeca(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AuthColors.primaryGreen,
                                ),
                              ),
                            ),
                        ],
                      ),
                      trailing: _isProcessing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : canRemove
                              ? IconButton(
                                  tooltip: 'Исключить',
                                  onPressed: () => _removeMember(participant),
                                  icon: const Icon(
                                    Icons.person_remove_outlined,
                                    color: Colors.redAccent,
                                  ),
                                )
                              : (participant.userId == null
                                  ? null
                                  : const Icon(Icons.chevron_right)),
                      onTap: participant.userId == null
                          ? null
                          : () {
                              Navigator.pop(context);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => UserProfilePage(
                                    userId: participant.userId!,
                                  ),
                                ),
                              );
                            },
                    );
                  },
                ),
              ),
            if (_isCreator) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isProcessing ? null : _deleteChat,
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent),
                label: Text(
                  'Удалить группу',
                  style: GoogleFonts.lexendDeca(
                    fontWeight: FontWeight.w600,
                    color: Colors.redAccent,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
