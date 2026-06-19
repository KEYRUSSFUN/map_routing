import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/navigation/open_user_profile.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:map_routing/core/widgets/user_avatar.dart';
import 'package:map_routing/data/models/friend.dart';
import 'package:map_routing/data/services/friend_service.dart';
import 'package:map_routing/data/services/group_service.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:map_routing/features/profile/presentation/profile_ui.dart';

class AddChatMembersSheet extends StatefulWidget {
  const AddChatMembersSheet({
    super.key,
    required this.chatId,
    required this.chatService,
    required this.existingMemberIds,
    this.onMembersAdded,
  });

  final String chatId;
  final GroupChatService chatService;
  final Set<String> existingMemberIds;
  final VoidCallback? onMembersAdded;

  static Future<void> show(
    BuildContext context, {
    required String chatId,
    required GroupChatService chatService,
    required Set<String> existingMemberIds,
    VoidCallback? onMembersAdded,
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
            child: AddChatMembersSheet(
              chatId: chatId,
              chatService: chatService,
              existingMemberIds: existingMemberIds,
              onMembersAdded: onMembersAdded,
            ),
          ),
        );
      },
    );
  }

  @override
  State<AddChatMembersSheet> createState() => _AddChatMembersSheetState();
}

class _AddChatMembersSheetState extends State<AddChatMembersSheet> {
  final Set<String> _selectedFriendIds = {};
  List<Friend> _friends = [];
  bool _isLoading = true;
  bool _isAdding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      final friends = await FriendService(token: widget.chatService.token)
          .fetchFriends();
      if (!mounted) return;
      setState(() {
        _friends = friends
            .where((friend) => !widget.existingMemberIds.contains(friend.id))
            .toList();
        _isLoading = false;
        _error = _friends.isEmpty ? 'Нет друзей для добавления' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Не удалось загрузить друзей: $e';
      });
    }
  }

  void _toggleFriend(String friendId) {
    setState(() {
      if (_selectedFriendIds.contains(friendId)) {
        _selectedFriendIds.remove(friendId);
      } else {
        _selectedFriendIds.add(friendId);
      }
    });
  }

  Future<void> _addSelected() async {
    if (_isAdding || _selectedFriendIds.isEmpty) return;

    setState(() => _isAdding = true);

    var successCount = 0;
    var failCount = 0;

    for (final friendId in _selectedFriendIds) {
      try {
        await widget.chatService.addMember(widget.chatId, friendId);
        successCount++;
      } catch (_) {
        failCount++;
      }
    }

    if (!mounted) return;

    if (successCount > 0) {
      widget.onMembersAdded?.call();
      Navigator.pop(context);
      AppSnackBar.show(
        context,
        failCount == 0
            ? (successCount == 1
                ? 'Участник добавлен в группу'
                : 'Добавлено участников: $successCount')
            : 'Добавлено: $successCount, ошибок: $failCount',
        variant: AppSnackBarVariant.success,
      );
      return;
    }

    setState(() => _isAdding = false);
    AppSnackBar.show(
      context,
      'Не удалось добавить участников',
      variant: AppSnackBarVariant.error,
    );
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
                    'Добавить участников',
                    style: GoogleFonts.lexendDeca(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AuthColors.title,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _isAdding ? null : () => Navigator.pop(context),
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
              label: _selectedFriendIds.isEmpty
                  ? 'Добавить'
                  : 'Добавить (${_selectedFriendIds.length})',
              isLoading: _isAdding,
              onPressed: _selectedFriendIds.isEmpty || _error != null
                  ? null
                  : _addSelected,
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
          Text(
            'Выберите друзей из списка',
            style: authSubtitleStyle(),
          ),
          const SizedBox(height: 12),
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
            ..._friends.map(_buildFriendTile),
        ],
      ),
    );
  }

  Widget _buildFriendTile(Friend friend) {
    final isSelected = _selectedFriendIds.contains(friend.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected
            ? ProfileColors.primaryGreen.withValues(alpha: 0.08)
            : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isAdding ? null : () => _toggleFriend(friend.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                UserAvatar(
                  name: friend.name,
                  avatarUrl: friend.avatarUrl,
                  onTap: () => openUserProfile(context, friend.id),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(friend.name, style: authFieldStyle()),
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
