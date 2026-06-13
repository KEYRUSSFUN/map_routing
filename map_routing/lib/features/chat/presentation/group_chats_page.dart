import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/services/notification_service.dart';
import 'package:map_routing/core/widgets/app_bottom_nav_bar.dart';
import 'package:map_routing/data/models/chat.dart';
import 'package:map_routing/data/models/chat_participant.dart';
import 'package:map_routing/data/models/friend.dart';
import 'package:map_routing/data/services/friend_service.dart';
import 'package:map_routing/data/services/group_service.dart';
import 'package:map_routing/data/services/user_search_service.dart';
import 'package:map_routing/data/services/user_service.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:map_routing/features/chat/presentation/chat_screen_page.dart';
import 'package:map_routing/features/chat/widgets/chat_participants_sheet.dart';
import 'package:map_routing/features/chat/widgets/add_user_sheet.dart';
import 'package:map_routing/features/chat/widgets/create_chat_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

final RouteObserver<PageRoute> chatListRouteObserver =
    RouteObserver<PageRoute>();

enum _CommunityTab { groups, challenges, clubs }

class GroupChatsPage extends StatefulWidget {
  const GroupChatsPage({super.key});

  @override
  State<GroupChatsPage> createState() => GroupChatsPageState();
}

class GroupChatsPageState extends State<GroupChatsPage> with RouteAware {
  GroupChatService? _chatService;
  FriendService? _friendService;
  UserSearchService? _userSearchService;

  List<Chat> _chats = [];
  List<Friend> _friends = [];
  List<Map<String, dynamic>> _friendRequests = [];

  String? _currentUserId;
  bool _dataLoaded = false;
  bool _loading = false;
  Object? _loadError;

  _CommunityTab _selectedTab = _CommunityTab.groups;
  String _searchQuery = '';
  Timer? _searchDebounce;

  int _lastRequestCount = 0;
  int _lastMessagesCount = 0;
  int _lastGroupInvitationCount = 0;
  int _unreadFriendRequestCount = 0;
  int _unreadGroupInvitationCount = 0;

  int get _requestCount => _friendRequests.length;

  int get _newMessageCount =>
      _chats.fold<int>(0, (sum, chat) => sum + chat.unreadCount);

  int get _notificationCount =>
      _unreadFriendRequestCount +
      _newMessageCount +
      _unreadGroupInvitationCount;

  List<Chat> get _filteredChats {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _chats;
    return _chats.where((chat) {
      return chat.title.toLowerCase().contains(query) ||
          chat.lastMessage.toLowerCase().contains(query) ||
          chat.lastMessageSender.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      chatListRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    chatListRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    loadData();
  }

  Future<void> _markNotificationsSeen() async {
    try {
      if (_friendService != null) {
        await _friendService!.markFriendRequestsSeen();
      }
      if (_chatService != null) {
        await _chatService!.markGroupInvitationsSeen();
      }
      await NotificationService.instance.cancelAll();
      if (!mounted) return;
      setState(() {
        _unreadFriendRequestCount = 0;
        _unreadGroupInvitationCount = 0;
        _lastGroupInvitationCount = 0;
        for (final request in _friendRequests) {
          request['isUnread'] = false;
        }
        _chats = _chats
            .map(
              (chat) => Chat(
                id: chat.id,
                title: chat.title,
                lastMessage: chat.lastMessage,
                lastMessageSender: chat.lastMessageSender,
                unreadCount: chat.unreadCount,
                creatorId: chat.creatorId,
                creatorName: chat.creatorName,
                isInvitationUnread: false,
              ),
            )
            .toList();
      });
    } catch (_) {
      // Ignore marking errors; list refresh will retry later.
    }
  }

  void loadData({bool silent = false}) {
    if (_loading) return;
    if (!silent || !_dataLoaded) {
      setState(() => _loading = true);
    }

    _initializeServiceAndLoadData().then((_) async {
      if (!mounted) return;

      if (_dataLoaded) {
        if (_unreadFriendRequestCount > _lastRequestCount) {
          await NotificationService.instance.show(
            title: 'Новые заявки в друзья',
            body: 'У вас $_unreadFriendRequestCount новых заявок в друзья',
          );
        }

        if (_newMessageCount > _lastMessagesCount) {
          await NotificationService.instance.show(
            title: 'Новые сообщения',
            body: 'У вас $_newMessageCount непрочитанных сообщений',
          );
        }

        if (_unreadGroupInvitationCount > _lastGroupInvitationCount) {
          final count = _unreadGroupInvitationCount;
          final groupWord = count == 1
              ? 'группу'
              : count < 5
                  ? 'группы'
                  : 'групп';
          await NotificationService.instance.show(
            title: 'Новые группы',
            body: 'Вас добавили в $count $groupWord',
          );
        }
      }

      _lastRequestCount = _unreadFriendRequestCount;
      _lastMessagesCount = _newMessageCount;
      _lastGroupInvitationCount = _unreadGroupInvitationCount;

      setState(() {
        _dataLoaded = true;
        _loading = false;
        _loadError = null;
      });

      if (_selectedTab == _CommunityTab.groups) {
        await _markNotificationsSeen();
      }
    }).catchError((error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
        _dataLoaded = false;
      });
    });
  }

  Future<void> _initializeServiceAndLoadData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login_page');
      throw Exception('Токен не найден');
    }

    _chatService = GroupChatService(token: token);
    _friendService = FriendService(token: token);
    _userSearchService = UserSearchService(token: token);

    final userService = UserService();
    final userInfo = await userService.fetchUserInfo();
    if (userInfo == null) {
      throw Exception('Не удалось получить информацию о пользователе');
    }

    final userId = userInfo['id']?.toString();
    if (userId == null) {
      throw Exception('Не найден идентификатор пользователя');
    }

    final chatsResponse = await _chatService!.fetchUserChats();
    final friends = await _friendService!.fetchFriends();
    final requests = await _friendService!.fetchFriendRequests();
    final unreadRequests =
        requests.where((request) => request['isUnread'] == true).length;

    if (!mounted) return;
    setState(() {
      _chats = chatsResponse.chats;
      _friends = friends;
      _friendRequests = requests;
      _unreadFriendRequestCount = unreadRequests;
      _unreadGroupInvitationCount = chatsResponse.unreadInvitationCount;
      _currentUserId = userId;
    });
  }

  Future<void> _createNewChat() async {
    if (_currentUserId == null || _chatService == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Данные пользователя еще загружаются')),
      );
      return;
    }

    CreateChatDialog.show(
      context,
      friends: _friends,
      chatService: _chatService!,
      onChatCreated: (newChat) {
        if (!mounted) return;
        setState(() => _chats.add(newChat));
      },
      currentUserId: _currentUserId!,
    );
  }

  Future<void> _acceptFriendRequest(String requestId) async {
    if (_friendService == null) return;
    try {
      await _friendService!.acceptFriendRequest(requestId);
      await _initializeServiceAndLoadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заявка принята')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _rejectFriendRequest(String requestId) async {
    if (_friendService == null) return;
    try {
      await _friendService!.rejectFriendRequest(requestId);
      await _initializeServiceAndLoadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заявка отклонена')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _showParticipants(Chat chat) async {
    if (_chatService == null) return;

    try {
      final details = await _chatService!.getChatDetails(chat.id);
      if (!mounted) return;

      final creatorId =
          (details['creatorId'] as num?)?.toInt() ?? chat.creatorId;
      final participants = ChatParticipant.fromJsonList(
        details['participants'],
        creatorId: creatorId,
      );
      final creatorName = details['creatorName']?.toString() ??
          ChatParticipant.creatorNameFrom(participants);

      await ChatParticipantsSheet.show(
        context,
        title: 'Участники группы',
        chatId: chat.id,
        chatService: _chatService!,
        participants: participants,
        creatorId: creatorId,
        creatorName: creatorName,
        currentUserId: _currentUserId,
        onParticipantsChanged: loadData,
        onChatDeleted: loadData,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить участников: $e')),
      );
    }
  }

  void _showSearchDialog() {
    if (_userSearchService == null || _friendService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Данные ещё загружаются')),
      );
      return;
    }

    AddUserSheet.show(
      context,
      userSearchService: _userSearchService!,
      friendService: _friendService!,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Ошибка: $_loadError', style: authSubtitleStyle()),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: loadData,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AuthColors.scaffoldBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AuthColors.scaffoldBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text('Сообщество', style: authTitleStyle()),
        actions: [
          _BadgeIconButton(
            icon: FontAwesomeIcons.bell,
            count: _notificationCount,
            onTap: () {
              _markNotificationsSeen();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Заявки: $_unreadFriendRequestCount, '
                    'группы: $_unreadGroupInvitationCount, '
                    'сообщения: $_newMessageCount',
                  ),
                ),
              );
            },
          ),
          IconButton(
            onPressed: _showSearchDialog,
            icon: const FaIcon(FontAwesomeIcons.userPlus, size: 16),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _dataLoaded ? _buildContent() : const SizedBox.shrink(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _CommunitySegmented(
            selected: _selectedTab,
            groupBadge: _unreadFriendRequestCount + _unreadGroupInvitationCount,
            onChanged: (value) {
              setState(() => _selectedTab = value);
              if (value == _CommunityTab.groups) {
                _markNotificationsSeen();
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            onChanged: (value) {
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 250), () {
                if (!mounted) return;
                setState(() => _searchQuery = value);
              });
            },
            style: authFieldStyle(),
            decoration: InputDecoration(
              hintText: 'Поиск групп и чатов...',
              hintStyle: authHintStyle(),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: AuthColors.hint),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AuthColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AuthColors.border),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: switch (_selectedTab) {
            _CommunityTab.groups => _buildGroupsTab(),
            _CommunityTab.challenges => _buildChallengesTab(),
            _CommunityTab.clubs => _buildClubsTab(),
          },
        ),
      ],
    );
  }

  Widget _buildGroupsTab() {
    final chats = _filteredChats;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        AppBottomNavBar.scrollEndPadding(context),
      ),
      children: [
        _SectionTitle(
          title: 'Ваши группы и чаты',
          trailing: _newMessageCount == 0
              ? null
              : _Badge(count: _newMessageCount, color: AuthColors.primaryGreen),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _createNewChat,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: Text(
              'Создать группу',
              style: GoogleFonts.lexendDeca(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AuthColors.primaryGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (chats.isEmpty)
          const _EmptyCard(
            title: 'У вас пока нет групп',
            subtitle: 'Создайте первый групповой чат и пригласите друзей.',
          )
        else
          ...chats.map(
            (chat) => _ChatListTile(
              chat: chat,
              onOpen: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      chatId: chat.id,
                      initialTitle: chat.title,
                    ),
                  ),
                );
                if (_chatService != null) {
                  try {
                    await _chatService!.markChatAsRead(chat.id);
                  } catch (_) {}
                }
                if (mounted) loadData();
              },
              onParticipantsTap: () => _showParticipants(chat),
            ),
          ),
        const SizedBox(height: 16),
        _SectionTitle(
          title: 'Заявки в друзья',
          trailing: _unreadFriendRequestCount == 0
              ? null
              : _Badge(
                  count: _unreadFriendRequestCount,
                  color: const Color(0xFFFFB300),
                ),
        ),
        if (_friendRequests.isEmpty)
          const _EmptyCard(
            title: 'Новых заявок нет',
            subtitle: 'Когда кто-то отправит заявку, она появится здесь.',
          )
        else
          ..._friendRequests.map(
            (request) => _FriendRequestCard(
              userName: request['fromUserName'] ?? 'Неизвестный пользователь',
              onAccept: () => _acceptFriendRequest(request['fromUserId']),
              onReject: () => _rejectFriendRequest(request['fromUserId']),
            ),
          ),
      ],
    );
  }

  Widget _buildChallengesTab() {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        AppBottomNavBar.scrollEndPadding(context),
      ),
      children: const [
        _ChallengeCard(
          title: 'Недельный забег 25 км',
          subtitle: 'Осталось 4 дня',
          participants: '36 участников',
          icon: FontAwesomeIcons.personRunning,
        ),
        SizedBox(height: 10),
        _ChallengeCard(
          title: 'Городской велоспринт',
          subtitle: 'Старт через 1 день',
          participants: '19 участников',
          icon: FontAwesomeIcons.bicycle,
        ),
        SizedBox(height: 10),
        _ChallengeCard(
          title: 'Шаговый марафон',
          subtitle: 'Открыт весь месяц',
          participants: '112 участников',
          icon: FontAwesomeIcons.shoePrints,
        ),
      ],
    );
  }

  Widget _buildClubsTab() {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        AppBottomNavBar.scrollEndPadding(context),
      ),
      children: const [
        _ClubDiscoverCard(),
      ],
    );
  }

}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.lexendDeca(
                fontSize: 23,
                fontWeight: FontWeight.w700,
                color: AuthColors.title,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _CommunitySegmented extends StatelessWidget {
  const _CommunitySegmented({
    required this.selected,
    required this.onChanged,
    required this.groupBadge,
  });

  final _CommunityTab selected;
  final int groupBadge;
  final ValueChanged<_CommunityTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AuthColors.border),
      ),
      child: Row(
        children: [
          _SegmentButton(
            label: 'Группы',
            selected: selected == _CommunityTab.groups,
            badge: groupBadge,
            onTap: () => onChanged(_CommunityTab.groups),
          ),
          _SegmentButton(
            label: 'Челенджи',
            selected: selected == _CommunityTab.challenges,
            onTap: () => onChanged(_CommunityTab.challenges),
          ),
          _SegmentButton(
            label: 'Клубы',
            selected: selected == _CommunityTab.clubs,
            onTap: () => onChanged(_CommunityTab.clubs),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF5E7CE) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: GoogleFonts.lexendDeca(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? AuthColors.title : AuthColors.body,
                ),
              ),
              if ((badge ?? 0) > 0) ...[
                const SizedBox(width: 6),
                _Badge(count: badge!, color: const Color(0xFFFF7A00)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: GoogleFonts.lexendDeca(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _BadgeIconButton extends StatelessWidget {
  const _BadgeIconButton({
    required this.icon,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(onPressed: onTap, icon: FaIcon(icon, size: 16)),
        if (count > 0)
          Positioned(
            right: 8,
            top: 8,
            child: _Badge(count: count, color: const Color(0xFFFF4B55)),
          ),
      ],
    );
  }
}

class _ChatListTile extends StatelessWidget {
  const _ChatListTile({
    required this.chat,
    required this.onOpen,
    required this.onParticipantsTap,
  });

  final Chat chat;
  final VoidCallback onOpen;
  final VoidCallback onParticipantsTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onOpen,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE7E7E7)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x10000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB2F7CC), Color(0xFF7DE7AA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: FaIcon(
                      FontAwesomeIcons.comments,
                      size: 17,
                      color: Color(0xFF0F5132),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chat.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.lexendDeca(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AuthColors.title,
                              ),
                            ),
                          ),
                          if (chat.unreadCount > 0)
                            _Badge(
                              count: chat.unreadCount,
                              color: AuthColors.primaryGreen,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (chat.isInvitationUnread)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            chat.creatorName != null &&
                                    chat.creatorName!.isNotEmpty
                                ? '${chat.creatorName} добавил(а) вас в группу'
                                : 'Вас добавили в группу',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: authSubtitleStyle().copyWith(
                              color: AuthColors.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      Text(
                        chat.lastMessagePreview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: authSubtitleStyle(),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onParticipantsTap,
                  icon: const Icon(Icons.group_outlined),
                  tooltip: 'Участники',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FriendRequestCard extends StatelessWidget {
  const _FriendRequestCard({
    required this.userName,
    required this.onAccept,
    required this.onReject,
  });

  final String userName;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7E7E7)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AuthColors.primaryGreen.withValues(alpha: 0.18),
            child: Text(
              userName.isEmpty ? '?' : userName[0].toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              userName,
              style: GoogleFonts.lexendDeca(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AuthColors.title,
              ),
            ),
          ),
          IconButton(
            onPressed: onAccept,
            icon: const Icon(Icons.check_circle_rounded,
                color: AuthColors.primaryGreen),
            tooltip: 'Принять',
          ),
          IconButton(
            onPressed: onReject,
            icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent),
            tooltip: 'Отклонить',
          ),
        ],
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.title,
    required this.subtitle,
    required this.participants,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String participants;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E7E7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AuthColors.primaryGreen.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: FaIcon(icon, size: 18, color: AuthColors.title),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.lexendDeca(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AuthColors.title,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: authSubtitleStyle()),
                const SizedBox(height: 2),
                Text(
                  participants,
                  style: authSubtitleStyle().copyWith(
                    color: AuthColors.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
              onPressed: () {}, child: Text('Скоро', style: authLinkStyle())),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.lexendDeca(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AuthColors.title,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: authSubtitleStyle()),
        ],
      ),
    );
  }
}

class _ClubDiscoverCard extends StatelessWidget {
  const _ClubDiscoverCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E7E7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AuthColors.primaryGreen.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: FaIcon(FontAwesomeIcons.compass, color: AuthColors.title),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Открыть новые клубы',
                  style: GoogleFonts.lexendDeca(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AuthColors.title,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Найдите локальные спортивные сообщества и присоединяйтесь.',
                  style: authSubtitleStyle(),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Раздел клубов скоро будет расширен')),
              );
            },
            child: Text('Открыть', style: authLinkStyle()),
          ),
        ],
      ),
    );
  }
}

