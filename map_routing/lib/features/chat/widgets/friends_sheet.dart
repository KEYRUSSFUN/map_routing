import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/navigation/open_user_profile.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:map_routing/core/widgets/user_avatar.dart';
import 'package:map_routing/data/models/chat.dart';
import 'package:map_routing/data/models/friend.dart';
import 'package:map_routing/data/services/friend_service.dart';
import 'package:map_routing/data/services/group_service.dart';
import 'package:map_routing/data/services/user_search_service.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:map_routing/features/chat/widgets/user_search_result.dart';

class FriendsSheet extends StatefulWidget {
  const FriendsSheet({
    super.key,
    required this.userSearchService,
    required this.friendService,
    required this.chatService,
    required this.onChatOpened,
    this.initialFriends = const [],
  });

  final UserSearchService userSearchService;
  final FriendService friendService;
  final GroupChatService chatService;
  final void Function(Chat chat) onChatOpened;
  final List<Friend> initialFriends;

  static Future<void> show(
    BuildContext context, {
    required UserSearchService userSearchService,
    required FriendService friendService,
    required GroupChatService chatService,
    required void Function(Chat chat) onChatOpened,
    List<Friend> initialFriends = const [],
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) {
        final sheetHeight = MediaQuery.sizeOf(ctx).height * 0.85;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: SizedBox(
            height: sheetHeight,
            child: FriendsSheet(
              userSearchService: userSearchService,
              friendService: friendService,
              chatService: chatService,
              onChatOpened: onChatOpened,
              initialFriends: initialFriends,
            ),
          ),
        );
      },
    );
  }

  @override
  State<FriendsSheet> createState() => _FriendsSheetState();
}

class _FriendsSheetState extends State<FriendsSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  int _searchRequestId = 0;

  List<Friend> _friends = const [];
  bool _friendsLoading = false;
  String? _openingChatFriendId;

  String _searchQuery = '';
  List<Map<String, dynamic>> _searchResults = const [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _friends = List<Friend>.from(widget.initialFriends);
    unawaited(_loadFriends());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<Friend> get _visibleFriends {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _friends;
    return _friends
        .where((friend) => friend.name.toLowerCase().contains(query))
        .toList(growable: false);
  }

  Future<void> _loadFriends() async {
    if (!mounted) return;
    setState(() => _friendsLoading = true);
    try {
      final friends = await widget.friendService.fetchFriends();
      if (!mounted) return;
      setState(() {
        _friends = friends;
        _friendsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _friendsLoading = false);
      AppSnackBar.show(context, 'Не удалось загрузить друзей: $e');
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();

    final trimmed = value.trim();
    if (!mounted) return;

    setState(() {
      _searchQuery = value;
      if (trimmed.isEmpty) {
        _searchResults = const [];
        _isSearching = false;
      } else {
        _isSearching = true;
      }
    });

    if (trimmed.isEmpty) return;

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(trimmed);
    });
  }

  Future<void> _performSearch(String query) async {
    final requestId = ++_searchRequestId;

    try {
      final users = await widget.userSearchService.searchUsers(query);
      if (!mounted || requestId != _searchRequestId) return;

      setState(() {
        _searchResults = users;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted || requestId != _searchRequestId) return;

      setState(() {
        _searchResults = const [];
        _isSearching = false;
      });

      AppSnackBar.show(context, 'Ошибка поиска: $e');
    }
  }

  Future<void> _openChatWithFriend(Friend friend) async {
    if (_openingChatFriendId != null) return;

    setState(() => _openingChatFriendId = friend.id);
    try {
      final chat = await widget.chatService.getOrCreateDirectChat(friend.id);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onChatOpened(chat);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Не удалось открыть чат: $e');
    } finally {
      if (mounted) setState(() => _openingChatFriendId = null);
    }
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      style: authFieldStyle(),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Поиск друзей или новых пользователей',
        hintStyle: authHintStyle(),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AuthColors.body,
          size: 22,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AuthColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AuthColors.primaryGreen,
            width: 1.5,
          ),
        ),
      ),
      onChanged: _onSearchChanged,
    );
  }

  Widget _buildFriendsSection() {
    if (_friendsLoading && _friends.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_friends.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'У вас пока нет друзей. Найдите пользователя ниже и отправьте заявку.',
          style: authSubtitleStyle(),
        ),
      );
    }

    final visibleFriends = _visibleFriends;
    if (visibleFriends.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Среди друзей никого не найдено по запросу «${_searchQuery.trim()}»',
          style: authSubtitleStyle(),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < visibleFriends.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _FriendTile(
            friend: visibleFriends[i],
            isOpeningChat: _openingChatFriendId == visibleFriends[i].id,
            onMessageTap: () => _openChatWithFriend(visibleFriends[i]),
          ),
        ],
      ],
    );
  }

  Widget _buildAddUserSection() {
    if (_searchQuery.trim().isEmpty) {
      return Text(
        'Введите имя в поле поиска, чтобы найти нового пользователя и отправить заявку в друзья.',
        style: authSubtitleStyle(),
      );
    }

    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_searchResults.isEmpty) {
      return Text('Пользователи не найдены', style: authSubtitleStyle());
    }

    return Column(
      children: [
        for (var i = 0; i < _searchResults.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _buildSearchResultTile(_searchResults[i]),
        ],
      ],
    );
  }

  Widget _buildSearchResultTile(Map<String, dynamic> user) {
    final userId = user['id'].toString();

    return UserSearchResult(
      key: ValueKey('$userId-${user['relationshipStatus']}'),
      userId: userId,
      name: user['name']?.toString() ?? 'Без имени',
      avatarUrl: user['avatar_url']?.toString(),
      relationshipStatus: user['relationshipStatus']?.toString() ?? 'none',
      onAddFriend: (targetUserId) async {
        await widget.friendService.sendFriendRequest(targetUserId);
        await _loadFriends();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AuthColors.scaffoldBackground,
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
                    'Друзья',
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
                  color: AuthColors.title,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Добавление пользователя',
                    style: GoogleFonts.lexendDeca(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AuthColors.title,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSearchField(),
                  const SizedBox(height: 12),
                  _buildAddUserSection(),
                  const SizedBox(height: 20),
                  Text(
                    'Мои друзья',
                    style: GoogleFonts.lexendDeca(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AuthColors.title,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildFriendsSection(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friend,
    required this.onMessageTap,
    this.isOpeningChat = false,
  });

  static const _avatarRadius = 28.0;

  final Friend friend;
  final VoidCallback onMessageTap;
  final bool isOpeningChat;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F7F7),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => openUserProfile(context, friend.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(
                    name: friend.name,
                    avatarUrl: friend.avatarUrl,
                    radius: _avatarRadius,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: friend.isOnline
                            ? AuthColors.primaryGreen
                            : const Color(0xFFBDBDBD),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  friend.name,
                  style: GoogleFonts.lexendDeca(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AuthColors.title,
                  ),
                ),
              ),
              IconButton(
                onPressed: isOpeningChat ? null : onMessageTap,
                tooltip: 'Написать',
                icon: isOpeningChat
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: AuthColors.primaryGreen,
                        size: 24,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
