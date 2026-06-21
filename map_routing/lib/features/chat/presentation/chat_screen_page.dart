import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/navigation/open_user_profile.dart';
import 'package:map_routing/core/network/config.dart';
import 'package:map_routing/core/widgets/app_confirm_dialog.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:map_routing/core/network/backend_urls.dart';
import 'package:map_routing/core/widgets/user_avatar.dart';
import 'package:map_routing/data/models/chat_participant.dart';
import 'package:map_routing/data/services/chat_details_cache.dart';
import 'package:map_routing/data/services/chat_message_cache.dart';
import 'package:map_routing/data/services/chat_session_cache.dart';
import 'package:map_routing/data/models/route_share_snapshot.dart';
import 'package:map_routing/data/services/chat_route_service.dart';
import 'package:map_routing/data/services/group_service.dart';
import 'package:map_routing/data/services/socket_chat_service.dart';
import 'package:map_routing/data/services/user_service.dart';
import 'package:map_routing/data/services/user_profile_cache.dart';
import 'package:map_routing/data/services/user_workout_storage.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:map_routing/features/chat/widgets/attach_route_dialog.dart';
import 'package:map_routing/shared/utils/backend_datetime.dart';
import 'package:map_routing/features/chat/widgets/chat_participants_sheet.dart';
import 'package:map_routing/features/chat/widgets/chat_settings_sheet.dart';
import 'package:map_routing/features/chat/widgets/chat_message_reactions.dart';
import 'package:map_routing/features/chat/widgets/chat_route_message_bubble.dart';
import 'package:map_routing/features/chat/utils/chat_message_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

final RouteObserver<PageRoute> chatRouteObserver = RouteObserver<PageRoute>();

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.chatId,
    this.initialTitle,
    this.initialSession,
    this.onChatMetadataChanged,
  });

  final String chatId;
  final String? initialTitle;
  final ChatSessionData? initialSession;
  final void Function({
    String? title,
    String? photoUrl,
    bool? notificationsMuted,
  })?
  onChatMetadataChanged;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with RouteAware {
  final TextEditingController _messageController = TextEditingController();
  final UserService _userService = UserService();
  final SocketChatService _socketService = SocketChatService.instance;

  late final void Function(dynamic) _onNewMessage;
  late final void Function(dynamic) _onMessageDeleted;
  late final void Function(dynamic) _onReactionsUpdated;
  late final void Function(dynamic) _onChatDeleted;
  late final void Function(dynamic) _onChatUpdated;
  late final void Function(dynamic) _onUserTyping;
  late final void Function(dynamic) _onMemberStateUpdated;

  String? _token;
  String? _currentUserId;
  String? _currentUserName;

  String _chatTitle = '';
  int? _creatorId;
  String? _creatorName;
  String? _chatPhotoUrl;
  bool _notificationsMuted = false;
  Map<String, String?> _participantAvatars = {};
  List<ChatParticipant> _participants = [];
  List<Map<String, dynamic>> _messages = [];

  Map<String, dynamic>? _replyTo;
  int _localCounter = 0;

  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isSending = false;
  bool _bootstrapStarted = false;
  bool _routeReady = false;
  bool _routeAnimationAttached = false;
  bool _messagesHydrating = false;
  Animation<double>? _routeAnimation;
  AnimationStatusListener? _routeAnimationListener;
  ChatSessionData? _pendingSession;
  final Set<String> _downloadingRouteKeys = {};
  Timer? _markReadDebounce;
  bool _markReadScheduled = false;
  bool _chatDeleted = false;
  final Map<String, String> _typingUsers = {};
  final Map<String, Timer> _typingExpireTimers = {};
  Timer? _typingPulseTimer;
  bool _typingSignalActive = false;
  final Map<String, DateTime?> _memberReadAt = {};
  final Map<String, DateTime?> _memberReceivedAt = {};

  @override
  void initState() {
    super.initState();
    _chatTitle = widget.initialTitle ?? '';
    _onNewMessage = (data) async {
      if (!mounted || _chatDeleted || data is! Map) return;
      final chatId = data['chat_id']?.toString();
      if (chatId != null && chatId != widget.chatId) return;

      final messageId = data['id'];
      final senderId = data['sender_id']?.toString() ?? 'unknown';
      final sender = data['sender']?.toString() ?? 'Участник';
      final content = data['content']?.toString() ?? '';

      final incoming = _normalizeMessage(
        senderId: senderId,
        sender: sender,
        content: content,
        timestamp: data['timestamp'],
        id: messageId,
        localId: messageId?.toString(),
        messageType: data['message_type'],
        routeShare: data['route_share'],
        reactions: data['reactions'],
        senderAvatarUrl: data['sender_avatar_url'],
        status: data['status'],
      );

      setState(() {
        if (messageId != null) {
          final idStr = messageId.toString();
          _messages.removeWhere((m) => m['id']?.toString() == idStr);
        }
        if (senderId == _currentUserId) {
          _messages.removeWhere(
            (m) =>
                m['sender_id'] == _currentUserId &&
                m['id'] == null &&
                m['content'] == incoming['content'],
          );
        }
        _messages.insert(0, incoming);
        if (senderId == _currentUserId) {
          _refreshOwnMessageStatuses();
        }
        _removeTypingUser(senderId);
      });
      _schedulePersistMessages();

      if (senderId != _currentUserId) {
        unawaited(
          _socketService.acknowledgeMessageDelivery(
            chatId: widget.chatId,
            messageId: messageId?.toString(),
          ),
        );
        _scheduleMarkChatAsRead();
      }
    };
    _onMessageDeleted = (data) {
      if (!mounted || _chatDeleted || data is! Map) return;
      final chatId = data['chat_id']?.toString();
      if (chatId != null && chatId != widget.chatId) return;
      _removeMessageFromList(data['message_id']);
    };
    _onReactionsUpdated = (data) {
      if (!mounted || _chatDeleted || data is! Map) return;
      final chatId = data['chat_id']?.toString();
      if (chatId != null && chatId != widget.chatId) return;
      final messageId = data['message_id'];
      if (messageId == null) return;
      _updateMessageReactions(messageId, _parseReactions(data['reactions']));
    };
    _onChatDeleted = (data) {
      if (!mounted || _chatDeleted || data is! Map) return;
      final chatId = data['chat_id']?.toString();
      if (chatId == null || chatId != widget.chatId) return;

      _chatDeleted = true;
      _cancelPendingWork();
      _socketService.forgetChat(chatId);
      ChatSessionCache.instance.remove(chatId);
      final userId = _currentUserId;
      if (mounted) {
        AppSnackBar.show(context, 'Группа была удалена');
        Navigator.pop(context, chatId);
      }
      if (userId != null) {
        unawaited(_purgeLocalChatStorage(userId, chatId));
      }
    };
    _onChatUpdated = (data) {
      if (!mounted || _chatDeleted || data is! Map) return;
      final chatRaw = data['chat'];
      if (chatRaw is! Map) return;
      final chatId = chatRaw['id']?.toString();
      if (chatId == null || chatId != widget.chatId) return;

      setState(() {
        final title = chatRaw['title']?.toString();
        if (title != null && title.isNotEmpty) {
          _chatTitle = title;
        }
        _chatPhotoUrl =
            absoluteBackendUrl(chatRaw['photoUrl']?.toString()) ??
            _chatPhotoUrl;
        if (chatRaw['notificationsMuted'] == true ||
            chatRaw['notificationsMuted'] == false) {
          _notificationsMuted = chatRaw['notificationsMuted'] == true;
        }
      });
      _applyChatMetadataChange(
        title: _chatTitle,
        photoUrl: _chatPhotoUrl,
        notificationsMuted: _notificationsMuted,
      );
      _saveSessionCache();
    };
    _onUserTyping = (raw) {
      if (!mounted || _chatDeleted || raw is! Map) return;
      final data = Map<String, dynamic>.from(raw);
      final chatId = data['chat_id']?.toString();
      if (chatId != null && chatId != widget.chatId) return;

      final userId = data['user_id']?.toString();
      if (userId == null || userId == _currentUserId) return;

      final isTyping = data['typing'] != false;
      if (!isTyping) {
        _removeTypingUser(userId);
        return;
      }

      final name = data['sender']?.toString().trim();
      if (name == null || name.isEmpty) return;
      _setTypingUser(userId, name);
    };
    _onMemberStateUpdated = (raw) {
      if (!mounted || _chatDeleted || raw is! Map) return;
      final chatId = raw['chat_id']?.toString();
      if (chatId != null && chatId != widget.chatId) return;

      final userId = raw['user_id']?.toString();
      if (userId == null || userId.isEmpty) return;

      final readAt = _parseMemberTimestamp(raw['read_at']);
      final receivedAt = _parseMemberTimestamp(raw['received_at']);

      setState(() {
        if (readAt != null) {
          _memberReadAt[userId] = readAt;
        }
        if (receivedAt != null) {
          _memberReceivedAt[userId] = receivedAt;
        }
        _refreshOwnMessageStatuses();
      });
    };
    _prepareSessionCache();
    _messageController.addListener(_handleComposerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleHeavyWorkAfterTransition();
    });
  }

  void _prepareSessionCache() {
    final session =
        widget.initialSession ?? ChatSessionCache.instance.get(widget.chatId);
    if (session == null) {
      _chatTitle = widget.initialTitle ?? '';
      return;
    }

    _pendingSession = session;
    _chatTitle = session.chatTitle.isNotEmpty
        ? session.chatTitle
        : (widget.initialTitle ?? '');
    _chatPhotoUrl = session.photoUrl;
    _creatorId = session.creatorId;
    _creatorName = session.creatorName;
    _participants = session.participants;
    _isLoading = false;
  }

  Future<void> _applyPendingSessionMessages() async {
    final session = _pendingSession;
    if (session == null) return;

    _pendingSession = null;
    final source = session.messages;
    if (source.isEmpty) {
      _messages = [];
      return;
    }

    _messages = source.length > 40
        ? await compute(cloneChatMessages, source)
        : cloneChatMessages(source);
  }

  void _beginHeavyContent() {
    if (_chatDeleted || _bootstrapStarted || !mounted) return;
    _bootstrapStarted = true;

    _bindSocketHandlers();

    final hasPendingMessages =
        _pendingSession != null && _pendingSession!.messages.isNotEmpty;

    setState(() {
      _routeReady = true;
      _messagesHydrating = hasPendingMessages;
    });

    unawaited(_hydrateMessagesAndBootstrap());
  }

  Future<void> _hydrateMessagesAndBootstrap() async {
    await _applyPendingSessionMessages();
    if (!mounted || _chatDeleted) return;

    if (_messagesHydrating) {
      setState(() => _messagesHydrating = false);
    }

    unawaited(_bootstrapChat());
  }

  void _cancelPendingWork() {
    _markReadDebounce?.cancel();
    _markReadDebounce = null;
    _markReadScheduled = false;
    _detachRouteAnimationListener();
    _socketService.off('new_message', _onNewMessage);
    _socketService.off('message_deleted', _onMessageDeleted);
    _socketService.off('reactions_updated', _onReactionsUpdated);
    _socketService.off('chat_deleted', _onChatDeleted);
    _socketService.off('chat_updated', _onChatUpdated);
    _socketService.off('user_typing', _onUserTyping);
    _socketService.off('member_state_updated', _onMemberStateUpdated);
    _stopTypingSignal();
    _clearTypingIndicators();
  }

  void _clearTypingIndicators() {
    _typingPulseTimer?.cancel();
    _typingPulseTimer = null;
    for (final timer in _typingExpireTimers.values) {
      timer.cancel();
    }
    _typingExpireTimers.clear();
    _typingUsers.clear();
  }

  void _setTypingUser(String userId, String name) {
    _typingUsers[userId] = name;
    _typingExpireTimers.remove(userId)?.cancel();
    _typingExpireTimers[userId] = Timer(const Duration(seconds: 4), () {
      _removeTypingUser(userId);
    });
    if (mounted) setState(() {});
  }

  void _removeTypingUser(String userId) {
    _typingExpireTimers.remove(userId)?.cancel();
    if (_typingUsers.remove(userId) != null && mounted) {
      setState(() {});
    }
  }

  void _handleComposerChanged() {
    if (_messageController.text.trim().isEmpty) {
      _stopTypingSignal();
      return;
    }
    _scheduleTypingSignal();
  }

  void _scheduleTypingSignal() {
    if (!_typingSignalActive) {
      _typingSignalActive = true;
      unawaited(_socketService.sendTyping(widget.chatId, isTyping: true));
    }

    _typingPulseTimer?.cancel();
    _typingPulseTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _messageController.text.trim().isEmpty) {
        _stopTypingSignal();
        return;
      }
      unawaited(_socketService.sendTyping(widget.chatId, isTyping: true));
      _scheduleTypingSignal();
    });
  }

  void _stopTypingSignal() {
    _typingPulseTimer?.cancel();
    _typingPulseTimer = null;
    if (!_typingSignalActive) return;
    _typingSignalActive = false;
    unawaited(_socketService.sendTyping(widget.chatId, isTyping: false));
  }

  String _participantsCountLabel(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return '$count участник';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return '$count участника';
    }
    return '$count участников';
  }

  String? get _typingStatusLabel {
    if (_typingUsers.isEmpty) return null;
    final names = _typingUsers.values.toList();
    if (names.length == 1) return '${names.first} печатает…';
    if (names.length == 2) return '${names[0]} и ${names[1]} печатают…';
    return '${names[0]}, ${names[1]} и ещё ${names.length - 2} печатают…';
  }

  String get _chatSubtitle {
    if (_participants.isEmpty) return 'подключение...';
    final typing = _typingStatusLabel;
    if (typing != null) return typing;
    return _participantsCountLabel(_participants.length);
  }

  Future<void> _purgeLocalChatStorage(String userId, String chatId) async {
    await Future.wait([
      ChatMessageCache.instance.clearChat(userId: userId, chatId: chatId),
      ChatDetailsCache.instance.clear(userId: userId, chatId: chatId),
    ]);
  }

  void _detachRouteAnimationListener() {
    if (!_routeAnimationAttached) return;
    final animation = _routeAnimation;
    final listener = _routeAnimationListener;
    if (animation != null && listener != null) {
      animation.removeStatusListener(listener);
    }
    _routeAnimationAttached = false;
  }

  void _scheduleHeavyWorkAfterTransition() {
    if (_bootstrapStarted || !mounted) return;

    final animation = _routeAnimation;
    if (animation == null || animation.status == AnimationStatus.completed) {
      _beginHeavyContent();
      return;
    }

    if (_routeAnimationAttached) return;
    _routeAnimationAttached = true;

    _routeAnimationListener ??= (AnimationStatus status) {
      if (status != AnimationStatus.completed) return;
      _detachRouteAnimationListener();
      if (mounted) _beginHeavyContent();
    };
    animation.addStatusListener(_routeAnimationListener!);
  }

  void _applyChatMetadataChange({
    String? title,
    String? photoUrl,
    bool? notificationsMuted,
  }) {
    widget.onChatMetadataChanged?.call(
      title: title,
      photoUrl: photoUrl,
      notificationsMuted: notificationsMuted,
    );
  }

  void _saveSessionCache() {
    ChatSessionCache.instance.put(
      widget.chatId,
      ChatSessionData(
        messages: _messages
            .map((message) => Map<String, dynamic>.from(message))
            .toList(),
        chatTitle: _chatTitle,
        photoUrl: _chatPhotoUrl,
        creatorId: _creatorId,
        creatorName: _creatorName,
        participants: _participants,
        currentUserId: _currentUserId,
        currentUserName: _currentUserName,
      ),
    );
  }

  Future<void> _persistChatDetails() async {
    final userId = _currentUserId;
    if (userId == null) return;
    await ChatDetailsCache.instance.save(
      userId: userId,
      chatId: widget.chatId,
      snapshot: ChatDetailsSnapshot(
        title: _chatTitle,
        photoUrl: _chatPhotoUrl,
        creatorId: _creatorId,
        creatorName: _creatorName,
        participants: _participants,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      chatRouteObserver.subscribe(this, route);
    }
    _routeAnimation = route?.animation;
  }

  @override
  void dispose() {
    chatRouteObserver.unsubscribe(this);
    _detachRouteAnimationListener();
    _socketService.off('new_message', _onNewMessage);
    _socketService.off('message_deleted', _onMessageDeleted);
    _socketService.off('reactions_updated', _onReactionsUpdated);
    _socketService.off('chat_deleted', _onChatDeleted);
    _socketService.off('chat_updated', _onChatUpdated);
    _socketService.off('user_typing', _onUserTyping);
    _socketService.off('member_state_updated', _onMemberStateUpdated);
    _stopTypingSignal();
    _clearTypingIndicators();
    _messageController.removeListener(_handleComposerChanged);
    _flushMarkChatAsRead();
    if (!_chatDeleted) {
      unawaited(ChatMessageCache.instance.flushScheduledSave());
      _saveSessionCache();
    }
    _messageController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    unawaited(_softResync());
  }

  String _nextLocalId() {
    _localCounter += 1;
    return 'local_${DateTime.now().millisecondsSinceEpoch}_$_localCounter';
  }

  DateTime _parseTimestamp(dynamic raw) => parseBackendDateTime(raw);

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatTime(dynamic raw) => formatBackendTime(raw);

  String _dayLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) return 'Сегодня';
    if (date == yesterday) return 'Вчера';

    const months = [
      'янв',
      'фев',
      'мар',
      'апр',
      'мая',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек',
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  Map<String, dynamic> _normalizeMessage({
    required dynamic senderId,
    required dynamic sender,
    required dynamic content,
    required dynamic timestamp,
    String? localId,
    dynamic id,
    dynamic messageType,
    dynamic routeShare,
    dynamic reactions,
    dynamic senderAvatarUrl,
    dynamic status,
  }) {
    final type = (messageType ?? 'text').toString();
    final text = (content ?? '').toString();

    String? replySender;
    String? replyText;
    var plainText = text;

    if (type == 'text' && text.startsWith('↪ ') && text.contains('\n')) {
      final parts = text.split('\n');
      final meta = parts.first;
      final idx = meta.indexOf(':');
      if (idx > 2) {
        replySender = meta.substring(2, idx).trim();
        replyText = meta.substring(idx + 1).trim();
      }
      plainText = parts.skip(1).join('\n').trim();
    }

    return {
      if (id != null) 'id': id,
      'local_id': localId ?? _nextLocalId(),
      'sender_id': senderId?.toString() ?? 'unknown',
      'sender': sender?.toString() ?? 'Неизвестный пользователь',
      if (senderAvatarUrl != null &&
          senderAvatarUrl.toString().trim().isNotEmpty)
        'sender_avatar_url': senderAvatarUrl.toString(),
      'content': plainText,
      'message_type': type,
      'timestamp': timestamp?.toString() ?? backendNowIsoUtc(),
      'reply_to_sender': replySender,
      'reply_to_text': replyText,
      if (routeShare is Map)
        'route_share': Map<String, dynamic>.from(routeShare),
      'reactions': _parseReactions(reactions),
      if (status != null) 'status': status.toString(),
    };
  }

  List<Map<String, dynamic>> _parseReactions(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> _mapServerMessages(
    List<Map<String, dynamic>> raw,
  ) {
    return raw
        .map(
          (m) => _normalizeMessage(
            senderId: m['sender_id'],
            sender: m['sender'],
            content: m['content'],
            timestamp: m['timestamp'],
            id: m['id'],
            localId: m['id']?.toString(),
            messageType: m['message_type'],
            routeShare: m['route_share'],
            reactions: m['reactions'],
            senderAvatarUrl: m['sender_avatar_url'],
            status: m['status'],
          ),
        )
        .toList();
  }

  Iterable<String> get _participantIds => _participants
      .map((participant) => participant.userId)
      .whereType<String>()
      .where((id) => id.isNotEmpty);

  DateTime? _parseMemberTimestamp(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toUtc();
  }

  void _refreshOwnMessageStatuses() {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    for (var i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      if (message['sender_id']?.toString() != currentUserId) continue;
      final status = ChatMessageStatusHelper.statusForMessage(
        message: message,
        currentUserId: currentUserId,
        memberReadAt: _memberReadAt,
        memberReceivedAt: _memberReceivedAt,
        participantIds: _participantIds,
      );
      message['status'] = chatMessageStatusToRaw(status);
    }
  }

  ChatMessageStatus _messageStatus(Map<String, dynamic> message) {
    return ChatMessageStatusHelper.statusForMessage(
      message: message,
      currentUserId: _currentUserId,
      memberReadAt: _memberReadAt,
      memberReceivedAt: _memberReceivedAt,
      participantIds: _participantIds,
    );
  }

  List<Map<String, dynamic>> _mergeMessages(
    List<Map<String, dynamic>> existing,
    List<Map<String, dynamic>> incoming,
  ) {
    final merged = <String, Map<String, dynamic>>{};
    for (final message in existing) {
      final key = message['id']?.toString() ?? message['local_id']?.toString();
      if (key != null) merged[key] = message;
    }
    for (final message in incoming) {
      final key = message['id']?.toString() ?? message['local_id']?.toString();
      if (key != null) merged[key] = message;
    }
    final list = merged.values.toList();
    list.sort(
      (a, b) => _parseTimestamp(
        b['timestamp'],
      ).compareTo(_parseTimestamp(a['timestamp'])),
    );
    return list;
  }

  Future<void> _persistMessages() async {
    final userId = _currentUserId;
    if (userId == null) return;
    await ChatMessageCache.instance.saveMessages(
      userId: userId,
      chatId: widget.chatId,
      messages: _messages,
    );
  }

  void _schedulePersistMessages() {
    final userId = _currentUserId;
    if (userId == null) return;
    ChatMessageCache.instance.scheduleSave(
      userId: userId,
      chatId: widget.chatId,
      messages: _messages,
    );
    _saveSessionCache();
  }

  void _applyChatDetails(Map<String, dynamic> chatDetails) {
    _chatTitle = (chatDetails['title'] ?? widget.initialTitle ?? '').toString();
    _creatorId = (chatDetails['creatorId'] as num?)?.toInt();
    _creatorName = chatDetails['creatorName']?.toString();
    _chatPhotoUrl = absoluteBackendUrl(chatDetails['photoUrl']?.toString());
    _notificationsMuted = chatDetails['notificationsMuted'] == true;
    _participants = ChatParticipant.fromJsonList(
      chatDetails['participants'],
      creatorId: _creatorId,
    );
    _creatorName ??= ChatParticipant.creatorNameFrom(_participants);
    _rebuildParticipantAvatars();
    unawaited(_persistChatDetails());
  }

  void _rebuildParticipantAvatars() {
    _participantAvatars = {
      for (final participant in _participants)
        if (participant.userId != null)
          participant.userId!: participant.avatarUrl,
    };
  }

  String? _avatarUrlForMessage(Map<String, dynamic> message) {
    final raw = message['sender_avatar_url']?.toString();
    if (raw != null && raw.isNotEmpty) {
      return absoluteBackendUrl(raw);
    }
    final senderId = message['sender_id']?.toString();
    if (senderId != null) {
      return absoluteBackendUrl(_participantAvatars[senderId]);
    }
    return null;
  }

  bool _isFirstInSenderGroup(int index, Map<String, dynamic> message) {
    if (index + 1 >= _messages.length) return true;

    final older = _messages[index + 1];
    final currentSender = message['sender_id']?.toString();
    final olderSender = older['sender_id']?.toString();
    if (currentSender != olderSender) return true;

    return !_isSameDay(
      _parseTimestamp(message['timestamp']),
      _parseTimestamp(older['timestamp']),
    );
  }

  bool get _isCreator {
    if (_creatorId == null || _currentUserId == null) return false;
    return _creatorId.toString() == _currentUserId;
  }

  Future<void> _openChatSettings() async {
    if (_token == null) return;

    await ChatSettingsSheet.show(
      context,
      chatId: widget.chatId,
      chatTitle: _chatTitle,
      photoUrl: _chatPhotoUrl,
      notificationsMuted: _notificationsMuted,
      isCreator: _isCreator,
      chatService: GroupChatService(token: _token!),
      onUpdated: ({String? title, String? photoUrl, bool? notificationsMuted}) {
        if (!mounted) return;
        setState(() {
          if (title != null) _chatTitle = title;
          if (photoUrl != null) _chatPhotoUrl = photoUrl;
          if (notificationsMuted != null) {
            _notificationsMuted = notificationsMuted;
          }
        });
        _applyChatMetadataChange(
          title: title,
          photoUrl: photoUrl,
          notificationsMuted: notificationsMuted,
        );
        _saveSessionCache();
        unawaited(_persistChatDetails());
      },
    );
  }

  void _updateMessageReactions(
    dynamic messageId,
    List<Map<String, dynamic>> reactions,
  ) {
    final idStr = messageId.toString();
    setState(() {
      final index = _messages.indexWhere((m) => m['id']?.toString() == idStr);
      if (index < 0) return;
      _messages[index] = {..._messages[index], 'reactions': reactions};
    });
    _schedulePersistMessages();
  }

  bool _isRouteMessage(Map<String, dynamic> message) {
    return message['message_type']?.toString() == 'route' &&
        message['route_share'] is Map;
  }

  String _routeDownloadKey(Map<String, dynamic> message) {
    final share = message['route_share'];
    if (share is Map) {
      return share['id']?.toString() ?? message['local_id'].toString();
    }
    return message['local_id']?.toString() ?? message['id']?.toString() ?? '';
  }

  int? _parseRouteShareId(dynamic raw) {
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  void _removeMessageFromList(dynamic messageId, {String? localId}) {
    setState(() {
      _messages.removeWhere((m) {
        if (messageId != null && m['id']?.toString() == messageId.toString()) {
          return true;
        }
        if (localId != null && m['local_id']?.toString() == localId) {
          return true;
        }
        return false;
      });
    });
    _schedulePersistMessages();
  }

  Future<bool> _loadCachedMessagesFromDisk(String userId) async {
    final cached = await ChatMessageCache.instance.loadMessages(
      userId: userId,
      chatId: widget.chatId,
    );
    if (cached.isEmpty || !mounted) return false;
    if (_messages.isNotEmpty) return true;

    setState(() {
      _messages = cached;
      _isLoading = false;
    });
    return true;
  }

  Future<bool> _loadCachedDetailsFromDisk(String userId) async {
    if (_participants.isNotEmpty) return true;

    final details = await ChatDetailsCache.instance.load(
      userId: userId,
      chatId: widget.chatId,
    );
    if (details == null || !mounted) return false;

    setState(() {
      if (_chatTitle.isEmpty && details.title.isNotEmpty) {
        _chatTitle = details.title;
      }
      _creatorId ??= details.creatorId;
      _creatorName ??= details.creatorName;
      _participants = details.participants;
      _creatorName ??= ChatParticipant.creatorNameFrom(_participants);
      _rebuildParticipantAvatars();
    });
    return true;
  }

  Future<void> _bootstrapChat() async {
    if (_chatDeleted) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null || token.isEmpty) {
      if (!mounted || _chatDeleted) return;
      setState(() => _isLoading = false);
      AppSnackBar.show(context, 'Токен не найден. Войдите снова.');
      return;
    }

    _token = token;

    final userId = await UserWorkoutStorage.instance.syncUserIdFromToken(token);
    if (userId != null) {
      if (_currentUserId != null && _currentUserId != userId) {
        _messages = [];
        ChatSessionCache.instance.remove(widget.chatId);
      }
      _currentUserId = userId;
      if (_messages.isEmpty) {
        await _loadCachedMessagesFromDisk(userId);
      }
      await _loadCachedDetailsFromDisk(userId);
    }

    if (_chatDeleted || !mounted) return;

    try {
      final profile = UserProfileCache.instance;
      if (profile.userId != null &&
          userId != null &&
          profile.userId != userId) {
        profile.clear();
      }

      final needsProfile = _currentUserName == null;

      if (needsProfile) {
        await profile.ensureLoaded(
          userService: _userService,
          expectedUserId: userId,
        );
      }

      _currentUserId = profile.userId ?? userId ?? _currentUserId;
      _currentUserName = profile.userName ?? _currentUserName;

      if (_chatDeleted || !mounted) return;

      _bindSocketHandlers();

      unawaited(
        _fetchChatData(
          showLoadingIfEmpty: _messages.isEmpty,
          showSyncIndicator: false,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isSyncing = false;
      });
      AppSnackBar.show(context, 'Ошибка инициализации чата: $e');
    }
  }

  void _bindSocketHandlers() {
    _socketService.off('new_message', _onNewMessage);
    _socketService.off('message_deleted', _onMessageDeleted);
    _socketService.off('reactions_updated', _onReactionsUpdated);
    _socketService.off('chat_deleted', _onChatDeleted);
    _socketService.off('chat_updated', _onChatUpdated);
    _socketService.off('user_typing', _onUserTyping);
    _socketService.off('member_state_updated', _onMemberStateUpdated);

    _socketService.on('new_message', _onNewMessage);
    _socketService.on('message_deleted', _onMessageDeleted);
    _socketService.on('reactions_updated', _onReactionsUpdated);
    _socketService.on('chat_deleted', _onChatDeleted);
    _socketService.on('chat_updated', _onChatUpdated);
    _socketService.on('user_typing', _onUserTyping);
    _socketService.on('member_state_updated', _onMemberStateUpdated);

    unawaited(_socketService.ensureConnected(backendBaseUrl));
    _socketService.joinChat(widget.chatId, force: true);
  }

  Future<void> _softResync() async {
    try {
      _bindSocketHandlers();
      unawaited(
        _fetchChatData(showLoadingIfEmpty: false, showSyncIndicator: false),
      );
    } catch (_) {
      // Keep cached messages visible if background sync fails.
    }
  }

  void _scheduleMarkChatAsRead() {
    _markReadScheduled = true;
    _markReadDebounce?.cancel();
    _markReadDebounce = Timer(const Duration(milliseconds: 600), () {
      _markReadScheduled = false;
      unawaited(_markChatAsRead());
    });
  }

  void _flushMarkChatAsRead() {
    _markReadDebounce?.cancel();
    _markReadDebounce = null;
    if (!_markReadScheduled) return;
    _markReadScheduled = false;
    unawaited(_markChatAsRead());
  }

  Future<void> _markChatAsRead() async {
    if (_token == null) return;
    try {
      final groupChatService = GroupChatService(token: _token!);
      await groupChatService.markChatAsRead(widget.chatId);
    } catch (_) {
      // Ignore read-mark errors; list refresh will retry later.
    }
  }

  Future<void> _fetchChatData({
    bool showLoadingIfEmpty = true,
    bool showSyncIndicator = true,
  }) async {
    if (_chatDeleted || _token == null) return;
    final userId = _currentUserId;
    if (userId == null) return;

    if (_messages.isEmpty) {
      final cached = await ChatMessageCache.instance.loadMessages(
        userId: userId,
        chatId: widget.chatId,
      );
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _messages = cached;
          _isLoading = false;
        });
      } else if (showLoadingIfEmpty && mounted) {
        setState(() => _isLoading = true);
      }
    }

    if (mounted && _messages.isNotEmpty && showSyncIndicator) {
      setState(() => _isSyncing = true);
    }

    try {
      final groupChatService = GroupChatService(token: _token!);
      final chatDetailsFuture = groupChatService
          .getChatDetails(widget.chatId, includeMessages: false)
          .timeout(const Duration(seconds: 10));

      final lastId = ChatMessageCache.instance.lastServerMessageId(_messages);
      final hadCache = _messages.isNotEmpty;

      final messagesFuture = () async {
        try {
          return await groupChatService
              .fetchMessages(widget.chatId, afterId: lastId)
              .timeout(const Duration(seconds: 10));
        } catch (_) {
          if (lastId != null) rethrow;
          final fallback = await groupChatService
              .getChatDetails(widget.chatId, includeMessages: true)
              .timeout(const Duration(seconds: 10));
          final messages = fallback['messages'];
          return messages is List
              ? messages
                    .whereType<Map>()
                    .map((item) => Map<String, dynamic>.from(item))
                    .toList()
              : const <Map<String, dynamic>>[];
        }
      }();

      final chatDetails = await chatDetailsFuture;
      final rawMessages = await messagesFuture;

      final incoming = _mapServerMessages(rawMessages).reversed.toList();
      final merged = incoming.isEmpty
          ? _messages
          : (lastId == null && !hadCache)
          ? incoming
          : _mergeMessages(_messages, incoming);

      if (!mounted) return;
      setState(() {
        _applyChatDetails(chatDetails);
        _messages = merged;
        _refreshOwnMessageStatuses();
        _isLoading = false;
        _isSyncing = false;
      });
      _saveSessionCache();
      await _persistMessages();
      _scheduleMarkChatAsRead();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isSyncing = false;
      });
      if (_messages.isEmpty) {
        AppSnackBar.show(context, 'Ошибка загрузки чата: $e');
      }
    }
  }

  void _setReplyTo(Map<String, dynamic> message) {
    setState(() => _replyTo = message);
  }

  Future<void> _showMessageActions(
    Map<String, dynamic> message,
    bool isCurrentUser,
    String messageId,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AuthColors.scaffoldBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        const emojis = ['👍', '🔥', '❤️', '👏', '😂', '😮'];
        final canDelete = isCurrentUser && message['id'] != null;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.reply_rounded,
                    color: AuthColors.body,
                  ),
                  title: Text('Ответить', style: authFieldStyle()),
                  onTap: () => Navigator.pop(context, 'reply'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Wrap(
                    spacing: 12,
                    children: emojis
                        .map(
                          (emoji) => GestureDetector(
                            onTap: () => Navigator.pop(context, 'react:$emoji'),
                            child: Container(
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F5F7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                if (canDelete) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFE53935),
                    ),
                    title: Text(
                      'Удалить',
                      style: authFieldStyle().copyWith(
                        color: const Color(0xFFE53935),
                      ),
                    ),
                    onTap: () => Navigator.pop(context, 'delete'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == 'reply') {
      _setReplyTo(message);
      return;
    }

    if (action.startsWith('react:')) {
      await _toggleReaction(message, action.substring(6));
      return;
    }

    if (action == 'delete') {
      await _confirmAndDeleteMessage(message, messageId);
    }
  }

  Future<void> _toggleReaction(
    Map<String, dynamic> message,
    String emoji,
  ) async {
    final serverId = message['id'];
    if (serverId == null || _token == null) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        'Реакцию можно поставить только после отправки сообщения',
      );
      return;
    }

    try {
      final reactions = await GroupChatService(token: _token!)
          .toggleMessageReaction(
            chatId: widget.chatId,
            messageId: serverId.toString(),
            emoji: emoji,
          );
      if (!mounted) return;
      _updateMessageReactions(serverId, reactions);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Не удалось поставить реакцию: $e');
    }
  }

  Future<void> _confirmAndDeleteMessage(
    Map<String, dynamic> message,
    String messageLocalId,
  ) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Удалить сообщение?',
      message: 'Сообщение будет удалено для всех участников чата.',
      confirmLabel: 'Удалить',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );

    if (confirmed != true || !mounted) return;

    final serverId = message['id'];
    if (serverId == null) {
      _removeMessageFromList(null, localId: messageLocalId);
      return;
    }

    if (_token == null) return;

    try {
      await GroupChatService(
        token: _token!,
      ).deleteMessage(widget.chatId, serverId.toString());
      if (!mounted) return;
      _removeMessageFromList(serverId, localId: messageLocalId);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Не удалось удалить сообщение: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _token == null || _isSending) return;

    setState(() => _isSending = true);

    if (!_socketService.isConnected) {
      try {
        await _socketService.ensureConnected(
          backendBaseUrl,
          wait: true,
          timeout: const Duration(seconds: 3),
        );
        _bindSocketHandlers();
      } catch (_) {
        if (mounted) {
          AppSnackBar.show(context, 'Нет соединения с сервером');
        }
        setState(() => _isSending = false);
        return;
      }
    }

    final replySender = _replyTo?['sender']?.toString();
    final replyText = _replyTo?['content']?.toString();
    final textToSend = (replySender != null && replyText != null)
        ? '↪ $replySender: $replyText\n$text'
        : text;

    await _socketService.sendMessage(widget.chatId, textToSend);
    _stopTypingSignal();
    _messageController.clear();

    setState(() {
      _messages.insert(
        0,
        _normalizeMessage(
            senderId: _currentUserId,
            sender: 'Вы',
            content: text,
            timestamp: backendNowIsoUtc(),
            localId: _nextLocalId(),
            status: 'sending',
          )
          ..['reply_to_sender'] = replySender
          ..['reply_to_text'] = replyText,
      );
      _replyTo = null;
      _isSending = false;
    });
    _schedulePersistMessages();
  }

  void _insertSharedRouteMessage(Map<String, dynamic> message) {
    final normalized = _normalizeMessage(
      senderId: message['sender_id'] ?? _currentUserId,
      sender: message['sender'] ?? 'Вы',
      content: message['content'],
      timestamp: message['timestamp'],
      id: message['id'],
      messageType: message['message_type'],
      routeShare: message['route_share'],
      reactions: message['reactions'],
      senderAvatarUrl: message['sender_avatar_url'],
      status: message['status'],
    );

    setState(() {
      final messageId = normalized['id']?.toString();
      if (messageId != null) {
        _messages.removeWhere((m) => m['id']?.toString() == messageId);
      }
      _messages.insert(0, normalized);
    });
    _schedulePersistMessages();
  }

  Future<void> _downloadSharedRoute(Map<String, dynamic> message) async {
    if (_token == null || !_isRouteMessage(message)) return;

    final routeShareRaw = message['route_share'];
    if (routeShareRaw is! Map) return;

    final share = Map<String, dynamic>.from(routeShareRaw);
    final shareId = _parseRouteShareId(share['id']);
    final originalFilename =
        share['originalFilename']?.toString() ?? 'route.gpx';
    final shareTitle = share['title']?.toString();
    final snapshot = RouteShareSnapshot.fromShareMessage(share);
    if (shareId == null) return;

    final key = _routeDownloadKey(message);
    if (_downloadingRouteKeys.contains(key)) return;

    setState(() => _downloadingRouteKeys.add(key));

    try {
      final routeService = ChatRouteService(token: _token!);
      await routeService.downloadRoute(
        chatId: widget.chatId,
        shareId: shareId,
        originalFilename: originalFilename,
        title: shareTitle,
        snapshot: snapshot,
        sharedByUserId: message['sender_id']?.toString(),
        sharedByUserName: message['sender']?.toString(),
        sharedByAvatarUrl: message['sender_avatar_url']?.toString(),
      );
      if (!mounted) return;
      AppSnackBar.show(context, 'Маршрут сохранён в историю');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Не удалось скачать маршрут: $e');
    } finally {
      if (mounted) {
        setState(() => _downloadingRouteKeys.remove(key));
      }
    }
  }

  Future<void> _openAttachRouteDialog() async {
    if (_token == null) return;

    await AttachRouteDialog.show(
      context,
      chatId: widget.chatId,
      routeService: ChatRouteService(token: _token!),
      onShared: _insertSharedRouteMessage,
    );
  }

  Future<void> _openParticipantsSheet() async {
    if (_token == null) return;

    await ChatParticipantsSheet.show(
      context,
      title: 'Участники',
      chatId: widget.chatId,
      chatService: GroupChatService(token: _token!),
      participants: _participants,
      creatorId: _creatorId,
      creatorName: _creatorName,
      currentUserId: _currentUserId,
      onParticipantsChanged: _fetchChatData,
      onChatDeleted: (chatId) {
        if (_chatDeleted) return;
        _chatDeleted = true;
        _cancelPendingWork();
        _socketService.forgetChat(chatId);
        ChatSessionCache.instance.remove(chatId);
        final userId = _currentUserId;
        if (mounted) Navigator.pop(context, chatId);
        if (userId != null) {
          unawaited(_purgeLocalChatStorage(userId, chatId));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F5F7),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AuthColors.title,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _chatTitle.isEmpty ? 'Групповой чат' : _chatTitle,
              style: GoogleFonts.lexendDeca(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AuthColors.title,
              ),
            ),
            Text(
              _chatSubtitle,
              style: authSubtitleStyle().copyWith(
                fontSize: 11,
                color: _typingUsers.isNotEmpty ? AuthColors.primaryGreen : null,
                fontWeight: _typingUsers.isNotEmpty
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openChatSettings,
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Настройки чата',
          ),
          IconButton(
            icon: const Icon(Icons.group_outlined),
            tooltip: 'Участники',
            onPressed: _openParticipantsSheet,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: !_routeReady
          ? const ColoredBox(color: Color(0xFFF2F5F7), child: SizedBox.expand())
          : _isLoading && _messages.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_isSyncing)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Color(0xFFE8EDF0),
                  ),
                Expanded(
                  child: _messagesHydrating
                      ? const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _messages.isEmpty
                      ? Center(
                          child: Text(
                            'Пока нет сообщений',
                            style: authSubtitleStyle(),
                          ),
                        )
                      : ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final currentDate = _parseTimestamp(
                              message['timestamp'],
                            );
                            final nextOlderDate = index + 1 < _messages.length
                                ? _parseTimestamp(
                                    _messages[index + 1]['timestamp'],
                                  )
                                : null;
                            final showDayDivider =
                                nextOlderDate == null ||
                                !_isSameDay(currentDate, nextOlderDate);

                            final isCurrentUser =
                                message['sender_id']?.toString() ==
                                _currentUserId;
                            final sender = isCurrentUser
                                ? 'Вы'
                                : (message['sender']?.toString() ??
                                      _currentUserName ??
                                      'Участник');
                            final time = _formatTime(message['timestamp']);
                            final messageId =
                                message['local_id']?.toString() ?? '$index';
                            final reactions = _parseReactions(
                              message['reactions'],
                            );

                            final avatarUrl = _avatarUrlForMessage(message);
                            final showAvatar =
                                !isCurrentUser &&
                                _isFirstInSenderGroup(index, message);
                            const avatarSize = 30.0;
                            const avatarColumnWidth = 30.0;

                            Widget messageBubble = GestureDetector(
                              onLongPress: () => _showMessageActions(
                                message,
                                isCurrentUser,
                                messageId,
                              ),
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width *
                                      (isCurrentUser ? 0.78 : 0.68),
                                ),
                                margin: EdgeInsets.only(
                                  top: showAvatar || isCurrentUser ? 3 : 1,
                                  bottom: 1,
                                ),
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  8,
                                  12,
                                  8,
                                ),
                                decoration: BoxDecoration(
                                  color: isCurrentUser
                                      ? const Color(0xFFDCF8C6)
                                      : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(14),
                                    topRight: const Radius.circular(14),
                                    bottomLeft: Radius.circular(
                                      isCurrentUser ? 14 : 4,
                                    ),
                                    bottomRight: Radius.circular(
                                      isCurrentUser ? 4 : 14,
                                    ),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x14000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isCurrentUser && showAvatar)
                                      Text(
                                        sender,
                                        style: GoogleFonts.lexendDeca(
                                          fontSize: 11,
                                          color: const Color(0xFF4D4D4D),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    if (message['reply_to_sender'] != null &&
                                        message['reply_to_text'] != null)
                                      Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.06,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border(
                                            left: BorderSide(
                                              color: isCurrentUser
                                                  ? const Color(0xFF37C979)
                                                  : const Color(0xFF8C8C8C),
                                              width: 3,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              message['reply_to_sender']
                                                  .toString(),
                                              style: GoogleFonts.lexendDeca(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF4D4D4D),
                                              ),
                                            ),
                                            Text(
                                              message['reply_to_text']
                                                  .toString(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.lexendDeca(
                                                fontSize: 11,
                                                color: const Color(0xFF6B6B6B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (_isRouteMessage(message))
                                      ChatRouteMessageBubble(
                                        title:
                                            (message['route_share']
                                                    as Map)['title']
                                                ?.toString() ??
                                            'Маршрут',
                                        fileName:
                                            (message['route_share']
                                                    as Map)['originalFilename']
                                                ?.toString() ??
                                            'route.gpx',
                                        fileSize:
                                            ((message['route_share']
                                                        as Map)['fileSize']
                                                    as num?)
                                                ?.toInt(),
                                        isCurrentUser: isCurrentUser,
                                        isDownloading: _downloadingRouteKeys
                                            .contains(
                                              _routeDownloadKey(message),
                                            ),
                                        onDownload: () =>
                                            _downloadSharedRoute(message),
                                      )
                                    else
                                      Text(
                                        message['content']?.toString() ?? '',
                                        style: GoogleFonts.lexendDeca(
                                          fontSize: 14,
                                          color: const Color(0xFF1E1E1E),
                                        ),
                                      ),
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          time,
                                          style: GoogleFonts.lexendDeca(
                                            fontSize: 10,
                                            color: const Color(0xFF7B7B7B),
                                          ),
                                        ),
                                        if (isCurrentUser) ...[
                                          const SizedBox(width: 4),
                                          ChatMessageStatusIcon(
                                            status: _messageStatus(message),
                                          ),
                                        ],
                                      ],
                                    ),
                                    ChatMessageReactions(
                                      reactions: reactions,
                                      currentUserId: _currentUserId,
                                      onReactionTap: message['id'] == null
                                          ? null
                                          : (emoji) =>
                                                _toggleReaction(message, emoji),
                                    ),
                                  ],
                                ),
                              ),
                            );

                            if (!isCurrentUser) {
                              messageBubble = Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: avatarColumnWidth,
                                    height: showAvatar ? avatarSize : null,
                                    child: showAvatar
                                        ? UserAvatar(
                                            name: sender,
                                            avatarUrl: avatarUrl,
                                            radius: avatarSize / 2,
                                            onTap: () => openUserProfile(
                                              context,
                                              message['sender_id'],
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(child: messageBubble),
                                ],
                              );
                            }

                            final bubble = Dismissible(
                              key: ValueKey(messageId),
                              direction: isCurrentUser
                                  ? DismissDirection.endToStart
                                  : DismissDirection.startToEnd,
                              confirmDismiss: (_) async {
                                _setReplyTo(message);
                                return false;
                              },
                              background: Align(
                                alignment: isCurrentUser
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.reply_rounded,
                                        color: AuthColors.body,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Ответить',
                                        style: TextStyle(
                                          color: AuthColors.body,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              child: Align(
                                alignment: isCurrentUser
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: messageBubble,
                              ),
                            );

                            return Column(
                              children: [
                                if (showDayDivider)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFFE4E4E4),
                                        ),
                                      ),
                                      child: Text(
                                        _dayLabel(currentDate),
                                        style: GoogleFonts.lexendDeca(
                                          fontSize: 11,
                                          color: AuthColors.body,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                bubble,
                              ],
                            );
                          },
                        ),
                ),
                if (_replyTo != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.reply_rounded,
                            size: 18,
                            color: AuthColors.body,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ответ: ${_replyTo!['sender']}',
                                  style: GoogleFonts.lexendDeca(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AuthColors.title,
                                  ),
                                ),
                                Text(
                                  _replyTo!['content']?.toString() ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.lexendDeca(
                                    fontSize: 11,
                                    color: AuthColors.body,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _replyTo = null),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_typingUsers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                    child: Row(
                      children: [
                        const _TypingDots(),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _typingStatusLabel ?? '',
                            style: GoogleFonts.lexendDeca(
                              fontSize: 12,
                              color: AuthColors.primaryGreen,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                SafeArea(
                  top: false,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          padding: EdgeInsets.zero,
                          icon: const FaIcon(
                            FontAwesomeIcons.route,
                            size: 17,
                            color: Color(0xFF7A7A7A),
                          ),
                          tooltip: 'Прикрепить маршрут',
                          onPressed: _openAttachRouteDialog,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: authFieldStyle(),
                            minLines: 1,
                            maxLines: 5,
                            decoration: InputDecoration(
                              hintText: _replyTo == null
                                  ? 'Сообщение'
                                  : 'Ответить ${_replyTo!['sender']}',
                              hintStyle: authHintStyle(),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 4,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 38,
                          height: 38,
                          child: Material(
                            color: AuthColors.primaryGreen,
                            shape: const CircleBorder(),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: _isSending
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const FaIcon(
                                      FontAwesomeIcons.paperPlane,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                              onPressed: _isSending ? null : _sendMessage,
                            ),
                          ),
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

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> {
  int _frame = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 350), (_) {
      if (mounted) setState(() => _frame = (_frame + 1) % 4);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final active = _frame > index;
        return Container(
          width: 5,
          height: 5,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AuthColors.primaryGreen : const Color(0xFFBDBDBD),
          ),
        );
      }),
    );
  }
}
