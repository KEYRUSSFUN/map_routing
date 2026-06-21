import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/network/backend_urls.dart';
import 'package:map_routing/core/network/config.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:map_routing/core/services/notification_service.dart';
import 'package:map_routing/core/widgets/app_bottom_nav_bar.dart';
import 'package:map_routing/data/models/chat.dart';
import 'package:map_routing/data/models/challenge.dart';
import 'package:map_routing/data/models/club.dart';
import 'package:map_routing/data/services/challenge_service.dart';
import 'package:map_routing/data/services/club_service.dart';
import 'package:map_routing/data/services/chat_session_cache.dart';
import 'package:map_routing/data/services/chat_message_cache.dart';
import 'package:map_routing/data/services/chat_details_cache.dart';
import 'package:map_routing/data/services/community_list_cache.dart';
import 'package:map_routing/features/challenges/presentation/challenge_detail_page.dart';
import 'package:map_routing/features/clubs/presentation/club_page.dart';
import 'package:map_routing/features/clubs/presentation/club_wizard_options.dart';
import 'package:map_routing/features/clubs/presentation/create_club_page.dart';
import 'package:map_routing/data/models/chat_participant.dart';
import 'package:map_routing/data/models/friend.dart';
import 'package:map_routing/data/services/friend_service.dart';
import 'package:map_routing/data/services/group_service.dart';
import 'package:map_routing/data/services/socket_chat_service.dart';
import 'package:map_routing/data/services/user_search_service.dart';
import 'package:map_routing/data/services/user_service.dart';
import 'package:map_routing/data/services/user_workout_storage.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:map_routing/features/chat/presentation/chat_screen_page.dart';
import 'package:map_routing/features/chat/widgets/chat_participants_sheet.dart';
import 'package:map_routing/features/chat/widgets/friends_sheet.dart';
import 'package:map_routing/features/chat/widgets/community_notifications_sheet.dart';
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
  ChallengeService? _challengeService;
  ClubService? _clubService;

  List<Chat> _chats = [];
  List<Friend> _friends = [];
  List<Map<String, dynamic>> _friendRequests = [];
  List<ChallengeSummary> _challenges = [];
  List<ClubSummary> _clubs = [];
  List<ClubSummary> _discoverClubs = [];
  final Set<String> _clubChatIds = {};
  final Set<int> _joiningChallengeIds = {};

  String? _currentUserId;
  bool _dataLoaded = false;
  bool _loading = false;
  bool _isSyncing = false;
  bool _challengesLoading = false;
  bool _clubsLoading = false;
  bool _discoverLoading = false;
  Object? _loadError;
  Object? _challengesError;
  Object? _clubsError;

  _CommunityTab _selectedTab = _CommunityTab.groups;
  String _searchQuery = '';
  Timer? _searchDebounce;

  int _lastRequestCount = 0;
  int _lastMessagesCount = 0;
  int _lastGroupInvitationCount = 0;
  int _unreadFriendRequestCount = 0;
  int _unreadGroupInvitationCount = 0;

  String? _openedChatId;
  bool _realtimeListenerAttached = false;
  late final void Function(dynamic) _realtimeMessageHandler;
  Timer? _silentRefreshTimer;
  Timer? _communityPersistTimer;
  bool _refreshInFlight = false;
  bool _pendingSilentRefresh = false;
  DateTime? _challengesLoadedAt;
  DateTime? _lastSuccessfulRefreshAt;
  static const _refreshTtl = Duration(seconds: 45);
  static const _challengesRefreshTtl = Duration(minutes: 3);

  int get _newMessageCount =>
      _chats.fold<int>(0, (sum, chat) => sum + chat.unreadCount);

  int get _notificationCount =>
      _unreadFriendRequestCount +
      _newMessageCount +
      _unreadGroupInvitationCount;

  List<Chat> get _filteredChats {
    final query = _searchQuery.trim().toLowerCase();
    final chats = _chats.where((chat) => !_clubChatIds.contains(chat.id));
    if (query.isEmpty) return chats.toList();
    return chats.where((chat) {
      return chat.title.toLowerCase().contains(query) ||
          chat.lastMessage.toLowerCase().contains(query) ||
          chat.lastMessageSender.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _realtimeMessageHandler = _handleRealtimeMessage;
    _bootstrap();
  }

  String _messagePreview(Map<String, dynamic> data) {
    final type = data['message_type']?.toString() ?? 'text';
    final content = data['content']?.toString() ?? '';
    if (type == 'route') {
      return content.isEmpty ? 'Маршрут' : content;
    }
    return content;
  }

  void handleRemoteChatDeleted(dynamic raw) {
    _handleRealtimeChatDeleted(raw);
  }

  void handleRemoteChatAdded(dynamic raw) {
    _handleRealtimeChatAdded(raw);
  }

  void handleRemoteChatUpdated(dynamic raw) {
    _handleRealtimeChatUpdated(raw);
  }

  void handlePresenceUpdate(dynamic raw) {
    if (raw is! Map) return;
    final userId = raw['user_id']?.toString();
    if (userId == null || userId.isEmpty) return;
    final isOnline = raw['is_online'] == true;

    final index = _friends.indexWhere((friend) => friend.id == userId);
    if (index < 0) return;

    final current = _friends[index];
    if (current.isOnline == isOnline) return;

    if (!mounted) return;
    setState(() {
      final updated = List<Friend>.from(_friends);
      updated[index] = Friend(
        id: current.id,
        avatarUrl: current.avatarUrl,
        isOnline: isOnline,
        name: current.name,
      );
      _friends = updated;
    });
    _persistCommunityListDebounced();
  }

  void applyChatMetadataUpdate(
    String chatId, {
    String? title,
    String? photoUrl,
    bool? notificationsMuted,
  }) {
    if (!mounted) return;

    final index = _chats.indexWhere((item) => item.id == chatId);
    if (index < 0) return;

    final current = _chats[index];
    final updated = current.copyWith(
      title: title,
      photoUrl: photoUrl,
      notificationsMuted: notificationsMuted,
    );

    if (current.title == updated.title &&
        current.photoUrl == updated.photoUrl &&
        current.notificationsMuted == updated.notificationsMuted) {
      return;
    }

    setState(() => _chats[index] = updated);
    _persistCommunityListDebounced();
  }

  void _handleRealtimeChatUpdated(dynamic raw) {
    if (!mounted || raw is! Map) return;

    final chatRaw = raw['chat'];
    if (chatRaw is! Map) return;

    final incoming = Chat.fromJson(Map<String, dynamic>.from(chatRaw));
    if (incoming.id.isEmpty) return;

    final index = _chats.indexWhere((item) => item.id == incoming.id);
    if (index < 0) return;

    final current = _chats[index];
    final updated = current.copyWith(
      title: incoming.title,
      photoUrl: incoming.photoUrl,
      notificationsMuted: incoming.notificationsMuted,
      creatorId: incoming.creatorId,
      creatorName: incoming.creatorName,
    );

    if (current.title == updated.title &&
        current.photoUrl == updated.photoUrl &&
        current.notificationsMuted == updated.notificationsMuted) {
      return;
    }

    setState(() => _chats[index] = updated);
    _persistCommunityListDebounced();
  }

  void _handleRealtimeChatDeleted(dynamic raw) {
    if (!mounted || raw is! Map) return;

    final chatId = raw['chat_id']?.toString();
    if (chatId == null || chatId.isEmpty) return;

    final hadChat = _chats.any((chat) => chat.id == chatId);
    if (!hadChat) return;

    _removeChatLocally(chatId);
    _purgeChatCache(chatId);

    if (_openedChatId != chatId) {
      unawaited(
        NotificationService.instance.show(
          title: 'Группа удалена',
          body: 'Создатель удалил групповой чат',
          payload: chatId,
        ),
      );
    }
  }

  void _handleRealtimeChatAdded(dynamic raw) {
    if (!mounted || raw is! Map) return;

    final chatRaw = raw['chat'];
    if (chatRaw is! Map) return;

    final chat = Chat.fromJson(Map<String, dynamic>.from(chatRaw));
    if (chat.id.isEmpty) return;
    if (_chats.any((item) => item.id == chat.id)) return;

    setState(() {
      _chats.insert(0, chat);
      if (chat.isInvitationUnread) {
        _unreadGroupInvitationCount++;
        _lastGroupInvitationCount = _unreadGroupInvitationCount;
      }
    });
    _persistCommunityListDebounced();
    SocketChatService.instance.joinChat(chat.id);

    unawaited(
      NotificationService.instance.show(
        title: 'Новая группа',
        body: chat.creatorName != null && chat.creatorName!.isNotEmpty
            ? '${chat.creatorName} добавил(а) вас в «${chat.title}»'
            : 'Вас добавили в «${chat.title}»',
        payload: chat.id,
      ),
    );
  }

  void _handleRealtimeMessage(dynamic raw) {
    if (!mounted || raw is! Map) return;

    final data = Map<String, dynamic>.from(raw);
    final chatId = data['chat_id']?.toString();
    if (chatId == null || chatId.isEmpty) return;

    final senderId = data['sender_id']?.toString() ?? '';
    final sender = data['sender']?.toString() ?? 'Участник';
    final preview = _messagePreview(data);
    final isOwn = senderId.isNotEmpty && senderId == _currentUserId;
    final isActiveChat = _openedChatId == chatId;

    final index = _chats.indexWhere((chat) => chat.id == chatId);
    if (index < 0) {
      unawaited(loadData(silent: true));
      return;
    }

    final current = _chats[index];
    final unreadCount = isOwn || isActiveChat
        ? current.unreadCount
        : current.unreadCount + 1;

    final updated = Chat(
      id: current.id,
      title: current.title,
      lastMessage: preview,
      lastMessageSender: sender,
      unreadCount: unreadCount,
      creatorId: current.creatorId,
      creatorName: current.creatorName,
      isInvitationUnread: current.isInvitationUnread,
      photoUrl: current.photoUrl,
      notificationsMuted: current.notificationsMuted,
    );

    if (current.lastMessage == preview &&
        current.lastMessageSender == sender &&
        current.unreadCount == unreadCount &&
        index == 0) {
      return;
    }

    setState(() {
      if (index == 0) {
        _chats[0] = updated;
      } else {
        _chats.removeAt(index);
        _chats.insert(0, updated);
      }
      _lastMessagesCount = _newMessageCount;
    });
    _persistCommunityListDebounced();

    if (!isOwn) {
      unawaited(
        SocketChatService.instance.acknowledgeMessageDelivery(
          chatId: chatId,
          messageId: data['id']?.toString(),
        ),
      );
    }

    if (!isOwn && !isActiveChat && !current.notificationsMuted) {
      unawaited(
        NotificationService.instance.show(
          title: current.title.isNotEmpty ? current.title : 'Новое сообщение',
          body: '$sender: $preview',
          payload: chatId,
        ),
      );
    }
  }

  Future<void> _connectRealtime() async {
    if (_chats.isEmpty) return;

    try {
      if (!_realtimeListenerAttached) {
        SocketChatService.instance.on('new_message', _realtimeMessageHandler);
        _realtimeListenerAttached = true;
      }
      unawaited(
        SocketChatService.instance.ensureConnected(backendBaseUrl).then((_) {
          SocketChatService.instance.joinUserRoom();
          SocketChatService.instance.refreshChatRooms();
          SocketChatService.instance.ensureJoinedChats(
            _chats.map((chat) => chat.id),
          );
        }),
      );
    } catch (_) {
      // Realtime is optional; silent refresh will catch up later.
    }
  }

  void _scheduleSilentRefresh({bool chatsOnly = true}) {
    _silentRefreshTimer?.cancel();
    _silentRefreshTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      unawaited(_runSilentRefresh(chatsOnly: chatsOnly));
    });
  }

  Future<void> _runSilentRefresh({bool chatsOnly = true}) async {
    if (_refreshInFlight) {
      _pendingSilentRefresh = true;
      return;
    }
    _refreshInFlight = true;
    try {
      await loadData(
        silent: true,
        chatsOnly: chatsOnly,
        showSyncIndicator: false,
      );
    } finally {
      _refreshInFlight = false;
      if (_pendingSilentRefresh && mounted) {
        _pendingSilentRefresh = false;
        _scheduleSilentRefresh(chatsOnly: chatsOnly);
      }
    }
  }

  void _finalizeChatReturn(String chatId) {
    final session = ChatSessionCache.instance.get(chatId);
    final index = _chats.indexWhere((item) => item.id == chatId);
    if (index < 0) return;

    final current = _chats[index];
    var lastMessage = current.lastMessage;
    var lastMessageSender = current.lastMessageSender;

    if (session != null && session.messages.isNotEmpty) {
      final last = session.messages.first;
      final senderId = last['sender_id']?.toString() ?? '';
      final sender = last['sender']?.toString() ?? '';
      final isOwn = senderId.isNotEmpty && senderId == _currentUserId;
      lastMessage = last['content']?.toString() ?? '';
      lastMessageSender = isOwn ? 'Вы' : sender;
    }

    final updated = current.copyWith(
      lastMessage: lastMessage,
      lastMessageSender: lastMessageSender,
      unreadCount: 0,
      title: session != null && session.chatTitle.isNotEmpty
          ? session.chatTitle
          : current.title,
      photoUrl: session?.photoUrl ?? current.photoUrl,
    );

    if (current.lastMessage == updated.lastMessage &&
        current.lastMessageSender == updated.lastMessageSender &&
        current.unreadCount == updated.unreadCount &&
        current.title == updated.title &&
        current.photoUrl == updated.photoUrl) {
      return;
    }

    setState(() {
      _chats[index] = updated;
      _lastMessagesCount = _newMessageCount;
    });
    _persistCommunityListDebounced();
  }

  /// Обновляет поля чатов с сервера, не меняя порядок, который видит пользователь.
  List<Chat> _mergeChatsPreservingOrder(
    List<Chat> current,
    List<Chat> incoming,
  ) {
    if (current.isEmpty) return incoming;

    final incomingById = {for (final chat in incoming) chat.id: chat};
    final merged = <Chat>[];
    final seen = <String>{};

    for (final chat in current) {
      final updated = incomingById[chat.id];
      if (updated != null) {
        merged.add(updated);
        seen.add(chat.id);
      }
    }

    for (final chat in incoming) {
      if (!seen.contains(chat.id)) {
        merged.add(chat);
      }
    }

    return merged;
  }

  bool _chatsEqual(List<Chat> current, List<Chat> incoming) {
    if (current.length != incoming.length) return false;
    for (var i = 0; i < current.length; i++) {
      final a = current[i];
      final b = incoming[i];
      if (a.id != b.id ||
          a.unreadCount != b.unreadCount ||
          a.lastMessage != b.lastMessage ||
          a.lastMessageSender != b.lastMessageSender ||
          a.title != b.title ||
          a.isInvitationUnread != b.isInvitationUnread ||
          a.photoUrl != b.photoUrl ||
          a.notificationsMuted != b.notificationsMuted) {
        return false;
      }
    }
    return true;
  }

  bool _friendsEqual(List<Friend> current, List<Friend> incoming) {
    if (current.length != incoming.length) return false;
    for (var i = 0; i < current.length; i++) {
      final a = current[i];
      final b = incoming[i];
      if (a.id != b.id ||
          a.name != b.name ||
          a.isOnline != b.isOnline ||
          a.avatarUrl != b.avatarUrl) {
        return false;
      }
    }
    return true;
  }

  bool _friendRequestsEqual(
    List<Map<String, dynamic>> current,
    List<Map<String, dynamic>> incoming,
  ) {
    if (current.length != incoming.length) return false;
    for (var i = 0; i < current.length; i++) {
      final a = current[i];
      final b = incoming[i];
      if (a['id']?.toString() != b['id']?.toString() ||
          a['isUnread'] != b['isUnread'] ||
          a['name']?.toString() != b['name']?.toString()) {
        return false;
      }
    }
    return true;
  }

  void _applyFullRefresh({
    required List<Chat> chats,
    required List<Friend> friends,
    required List<Map<String, dynamic>> friendRequests,
    required int unreadRequests,
    required int unreadInvitationCount,
  }) {
    final mergedChats = _mergeChatsPreservingOrder(_chats, chats);
    final chatsChanged = !_chatsEqual(_chats, mergedChats);
    final friendsChanged = !_friendsEqual(_friends, friends);
    final requestsChanged = !_friendRequestsEqual(
      _friendRequests,
      friendRequests,
    );
    final countsChanged =
        _unreadFriendRequestCount != unreadRequests ||
        _unreadGroupInvitationCount != unreadInvitationCount;

    if (!chatsChanged &&
        !friendsChanged &&
        !requestsChanged &&
        !countsChanged) {
      return;
    }

    setState(() {
      if (chatsChanged) _chats = mergedChats;
      if (friendsChanged) _friends = friends;
      if (requestsChanged) _friendRequests = friendRequests;
      if (countsChanged) {
        _unreadFriendRequestCount = unreadRequests;
        _unreadGroupInvitationCount = unreadInvitationCount;
      }
    });
  }

  void _applyChatsIfChanged(
    List<Chat> incoming, {
    required int unreadInvitationCount,
  }) {
    final merged = _mergeChatsPreservingOrder(_chats, incoming);
    if (_chatsEqual(_chats, merged) &&
        _unreadGroupInvitationCount == unreadInvitationCount) {
      return;
    }
    setState(() {
      _chats = merged;
      _unreadGroupInvitationCount = unreadInvitationCount;
    });
  }

  Route<String?> _chatRoute(Chat chat) {
    return PageRouteBuilder<String?>(
      settings: RouteSettings(name: '/chat/${chat.id}'),
      pageBuilder: (context, animation, secondaryAnimation) => ChatScreen(
        chatId: chat.id,
        initialTitle: chat.title,
        initialSession: ChatSessionCache.instance.get(chat.id),
        onChatMetadataChanged:
            ({String? title, String? photoUrl, bool? notificationsMuted}) {
              applyChatMetadataUpdate(
                chat.id,
                title: title,
                photoUrl: photoUrl,
                notificationsMuted: notificationsMuted,
              );
            },
      ),
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation = animation.drive(
          Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic)),
        );
        return SlideTransition(
          position: offsetAnimation,
          child: RepaintBoundary(child: child),
        );
      },
    );
  }

  Future<void> _warmChatSessionCache(Chat chat, {String? userId}) async {
    final resolvedUserId =
        userId ?? await UserWorkoutStorage.instance.getStoredUserId();
    if (resolvedUserId == null) return;
    await ChatSessionCache.instance.warmFromDisk(
      userId: resolvedUserId,
      chatId: chat.id,
      fallbackTitle: chat.title,
    );
  }

  void _removeChatLocally(String chatId) {
    if (!mounted) return;
    final index = _chats.indexWhere((chat) => chat.id == chatId);
    if (index < 0) return;

    setState(() {
      _chats.removeAt(index);
      _lastMessagesCount = _newMessageCount;
    });
    _persistCommunityListDebounced();
    SocketChatService.instance.forgetChat(chatId);
  }

  void _purgeChatCache(String chatId) {
    ChatSessionCache.instance.remove(chatId);
    final userId = _currentUserId;
    if (userId == null) return;
    unawaited(
      Future.wait([
        ChatMessageCache.instance.clearChat(userId: userId, chatId: chatId),
        ChatDetailsCache.instance.clear(userId: userId, chatId: chatId),
      ]),
    );
  }

  Future<void> _openChat(Chat chat) async {
    _openedChatId = chat.id;

    unawaited(_warmChatSessionCache(chat, userId: _currentUserId));

    final deletedChatId = await Navigator.push<String?>(
      context,
      _chatRoute(chat),
    );

    _openedChatId = null;
    if (!mounted) return;

    if (deletedChatId != null && deletedChatId.isNotEmpty) {
      _removeChatLocally(deletedChatId);
      _purgeChatCache(deletedChatId);
      return;
    }

    _finalizeChatReturn(chat.id);
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      loadData();
      return;
    }

    final userId = await UserWorkoutStorage.instance.syncUserIdFromToken(token);
    if (userId != null) {
      final cached = await CommunityListCache.instance.load(userId: userId);
      if (cached != null && mounted) {
        setState(() {
          _applySnapshot(cached, userId: userId);
          _dataLoaded = true;
          _loading = false;
        });
        unawaited(_connectRealtime());
      }
    }

    loadData(silent: _dataLoaded);
  }

  void _applySnapshot(
    CommunityListSnapshot snapshot, {
    required String userId,
  }) {
    _currentUserId = userId;
    _chats = snapshot.chats;
    _friends = snapshot.friends;
    _friendRequests = snapshot.friendRequests;
    _unreadFriendRequestCount = snapshot.unreadFriendRequestCount;
    _unreadGroupInvitationCount = snapshot.unreadGroupInvitationCount;
    _lastRequestCount = _unreadFriendRequestCount;
    _lastMessagesCount = _newMessageCount;
    _lastGroupInvitationCount = _unreadGroupInvitationCount;
  }

  Future<void> _persistCommunityList() async {
    final userId = _currentUserId;
    if (userId == null) return;
    await CommunityListCache.instance.save(
      userId: userId,
      chats: _chats,
      friends: _friends,
      friendRequests: _friendRequests,
      unreadFriendRequestCount: _unreadFriendRequestCount,
      unreadGroupInvitationCount: _unreadGroupInvitationCount,
    );
  }

  void _persistCommunityListDebounced() {
    _communityPersistTimer?.cancel();
    _communityPersistTimer = Timer(const Duration(milliseconds: 450), () {
      unawaited(_persistCommunityList());
    });
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
    _silentRefreshTimer?.cancel();
    _communityPersistTimer?.cancel();
    if (_realtimeListenerAttached) {
      SocketChatService.instance.off('new_message', _realtimeMessageHandler);
      _realtimeListenerAttached = false;
    }
    chatListRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    if (_openedChatId != null) return;
    if (_selectedTab == _CommunityTab.challenges) {
      _loadChallenges();
    }
  }

  Future<void> _markNotificationsSeen() async {
    final hasUnreadRequests =
        _unreadFriendRequestCount > 0 ||
        _friendRequests.any((request) => request['isUnread'] == true);
    final hasUnreadInvites =
        _unreadGroupInvitationCount > 0 ||
        _chats.any((chat) => chat.isInvitationUnread);

    if (!hasUnreadRequests && !hasUnreadInvites) {
      return;
    }

    try {
      if (_friendService != null && hasUnreadRequests) {
        await _friendService!.markFriendRequestsSeen();
      }
      if (_chatService != null && hasUnreadInvites) {
        await _chatService!.markGroupInvitationsSeen();
      }
      await NotificationService.instance.cancelAll();
      if (!mounted) return;

      final needsChatUpdate = _chats.any((chat) => chat.isInvitationUnread);
      final needsRequestUpdate = _friendRequests.any(
        (request) => request['isUnread'] == true,
      );

      setState(() {
        _unreadFriendRequestCount = 0;
        _unreadGroupInvitationCount = 0;
        _lastGroupInvitationCount = 0;
        if (needsRequestUpdate) {
          for (final request in _friendRequests) {
            request['isUnread'] = false;
          }
        }
        if (needsChatUpdate) {
          for (var i = 0; i < _chats.length; i++) {
            final chat = _chats[i];
            if (!chat.isInvitationUnread) continue;
            _chats[i] = chat.copyWith(isInvitationUnread: false);
          }
        }
      });
    } catch (_) {
      // Ignore marking errors; list refresh will retry later.
    }
  }

  Future<void> loadDataIfStale({
    bool silent = true,
    bool chatsOnly = false,
    bool showSyncIndicator = false,
  }) {
    if (_lastSuccessfulRefreshAt != null &&
        DateTime.now().difference(_lastSuccessfulRefreshAt!) < _refreshTtl) {
      return Future.value();
    }
    return loadData(
      silent: silent,
      chatsOnly: chatsOnly,
      showSyncIndicator: showSyncIndicator,
    );
  }

  Future<void> loadData({
    bool silent = false,
    bool chatsOnly = false,
    bool showSyncIndicator = true,
  }) {
    final showFullLoader = !silent && !_dataLoaded;
    if (showFullLoader) {
      setState(() => _loading = true);
    } else if (_dataLoaded && mounted && showSyncIndicator) {
      setState(() => _isSyncing = true);
    }

    return _initializeServiceAndLoadData(chatsOnly: chatsOnly)
        .then((_) async {
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

          await _persistCommunityList();
          await _connectRealtime();

          if (_loading || _isSyncing || _loadError != null || !_dataLoaded) {
            setState(() {
              _dataLoaded = true;
              _loading = false;
              _isSyncing = false;
              _loadError = null;
            });
          } else {
            _dataLoaded = true;
          }

          _lastSuccessfulRefreshAt = DateTime.now();
        })
        .catchError((error) {
          if (!mounted) return;
          setState(() {
            if (!_dataLoaded) {
              _loadError = error;
              _loading = false;
            }
            _isSyncing = false;
          });
        });
  }

  Future<void> _initializeServiceAndLoadData({bool chatsOnly = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login_page');
      throw Exception('Токен не найден');
    }

    _chatService ??= GroupChatService(token: token);
    _friendService ??= FriendService(token: token);
    _userSearchService ??= UserSearchService(token: token);
    _challengeService ??= ChallengeService(token: token);
    _clubService ??= ClubService(token: token);

    if (chatsOnly && _currentUserId != null) {
      final chatsResponse = await _chatService!.fetchUserChats();
      if (!mounted) return;
      _applyChatsIfChanged(
        chatsResponse.chats,
        unreadInvitationCount: chatsResponse.unreadInvitationCount,
      );
      return;
    }

    if (_currentUserId == null) {
      final userInfo = await UserService().fetchUserInfo();
      if (userInfo == null) {
        throw Exception('Не удалось получить информацию о пользователе');
      }
      final userId = userInfo['id']?.toString();
      if (userId == null) {
        throw Exception('Не найден идентификатор пользователя');
      }
      _currentUserId = userId;
      await UserWorkoutStorage.instance.setCurrentUserId(userId);
    }

    final chatsFuture = _chatService!.fetchUserChats();
    final socialFuture = Future.wait([
      _friendService!.fetchFriends(),
      _friendService!.fetchFriendRequests(),
    ]);

    final chatsResponse = await chatsFuture;
    final social = await socialFuture;
    final friends = social[0] as List<Friend>;
    final requests = social[1] as List<Map<String, dynamic>>;
    final unreadRequests = requests
        .where((request) => request['isUnread'] == true)
        .length;

    if (!mounted) return;
    _applyFullRefresh(
      chats: chatsResponse.chats,
      friends: friends,
      friendRequests: requests,
      unreadRequests: unreadRequests,
      unreadInvitationCount: chatsResponse.unreadInvitationCount,
    );
  }

  Future<void> _createNewChat() async {
    if (_chatService == null) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Данные пользователя еще загружаются');
      return;
    }

    CreateChatDialog.show(
      context,
      friends: _friends,
      chatService: _chatService!,
      onChatCreated: (newChat) {
        if (!mounted) return;
        if (_chats.any((chat) => chat.id == newChat.id)) return;
        setState(() => _chats.insert(0, newChat));
        SocketChatService.instance.joinChat(newChat.id);
        _persistCommunityListDebounced();
      },
    );
  }

  Future<void> _acceptFriendRequest(String requestId) async {
    if (_friendService == null) return;
    try {
      await _friendService!.acceptFriendRequest(requestId);
      await _initializeServiceAndLoadData();
      if (!mounted) return;
      AppSnackBar.show(context, 'Заявка принята');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Ошибка: $e');
    }
  }

  Future<void> _rejectFriendRequest(String requestId) async {
    if (_friendService == null) return;
    try {
      await _friendService!.rejectFriendRequest(requestId);
      await _initializeServiceAndLoadData();
      if (!mounted) return;
      AppSnackBar.show(context, 'Заявка отклонена');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Ошибка: $e');
    }
  }

  void _showNotificationsSheet() {
    unawaited(_markNotificationsSeen());

    final notificationChats = _chats
        .where((chat) => chat.unreadCount > 0 || chat.isInvitationUnread)
        .toList(growable: false);

    unawaited(
      CommunityNotificationsSheet.show(
        context,
        friendRequests: _friendRequests,
        unreadChats: notificationChats,
        onAcceptRequest: _acceptFriendRequest,
        onRejectRequest: _rejectFriendRequest,
        onOpenChat: _openChat,
      ),
    );
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
      final creatorName =
          details['creatorName']?.toString() ??
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
        onChatDeleted: (chatId) {
          _removeChatLocally(chatId);
          _purgeChatCache(chatId);
        },
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Не удалось загрузить участников: $e');
    }
  }

  Future<void> _showFriendsSheet() async {
    if (_userSearchService == null ||
        _friendService == null ||
        _chatService == null) {
      AppSnackBar.show(context, 'Данные ещё загружаются');
      return;
    }

    await FriendsSheet.show(
      context,
      userSearchService: _userSearchService!,
      friendService: _friendService!,
      chatService: _chatService!,
      initialFriends: _friends,
      onChatOpened: (chat) {
        if (!mounted) return;
        if (!_chats.any((item) => item.id == chat.id)) {
          setState(() => _chats.insert(0, chat));
          SocketChatService.instance.joinChat(chat.id);
          _persistCommunityListDebounced();
        }
        unawaited(_openChat(chat));
      },
    );
    if (!mounted) return;
    await loadData(silent: true, showSyncIndicator: false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && !_dataLoaded) {
      return const Scaffold(
        backgroundColor: AuthColors.scaffoldBackground,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null && !_dataLoaded) {
      return Scaffold(
        backgroundColor: AuthColors.scaffoldBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Ошибка: $_loadError', style: authSubtitleStyle()),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => loadData(),
                child: const Text('Повторить'),
              ),
            ],
          ),
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
            onTap: _showNotificationsSheet,
          ),
          IconButton(
            onPressed: _showFriendsSheet,
            tooltip: 'Друзья',
            icon: const FaIcon(FontAwesomeIcons.userGroup, size: 16),
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
        if (_isSyncing)
          const LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: Color(0xFFE8EDF0),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _CommunitySegmented(
            selected: _selectedTab,
            groupBadge: _unreadFriendRequestCount + _unreadGroupInvitationCount,
            onChanged: (value) {
              setState(() => _selectedTab = value);
              if (value == _CommunityTab.challenges) {
                _maybeLoadChallenges();
              }
              if (value == _CommunityTab.clubs) {
                _maybeLoadClubs();
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
                if (_selectedTab == _CommunityTab.clubs) {
                  unawaited(_loadDiscoverClubs());
                }
              });
            },
            style: authFieldStyle(),
            decoration: InputDecoration(
              hintText: switch (_selectedTab) {
                _CommunityTab.clubs => 'Поиск клубов...',
                _ => 'Поиск групп и чатов...',
              },
              hintStyle: authHintStyle(),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AuthColors.hint,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
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
    final bottomPadding = AppBottomNavBar.scrollEndPadding(context);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _CommunityCreateBanner(
                title: 'Создать группу',
                subtitle: 'Пригласите друзей и общайтесь вместе',
                onTap: _createNewChat,
              ),
              const SizedBox(height: 16),
              _SectionTitle(
                title: 'Ваши группы и чаты',
                trailing: _newMessageCount == 0
                    ? null
                    : _Badge(
                        count: _newMessageCount,
                        color: AuthColors.primaryGreen,
                      ),
              ),
              const SizedBox(height: 14),
            ]),
          ),
        ),
        if (chats.isEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
            sliver: const SliverToBoxAdapter(
              child: _EmptyCard(
                title: 'У вас пока нет групп',
                subtitle: 'Создайте первый групповой чат и пригласите друзей.',
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
            sliver: SliverList.builder(
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                return RepaintBoundary(
                  child: _ChatListTile(
                    key: ValueKey(chat.id),
                    chat: chat,
                    onOpen: () => _openChat(chat),
                    onParticipantsTap: () => _showParticipants(chat),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _maybeLoadChallenges() {
    if (_challenges.isNotEmpty &&
        _challengesLoadedAt != null &&
        DateTime.now().difference(_challengesLoadedAt!) <
            _challengesRefreshTtl) {
      return;
    }
    _loadChallenges();
  }

  Future<void> refreshChallenges({bool force = false}) async {
    if (!force &&
        _challengesLoadedAt != null &&
        DateTime.now().difference(_challengesLoadedAt!) <
            _challengesRefreshTtl) {
      return;
    }
    await _loadChallenges();
  }

  Future<void> _loadChallenges() async {
    if (_challengeService == null) return;
    setState(() {
      _challengesLoading = true;
      _challengesError = null;
    });
    try {
      final challenges = await _challengeService!.fetchChallenges();
      if (!mounted) return;
      setState(() {
        _challenges = challenges;
        _challengesLoading = false;
        _challengesLoadedAt = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _challengesError = e;
        _challengesLoading = false;
      });
    }
  }

  Future<void> _openChallenge(ChallengeSummary challenge) async {
    if (_challengeService == null) return;

    if (challenge.isJoined) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChallengeDetailPage(
            challengeId: challenge.id,
            challengeService: _challengeService!,
          ),
        ),
      );
      _loadChallenges();
      return;
    }

    setState(() => _joiningChallengeIds.add(challenge.id));
    try {
      await _challengeService!.joinChallenge(challenge.id);
      if (!mounted) return;
      AppSnackBar.show(context, 'Вы присоединились к челленджу');
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChallengeDetailPage(
            challengeId: challenge.id,
            challengeService: _challengeService!,
          ),
        ),
      );
      _loadChallenges();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Ошибка: $e');
    } finally {
      if (mounted) {
        setState(() => _joiningChallengeIds.remove(challenge.id));
      }
    }
  }

  Widget _buildChallengesTab() {
    if (_challengesLoading && _challenges.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_challengesError != null && _challenges.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Не удалось загрузить челленджи',
                style: authSubtitleStyle(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loadChallenges,
                child: Text('Повторить', style: authLinkStyle()),
              ),
            ],
          ),
        ),
      );
    }

    if (_challenges.isEmpty) {
      return ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          AppBottomNavBar.scrollEndPadding(context),
        ),
        children: const [
          _EmptyCard(
            title: 'Пока нет челленджей',
            subtitle: 'Скоро здесь появятся новые соревнования.',
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChallenges,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          AppBottomNavBar.scrollEndPadding(context),
        ),
        itemCount: _challenges.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final challenge = _challenges[index];
          return _ChallengeCard(
            challenge: challenge,
            isJoining: _joiningChallengeIds.contains(challenge.id),
            onTap: () => _openChallenge(challenge),
          );
        },
      ),
    );
  }

  Widget _buildClubsTab() {
    if (_clubsLoading && _clubs.isEmpty && !_discoverLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final searchQuery = _searchQuery.trim();
    final myClubs = searchQuery.isEmpty
        ? _clubs
        : _clubs.where((club) {
            final q = searchQuery.toLowerCase();
            return club.title.toLowerCase().contains(q) ||
                club.description.toLowerCase().contains(q) ||
                (club.locationLabel?.toLowerCase().contains(q) ?? false);
          }).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        AppBottomNavBar.scrollEndPadding(context),
      ),
      children: [
        _CommunityCreateBanner(
          title: 'Создать свой клуб',
          subtitle: 'Объедините бегунов и делитесь тренировками',
          onTap: _openCreateClub,
        ),
        if (_clubsError != null) ...[
          const SizedBox(height: 16),
          Text(
            'Не удалось загрузить клубы',
            style: authSubtitleStyle(),
            textAlign: TextAlign.center,
          ),
        ],
        if (searchQuery.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _SectionTitle(title: 'Найденные клубы'),
          if (_discoverLoading && _discoverClubs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_discoverClubs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Клубы не найдены. Попробуйте изменить запрос.',
                textAlign: TextAlign.center,
                style: authSubtitleStyle(),
              ),
            )
          else
            ..._discoverClubs.map(
              (club) => _ClubListTile(
                club: club,
                onTap: () => _openClub(club),
                onJoin: (!club.isMember && !club.membershipPending)
                    ? () => _joinClub(club)
                    : null,
              ),
            ),
        ] else if (_clubs.isEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'У вас пока нет клубов. Создайте своё спортивное сообщество или найдите клуб через поиск.',
            textAlign: TextAlign.center,
            style: authSubtitleStyle(),
          ),
        ],
        if (myClubs.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _SectionTitle(title: 'Мои клубы'),
          ...myClubs.map(
            (club) => _ClubListTile(club: club, onTap: () => _openClub(club)),
          ),
        ],
      ],
    );
  }

  void _maybeLoadClubs({bool force = false}) {
    if (_clubsLoading) return;
    if (!force && _clubs.isNotEmpty) return;
    unawaited(_loadClubs(force: force));
  }

  Future<void> _loadClubs({bool force = false}) async {
    if (_clubsLoading) return;
    if (_clubService == null) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return;
      _clubService = ClubService(token: token);
    }

    setState(() {
      _clubsLoading = true;
      _clubsError = null;
    });

    try {
      final clubs = await _clubService!.fetchMyClubs();
      if (!mounted) return;
      setState(() {
        _clubs = clubs;
        _clubChatIds
          ..clear()
          ..addAll(
            clubs
                .map((club) => club.groupChatId?.toString())
                .whereType<String>(),
          );
        _clubsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _clubsError = error;
        _clubsLoading = false;
      });
    }
  }

  Future<void> _loadDiscoverClubs() async {
    final query = _searchQuery.trim();
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _discoverClubs = [];
        _discoverLoading = false;
      });
      return;
    }

    if (_clubService == null) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) return;
      _clubService = ClubService(token: token);
    }

    setState(() => _discoverLoading = true);

    try {
      final clubs = await _clubService!.discoverClubs(query);
      if (!mounted) return;
      setState(() {
        _discoverClubs = clubs;
        _discoverLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _discoverLoading = false);
    }
  }

  Future<void> _joinClub(ClubSummary club) async {
    if (_clubService == null) return;

    try {
      await _clubService!.joinClub(club.id);
      final updated = await _clubService!.fetchClub(club.id);
      if (!mounted) return;

      AppSnackBar.show(
        context,
        club.isClosed || updated.membershipPending
            ? 'Заявка на вступление отправлена'
            : 'Вы вступили в клуб',
      );

      await _loadClubs(force: true);
      if (_searchQuery.trim().isNotEmpty) {
        await _loadDiscoverClubs();
      }
      await _openClub(updated);
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.show(context, error.toString());
    }
  }

  Future<void> _openCreateClub() async {
    if (_clubService == null) {
      final service = await ClubService.fromPrefs();
      if (service == null) {
        if (!mounted) return;
        AppSnackBar.show(context, 'Не удалось авторизоваться');
        return;
      }
      _clubService = service;
    }

    if (!mounted) return;
    final created = await Navigator.of(context).push<ClubSummary>(
      MaterialPageRoute(
        builder: (_) => CreateClubPage(clubService: _clubService!),
      ),
    );

    if (!mounted || created == null) return;
    await _loadClubs(force: true);
    await _initializeServiceAndLoadData(chatsOnly: false);
    if (created.groupChatId != null) {
      await _openClub(created);
    }
  }

  Future<void> _openClub(ClubSummary club) async {
    if (_clubService == null) {
      final service = await ClubService.fromPrefs();
      if (service == null || !mounted) return;
      _clubService = service;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClubPage(
          clubService: _clubService!,
          clubId: club.id,
          initialClub: club,
        ),
      ),
    );

    if (!mounted) return;
    await _loadClubs(force: true);
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

  final FaIconData icon;
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
    super.key,
    required this.chat,
    required this.onOpen,
    required this.onParticipantsTap,
  });

  final Chat chat;
  final VoidCallback onOpen;
  final VoidCallback onParticipantsTap;

  bool get _hasHighlight => chat.unreadCount > 0 || chat.isInvitationUnread;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen,
          child: Ink(
            decoration: BoxDecoration(
              color: _hasHighlight ? const Color(0xFFF4FFF8) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _hasHighlight
                    ? AuthColors.primaryGreen.withValues(alpha: 0.28)
                    : const Color(0xFFE3E8EE),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AuthColors.primaryGreen.withValues(
                            alpha: 0.14,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Container(
                        key: ValueKey(chat.photoUrl ?? chat.id),
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient:
                              chat.photoUrl == null || chat.photoUrl!.isEmpty
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF00E676),
                                    Color(0xFF00C853),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          image:
                              chat.photoUrl != null && chat.photoUrl!.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(chat.photoUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: chat.photoUrl == null || chat.photoUrl!.isEmpty
                            ? const Center(
                                child: FaIcon(
                                  FontAwesomeIcons.comments,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              )
                            : null,
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
                                  fontSize: 16,
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
                        const SizedBox(height: 5),
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
                          style: authSubtitleStyle().copyWith(
                            color: _hasHighlight
                                ? AuthColors.title.withValues(alpha: 0.72)
                                : AuthColors.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: onParticipantsTap,
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(
                          Icons.group_outlined,
                          size: 20,
                          color: AuthColors.body,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.challenge,
    required this.onTap,
    this.isJoining = false,
  });

  final ChallengeSummary challenge;
  final VoidCallback onTap;
  final bool isJoining;

  static const _cardBlack = Color(0xFF17171A);
  static const _daysLeft = Color(0xFFFFD166);

  @override
  Widget build(BuildContext context) {
    final actionLabel = challenge.isJoined ? 'Открыть' : 'Участвовать';
    final progress = challenge.isJoined ? challenge.progressPercent : 0.0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: isJoining ? null : onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [
                _cardBlack.withValues(alpha: 0.92),
                _cardBlack.withValues(alpha: 0.78),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -18,
                top: -18,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AuthColors.primaryGreen.withValues(alpha: 0.28),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AuthColors.primaryGreen.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AuthColors.primaryGreen.withValues(
                            alpha: 0.35,
                          ),
                        ),
                      ),
                      child: Center(
                        child: FaIcon(
                          challenge.icon,
                          size: 20,
                          color: AuthColors.primaryGreen,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            challenge.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.lexendDeca(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            challenge.daysLeftLabel,
                            style: GoogleFonts.lexendDeca(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _daysLeft,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            challenge.participantsLabel,
                            style: GoogleFonts.lexendDeca(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AuthColors.primaryGreen,
                            ),
                          ),
                          if (challenge.isJoined &&
                              challenge.myProgress != null) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress.clamp(0.0, 1.0),
                                      minHeight: 5,
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.12,
                                      ),
                                      color: AuthColors.primaryGreen,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  challenge.formatProgress(
                                    challenge.myProgress!,
                                  ),
                                  style: GoogleFonts.lexendDeca(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isJoining)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AuthColors.primaryGreen,
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: challenge.isJoined
                              ? AuthColors.primaryGreen
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: challenge.isJoined
                              ? null
                              : Border.all(
                                  color: AuthColors.primaryGreen.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: onTap,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Text(
                                actionLabel,
                                style: GoogleFonts.lexendDeca(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: challenge.isJoined
                                      ? Colors.white
                                      : AuthColors.primaryGreen,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

class _CommunityCreateBanner extends StatelessWidget {
  const _CommunityCreateBanner({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [
                AuthColors.primaryGreen.withValues(alpha: 0.14),
                AuthColors.primaryGreen.withValues(alpha: 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: AuthColors.primaryGreen.withValues(alpha: 0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: AuthColors.primaryGreen.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AuthColors.primaryGreen.withValues(alpha: 0.14),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: AuthColors.primaryGreen,
                  size: 24,
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
                    Text(
                      subtitle,
                      style: authSubtitleStyle().copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: AuthColors.primaryGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClubListTile extends StatelessWidget {
  const _ClubListTile({required this.club, required this.onTap, this.onJoin});

  final ClubSummary club;
  final VoidCallback onTap;
  final VoidCallback? onJoin;

  Color get _sportAccent {
    switch (club.sportType) {
      case 'running':
      case 'all_sports':
        return AuthColors.primaryGreen;
      case 'cycling':
        return const Color(0xFF5C9FD6);
      case 'triathlon':
        return const Color(0xFF8E7CC3);
      case 'alpine_skiing':
        return const Color(0xFF6FA8DC);
      default:
        return AuthColors.primaryGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = absoluteBackendUrl(club.avatarUrl);
    final sportLabel = clubSportLabel(club.sportType);
    final location = clubLocationLabel(club.locationLabel);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE3E8EE)),
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _sportAccent.withValues(alpha: 0.22),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: Container(
                      width: 56,
                      height: 56,
                      color: _sportAccent.withValues(alpha: 0.06),
                      child: isLoadableNetworkUrl(avatarUrl)
                          ? Image.network(
                              avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _ClubAvatarFallback(
                                title: club.title,
                                accent: _sportAccent,
                              ),
                            )
                          : _ClubAvatarFallback(
                              title: club.title,
                              accent: _sportAccent,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        club.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lexendDeca(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AuthColors.title,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _ClubMetaChip(label: sportLabel, color: _sportAccent),
                          if (location.isNotEmpty)
                            _ClubMetaChip(
                              label: location,
                              color: AuthColors.body,
                              outlined: true,
                            ),
                          _ClubMetaChip(
                            label:
                                '${club.memberCount} ${_membersLabel(club.memberCount)}',
                            color: AuthColors.title,
                            outlined: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (club.isMember)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AuthColors.body,
                  )
                else if (club.membershipPending)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AuthColors.border),
                    ),
                    child: Text(
                      'Заявка',
                      style: GoogleFonts.lexendDeca(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AuthColors.body,
                      ),
                    ),
                  )
                else if (onJoin != null)
                  Material(
                    color: AuthColors.primaryGreen,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: onJoin,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Text(
                          club.isClosed ? 'Заявка' : 'Вступить',
                          style: GoogleFonts.lexendDeca(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AuthColors.body,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _membersLabel(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return 'участник';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'участника';
    }
    return 'участников';
  }
}

class _ClubMetaChip extends StatelessWidget {
  const _ClubMetaChip({
    required this.label,
    required this.color,
    this.outlined = false,
  });

  final String label;
  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: outlined
            ? Border.all(color: const Color(0xFFE3E8EE))
            : Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: GoogleFonts.lexendDeca(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: outlined ? AuthColors.body : color,
        ),
      ),
    );
  }
}

class _ClubAvatarFallback extends StatelessWidget {
  const _ClubAvatarFallback({
    required this.title,
    this.accent = AuthColors.primaryGreen,
  });

  final String title;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final initial = title.trim().isNotEmpty
        ? title.trim()[0].toUpperCase()
        : '?';
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.22),
            accent.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.lexendDeca(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: accent,
          ),
        ),
      ),
    );
  }
}
