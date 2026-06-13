import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/data/services/friend_service.dart';
import 'package:map_routing/data/services/user_search_service.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:map_routing/features/chat/widgets/user_search_result.dart';

class AddUserSheet extends StatefulWidget {
  const AddUserSheet({
    super.key,
    required this.userSearchService,
    required this.friendService,
  });

  final UserSearchService userSearchService;
  final FriendService friendService;

  static Future<void> show(
    BuildContext context, {
    required UserSearchService userSearchService,
    required FriendService friendService,
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
            child: AddUserSheet(
              userSearchService: userSearchService,
              friendService: friendService,
            ),
          ),
        );
      },
    );
  }

  @override
  State<AddUserSheet> createState() => _AddUserSheetState();
}

class _AddUserSheetState extends State<AddUserSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  int _searchRequestId = 0;

  String _searchQuery = '';
  List<Map<String, dynamic>> _searchResults = const [];
  bool _isSearching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
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

      if (!mounted) return;
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка поиска: $e')),
      );
    }
  }

  Widget _buildResults() {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_searchQuery.trim().isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Начните вводить имя, чтобы увидеть результаты',
          textAlign: TextAlign.center,
          style: authSubtitleStyle(),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Пользователи не найдены',
          textAlign: TextAlign.center,
          style: authSubtitleStyle(),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final userId = user['id'].toString();

        return UserSearchResult(
          key: ValueKey('$userId-${user['relationshipStatus']}'),
          userId: userId,
          name: user['name']?.toString() ?? 'Без имени',
          relationshipStatus:
              user['relationshipStatus']?.toString() ?? 'none',
          onAddFriend: (targetUserId) =>
              widget.friendService.sendFriendRequest(targetUserId),
        );
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
                    'Добавление пользователя',
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: AuthFormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Найдите пользователя по имени и отправьте заявку в друзья',
                    style: authSubtitleStyle(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    style: authFieldStyle(),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Введите имя пользователя',
                      hintStyle: authHintStyle(),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AuthColors.body,
                        size: 20,
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
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: _buildResults(),
            ),
          ),
        ],
      ),
    );
  }
}
