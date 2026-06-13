import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/network/config.dart';
import 'package:map_routing/core/services/notification_service.dart';
import 'package:map_routing/data/models/chat_participant.dart';
import 'package:map_routing/data/services/chat_route_service.dart';
import 'package:map_routing/data/services/group_service.dart';
import 'package:map_routing/data/services/socket_chat_service.dart';
import 'package:map_routing/data/services/user_service.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:map_routing/features/chat/widgets/attach_route_dialog.dart';
import 'package:map_routing/features/chat/widgets/chat_participants_sheet.dart';
import 'package:map_routing/features/chat/widgets/chat_message_reactions.dart';
import 'package:map_routing/features/chat/widgets/chat_route_message_bubble.dart';
import 'package:shared_preferences/shared_preferences.dart';

final RouteObserver<PageRoute> chatRouteObserver = RouteObserver<PageRoute>();

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.chatId,
    this.initialTitle,
  });

  final String chatId;
  final String? initialTitle;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with RouteAware {
  final TextEditingController _messageController = TextEditingController();
  final UserService _userService = UserService();
  late SocketChatService _socketService;

  String? _token;
  String? _currentUserId;
  String? _currentUserName;

  String _chatTitle = '';
  int? _creatorId;
  String? _creatorName;
  List<ChatParticipant> _participants = [];
  List<Map<String, dynamic>> _messages = [];

  Map<String, dynamic>? _replyTo;
  int _localCounter = 0;

  bool _isLoading = true;
  bool _isSending = false;
  int _newIncomingCount = 0;
  final Set<String> _downloadingRouteKeys = {};

  @override
  void initState() {
    super.initState();
    _chatTitle = widget.initialTitle ?? '';
    _socketService = SocketChatService();
    _loadTokenAndInitializeSocket();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      chatRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    chatRouteObserver.unsubscribe(this);
    _socketService.disconnect();
    _messageController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _reconnectSocketAndReload();
  }

  String _nextLocalId() {
    _localCounter += 1;
    return 'local_${DateTime.now().millisecondsSinceEpoch}_$_localCounter';
  }

  DateTime _parseTimestamp(dynamic raw) {
    final str = raw?.toString();
    if (str == null || str.isEmpty) return DateTime.now();
    return DateTime.tryParse(str)?.toLocal() ?? DateTime.now();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatTime(dynamic raw) {
    final dt = _parseTimestamp(raw);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

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
      'дек'
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
      'content': plainText,
      'message_type': type,
      'timestamp': timestamp?.toString() ?? DateTime.now().toIso8601String(),
      'reply_to_sender': replySender,
      'reply_to_text': replyText,
      if (routeShare is Map) 'route_share': Map<String, dynamic>.from(routeShare),
      'reactions': _parseReactions(reactions),
    };
  }

  List<Map<String, dynamic>> _parseReactions(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  void _updateMessageReactions(
    dynamic messageId,
    List<Map<String, dynamic>> reactions,
  ) {
    final idStr = messageId.toString();
    setState(() {
      final index =
          _messages.indexWhere((m) => m['id']?.toString() == idStr);
      if (index < 0) return;
      _messages[index] = {
        ..._messages[index],
        'reactions': reactions,
      };
    });
  }

  bool _isRouteMessage(Map<String, dynamic> message) {
    return message['message_type']?.toString() == 'route' &&
        message['route_share'] is Map;
  }

  String _routeDownloadKey(Map<String, dynamic> message) {
    final share = message['route_share'] as Map;
    return share['id']?.toString() ?? message['local_id'].toString();
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
  }

  Future<void> _loadTokenAndInitializeSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Токен не найден. Войдите снова.')),
      );
      return;
    }

    _token = token;

    try {
      await _loadUserInfo();
      await _initializeSocket();
      await _fetchChatData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка инициализации чата: $e')),
      );
    }
  }

  Future<void> _loadUserInfo() async {
    final userInfo = await _userService.fetchUserInfo();
    if (userInfo == null) {
      throw Exception('Не удалось загрузить данные пользователя');
    }
    _currentUserId = userInfo['id'].toString();
    _currentUserName = userInfo['name'].toString();
  }

  Future<void> _initializeSocket() async {
    _socketService.off('new_message');
    _socketService.off('message_deleted');
    _socketService.off('reactions_updated');
    await _socketService.initialize(backendBaseUrl);

    _socketService.on('new_message', (data) async {
      if (!mounted) return;

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
        messageType: data['message_type'],
        routeShare: data['route_share'],
        reactions: data['reactions'],
      );

      setState(() {
        if (messageId != null) {
          final idStr = messageId.toString();
          _messages.removeWhere((m) => m['id']?.toString() == idStr);
        }
        if (senderId == _currentUserId) {
          _messages.removeWhere((m) =>
              m['sender_id'] == _currentUserId &&
              m['id'] == null &&
              m['content'] == incoming['content']);
        }
        _messages.insert(0, incoming);
      });

      if (senderId != _currentUserId) {
        await _markChatAsRead();
      }
    });

    _socketService.on('message_deleted', (data) {
      if (!mounted) return;
      final chatId = data['chat_id']?.toString();
      if (chatId != null && chatId != widget.chatId) return;
      _removeMessageFromList(data['message_id']);
    });

    _socketService.on('reactions_updated', (data) {
      if (!mounted) return;
      final chatId = data['chat_id']?.toString();
      if (chatId != null && chatId != widget.chatId) return;
      final messageId = data['message_id'];
      if (messageId == null) return;
      _updateMessageReactions(
        messageId,
        _parseReactions(data['reactions']),
      );
    });

    _socketService.joinChat(widget.chatId);
  }

  Future<void> _reconnectSocketAndReload() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null || token.isEmpty) {
        throw Exception('Токен не найден');
      }

      _token = token;
      await _loadUserInfo();
      _socketService.disconnect();
      await _initializeSocket();
      await _fetchChatData();
      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка переподключения: $e')),
      );
    }
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

  Future<void> _fetchChatData() async {
    try {
      final groupChatService = GroupChatService(token: _token!);
      final chatDetails = await groupChatService
          .getChatDetails(widget.chatId)
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      setState(() {
        _chatTitle = (chatDetails['title'] ?? widget.initialTitle ?? '').toString();
        _creatorId = (chatDetails['creatorId'] as num?)?.toInt();
        _creatorName = chatDetails['creatorName']?.toString();
        _participants = ChatParticipant.fromJsonList(
          chatDetails['participants'],
          creatorId: _creatorId,
        );
        _creatorName ??= ChatParticipant.creatorNameFrom(_participants);
        _messages = List<Map<String, dynamic>>.from(
          (chatDetails['messages'] ?? []).map((m) => _normalizeMessage(
                senderId: m['sender_id'],
                sender: m['sender'],
                content: m['content'],
                timestamp: m['timestamp'],
                id: m['id'],
                messageType: m['message_type'],
                routeShare: m['route_share'],
                reactions: m['reactions'],
              )),
        ).reversed.toList();
        _isLoading = false;
      });
      await _markChatAsRead();
      if (mounted) {
        setState(() => _newIncomingCount = 0);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки чата: $e')),
      );
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        const emojis = ['👍', '🔥', '❤️', '👏', '😂', '😮'];
        final canDelete = isCurrentUser && message['id'] != null;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  leading: const Icon(Icons.reply_rounded, color: AuthColors.body),
                  title: Text('Ответить', style: authFieldStyle()),
                  onTap: () => Navigator.pop(context, 'reply'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                              child: Text(emoji, style: const TextStyle(fontSize: 24)),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                if (canDelete) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded,
                        color: Color(0xFFE53935)),
                    title: Text(
                      'Удалить',
                      style: authFieldStyle().copyWith(color: const Color(0xFFE53935)),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Реакцию можно поставить только после отправки сообщения'),
        ),
      );
      return;
    }

    try {
      final reactions = await GroupChatService(token: _token!).toggleMessageReaction(
        chatId: widget.chatId,
        messageId: serverId.toString(),
        emoji: emoji,
      );
      if (!mounted) return;
      _updateMessageReactions(serverId, reactions);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось поставить реакцию: $e')),
      );
    }
  }

  Future<void> _confirmAndDeleteMessage(
    Map<String, dynamic> message,
    String messageLocalId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить сообщение?'),
        content: const Text('Сообщение будет удалено для всех участников чата.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Удалить',
              style: TextStyle(color: Color(0xFFE53935)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final serverId = message['id'];
    if (serverId == null) {
      _removeMessageFromList(null, localId: messageLocalId);
      return;
    }

    if (_token == null) return;

    try {
      await GroupChatService(token: _token!).deleteMessage(
        widget.chatId,
        serverId.toString(),
      );
      if (!mounted) return;
      _removeMessageFromList(serverId, localId: messageLocalId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось удалить сообщение: $e')),
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _token == null || _isSending) return;

    setState(() => _isSending = true);

    if (!_socketService.isConnected) {
      await _reconnectSocketAndReload();
      if (!_socketService.isConnected) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Нет соединения с сервером')),
          );
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

    _socketService.sendMessage(widget.chatId, textToSend);
    _messageController.clear();

    setState(() {
      _messages.insert(
        0,
        _normalizeMessage(
          senderId: _currentUserId,
          sender: 'Вы',
          content: text,
          timestamp: DateTime.now().toIso8601String(),
          localId: _nextLocalId(),
        )
          ..['reply_to_sender'] = replySender
          ..['reply_to_text'] = replyText,
      );
      _replyTo = null;
      _isSending = false;
    });
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
    );

    setState(() {
      final messageId = normalized['id']?.toString();
      if (messageId != null) {
        _messages.removeWhere((m) => m['id']?.toString() == messageId);
      }
      _messages.insert(0, normalized);
    });
  }

  Future<void> _downloadSharedRoute(Map<String, dynamic> message) async {
    if (_token == null || !_isRouteMessage(message)) return;

    final share = Map<String, dynamic>.from(message['route_share'] as Map);
    final shareId = (share['id'] as num?)?.toInt();
    final originalFilename =
        share['originalFilename']?.toString() ?? 'route.gpx';
    if (shareId == null) return;

    final key = _routeDownloadKey(message);
    if (_downloadingRouteKeys.contains(key)) return;

    setState(() => _downloadingRouteKeys.add(key));

    try {
      final routeService = ChatRouteService(token: _token!);
      final savedPath = await routeService.downloadRoute(
        chatId: widget.chatId,
        shareId: shareId,
        originalFilename: originalFilename,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Маршрут сохранён: $savedPath')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось скачать маршрут: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _downloadingRouteKeys.remove(key));
      }
    }
  }

  Future<void> _openAttachRouteDialog() async {
    if (_token == null) return;

    await showDialog<void>(
      context: context,
      builder: (_) => AttachRouteDialog(
        chatId: widget.chatId,
        routeService: ChatRouteService(token: _token!),
        onShared: _insertSharedRouteMessage,
      ),
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
      onChatDeleted: () {
        if (mounted) Navigator.pop(context);
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AuthColors.title),
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
              _participants.isEmpty
                  ? 'подключение...'
                  : _creatorName != null && _creatorName!.isNotEmpty
                      ? '${_participants.length} участников · создатель: $_creatorName'
                      : '${_participants.length} участников',
              style: authSubtitleStyle().copyWith(fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                onPressed: () async {
                  setState(() => _newIncomingCount = 0);
                  await _markChatAsRead();
                  await NotificationService.instance.cancelAll();
                },
                icon: const Icon(Icons.notifications_outlined),
              ),
              if (_newIncomingCount > 0)
                Positioned(
                  right: 9,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _newIncomingCount > 99 ? '99+' : '$_newIncomingCount',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.group_outlined),
            tooltip: 'Участники',
            onPressed: _openParticipantsSheet,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
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
                            final currentDate = _parseTimestamp(message['timestamp']);
                            final nextOlderDate = index + 1 < _messages.length
                                ? _parseTimestamp(_messages[index + 1]['timestamp'])
                                : null;
                            final showDayDivider =
                                nextOlderDate == null || !_isSameDay(currentDate, nextOlderDate);

                            final isCurrentUser =
                                message['sender_id']?.toString() == _currentUserId;
                            final sender = isCurrentUser
                                ? 'Вы'
                                : (message['sender']?.toString() ?? _currentUserName ?? 'Участник');
                            final time = _formatTime(message['timestamp']);
                            final messageId = message['local_id']?.toString() ?? '$index';
                            final reactions = _parseReactions(message['reactions']);

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
                                  margin: const EdgeInsets.symmetric(horizontal: 16),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.reply_rounded, color: AuthColors.body),
                                      SizedBox(width: 6),
                                      Text('Ответить',
                                          style: TextStyle(color: AuthColors.body)),
                                    ],
                                  ),
                                ),
                              ),
                              child: Align(
                                alignment: isCurrentUser
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: GestureDetector(
                                  onLongPress: () => _showMessageActions(
                                    message,
                                    isCurrentUser,
                                    messageId,
                                  ),
                                  child: Container(
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                                    ),
                                    margin: const EdgeInsets.symmetric(vertical: 3),
                                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                                    decoration: BoxDecoration(
                                      color: isCurrentUser
                                          ? const Color(0xFFDCF8C6)
                                          : Colors.white,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(14),
                                        topRight: const Radius.circular(14),
                                        bottomLeft: Radius.circular(isCurrentUser ? 14 : 4),
                                        bottomRight: Radius.circular(isCurrentUser ? 4 : 14),
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x14000000),
                                          blurRadius: 6,
                                          offset: Offset(0, 2),
                                        )
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (!isCurrentUser)
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
                                            margin: const EdgeInsets.only(bottom: 6),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.06),
                                              borderRadius: BorderRadius.circular(8),
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
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  message['reply_to_sender'].toString(),
                                                  style: GoogleFonts.lexendDeca(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(0xFF4D4D4D),
                                                  ),
                                                ),
                                                Text(
                                                  message['reply_to_text'].toString(),
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
                                            title: (message['route_share']
                                                        as Map)['title']
                                                    ?.toString() ??
                                                'Маршрут',
                                            fileName: (message['route_share']
                                                        as Map)['originalFilename']
                                                    ?.toString() ??
                                                'route.gpx',
                                            fileSize: ((message['route_share']
                                                        as Map)['fileSize']
                                                    as num?)
                                                ?.toInt(),
                                            isCurrentUser: isCurrentUser,
                                            isDownloading:
                                                _downloadingRouteKeys.contains(
                                              _routeDownloadKey(message),
                                            ),
                                            onDownload: () =>
                                                _downloadSharedRoute(message),
                                          )
                                        else
                                          Text(
                                            message['content']?.toString() ??
                                                '',
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
                                              const Icon(
                                                Icons.done_all_rounded,
                                                size: 14,
                                                color: Color(0xFF6AA7D8),
                                              ),
                                            ],
                                          ],
                                        ),
                                        ChatMessageReactions(
                                          reactions: reactions,
                                          currentUserId: _currentUserId,
                                          onReactionTap: message['id'] == null
                                              ? null
                                              : (emoji) => _toggleReaction(
                                                    message,
                                                    emoji,
                                                  ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );

                            return Column(
                              children: [
                                if (showDayDivider)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: const Color(0xFFE4E4E4)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.reply_rounded, size: 18, color: AuthColors.body),
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
                SafeArea(
                  top: false,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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

