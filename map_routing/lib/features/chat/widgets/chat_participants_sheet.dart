import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/data/models/chat_participant.dart';
import 'package:map_routing/data/services/group_service.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
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
  final VoidCallback? onChatDeleted;

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
    VoidCallback? onChatDeleted,
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

  String? get _creatorName =>
      widget.creatorName ?? ChatParticipant.creatorNameFrom(widget.participants);

  @override
  void initState() {
    super.initState();
    _participants = ChatParticipant.fromJsonList(
      widget.participants
          .map((p) => {
                'id': p.userId,
                'name': p.name,
                'isCreator': p.isCreator,
              })
          .toList(),
      creatorId: widget.creatorId,
    );
  }

  Future<void> _removeMember(ChatParticipant participant) async {
    final memberId = participant.userId;
    if (memberId == null || _isProcessing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Исключить участника?'),
        content: Text(
          '${participant.name} будет удалён из группы.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Исключить',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      await widget.chatService.removeMember(widget.chatId, memberId);
      if (!mounted) return;
      setState(() {
        _participants.removeWhere((p) => p.userId == memberId);
        _isProcessing = false;
      });
      widget.onParticipantsChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Участник исключён')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _deleteChat() async {
    if (_isProcessing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить группу?'),
        content: const Text(
          'Чат и все сообщения будут удалены без возможности восстановления.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Удалить',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      await widget.chatService.deleteChat(widget.chatId);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onChatDeleted?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Группа удалена')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
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
            Text(
              widget.title,
              style: GoogleFonts.lexendDeca(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AuthColors.title,
              ),
            ),
            if (_creatorName != null && _creatorName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Создатель: $_creatorName',
                style: authSubtitleStyle().copyWith(
                  fontWeight: FontWeight.w600,
                  color: AuthColors.primaryGreen,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (_participants.isEmpty)
              Text('Нет данных по участникам', style: authSubtitleStyle())
            else
              Flexible(
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
                      leading: CircleAvatar(
                        backgroundColor:
                            AuthColors.primaryGreen.withValues(alpha: 0.18),
                        child: Text(
                          participant.name.isEmpty
                              ? '?'
                              : participant.name[0].toUpperCase(),
                          style: GoogleFonts.lexendDeca(
                            fontWeight: FontWeight.w700,
                            color: AuthColors.title,
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
