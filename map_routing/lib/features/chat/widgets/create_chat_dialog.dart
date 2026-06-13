import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/data/models/chat.dart';
import 'package:map_routing/data/models/friend.dart';
import 'package:map_routing/data/services/group_service.dart';
import 'package:map_routing/core/widgets/user_avatar.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:map_routing/features/profile/presentation/profile_ui.dart';

class CreateChatDialog extends StatefulWidget {
  const CreateChatDialog({
    super.key,
    required this.friends,
    required this.chatService,
    required this.onChatCreated,
    required this.currentUserId,
  });

  final List<Friend> friends;
  final GroupChatService chatService;
  final void Function(Chat newChat) onChatCreated;
  final String currentUserId;

  static Future<void> show(
    BuildContext context, {
    required List<Friend> friends,
    required GroupChatService chatService,
    required void Function(Chat newChat) onChatCreated,
    required String currentUserId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: CreateChatDialog(
          friends: friends,
          chatService: chatService,
          onChatCreated: onChatCreated,
          currentUserId: currentUserId,
        ),
      ),
    );
  }

  @override
  State<CreateChatDialog> createState() => _CreateChatDialogState();
}

class _CreateChatDialogState extends State<CreateChatDialog> {
  final TextEditingController _titleController = TextEditingController();
  final Set<String> _selectedFriendIds = {};
  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название группы')),
      );
      return;
    }

    final participants = <String>{
      widget.currentUserId,
      ..._selectedFriendIds,
    };

    if (participants.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите хотя бы одного участника')),
      );
      return;
    }

    setState(() => _isCreating = true);
    try {
      final newChat = await widget.chatService.createGroupChat(
        title,
        participants.toList(),
      );
      widget.onChatCreated(newChat);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                    'Новая группа',
                    style: GoogleFonts.lexendDeca(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AuthColors.title,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthTextField(
                    label: 'Название группы',
                    hint: 'Например, Бегуны района',
                    controller: _titleController,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Участники',
                    style: GoogleFonts.lexendDeca(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AuthColors.title,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (widget.friends.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Добавьте друзей, чтобы пригласить их в группу.',
                        style: authSubtitleStyle(),
                      ),
                    )
                  else
                    ...widget.friends.map((friend) {
                      final isSelected =
                          _selectedFriendIds.contains(friend.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: isSelected
                              ? ProfileColors.primaryGreen
                                  .withValues(alpha: 0.08)
                              : const Color(0xFFF7F7F7),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedFriendIds.remove(friend.id);
                                } else {
                                  _selectedFriendIds.add(friend.id);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  UserAvatar(
                                    name: friend.name,
                                    avatarUrl: friend.avatarUrl,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      friend.name,
                                      style: authFieldStyle(),
                                    ),
                                  ),
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.circle_outlined,
                                    color: isSelected
                                        ? AuthColors.primaryGreen
                                        : AuthColors.hint,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 20),
                  AuthPrimaryButton(
                    label: 'Создать группу',
                    isLoading: _isCreating,
                    onPressed: _isCreating ? null : _create,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
