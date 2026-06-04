import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/network/config.dart';
import 'package:map_routing/core/services/notification_service.dart';
import 'package:map_routing/data/services/group_service.dart';
import 'package:map_routing/data/services/socket_chat_service.dart';
import 'package:map_routing/data/services/user_service.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:map_routing/features/chat/widgets/attach_route_dialog.dart';
import 'package:map_routing/features/profile/presentation/user_profile_page.dart';
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
  List<_ChatParticipant> _participants = [];
  List<Map<String, dynamic>> _messages = [];
  final Map<String, String> _reactions = {};

  Map<String, dynamic>? _replyTo;
  int _localCounter = 0;

  bool _isLoading = true;
  bool _isSending = false;
  int _newIncomingCount = 0;

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
  }) {
    final text = (content ?? '').toString();

    String? replySender;
    String? replyText;
    var plainText = text;

    if (text.startsWith('↪ ') && text.contains('\n')) {
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
      'local_id': localId ?? _nextLocalId(),
      'sender_id': senderId?.toString() ?? 'unknown',
      'sender': sender?.toString() ?? 'Неизвестный пользователь',
      'content': plainText,
      'timestamp': timestamp?.toString() ?? DateTime.now().toIso8601String(),
      'reply_to_sender': replySender,
      'reply_to_text': replyText,
    };
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
    await _socketService.initialize(backendBaseUrl);

    _socketService.on('new_message', (data) async {
      if (!mounted) return;

      final senderId = data['sender_id']?.toString() ?? 'unknown';
      final sender = data['sender']?.toString() ?? 'Участник';
      final content = data['content']?.toString() ?? '';

      final incoming = _normalizeMessage(
        senderId: senderId,
        sender: sender,
        content: content,
        timestamp: data['timestamp'],
      );

      setState(() {
        _messages.insert(0, incoming);
        if (senderId != _currentUserId) {
          _newIncomingCount += 1;
        }
      });

      if (senderId != _currentUserId && content.isNotEmpty) {
        await NotificationService.instance.show(
          title: _chatTitle.isEmpty ? 'Новое сообщение' : _chatTitle,
          body: '$sender: $content',
          payload: widget.chatId,
        );
      }
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

  Future<void> _fetchChatData() async {
    try {
      final groupChatService = GroupChatService(token: _token!);
      final chatDetails = await groupChatService
          .getChatDetails(widget.chatId)
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      setState(() {
        _chatTitle = (chatDetails['title'] ?? widget.initialTitle ?? '').toString();
        _participants = _parseParticipants(chatDetails['participants']);
        _messages = List<Map<String, dynamic>>.from(
          (chatDetails['messages'] ?? []).map((m) => _normalizeMessage(
                senderId: m['sender_id'],
                sender: m['sender'],
                content: m['content'],
                timestamp: m['timestamp'],
              )),
        ).reversed.toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки чата: $e')),
      );
    }
  }

  List<_ChatParticipant> _parseParticipants(dynamic raw) {
    if (raw is! List) return const [];

    return raw.map<_ChatParticipant>((item) {
      if (item is Map<String, dynamic>) {
        return _ChatParticipant(
          name: (item['name'] ?? 'Пользователь').toString(),
          userId: item['id']?.toString() ?? item['userId']?.toString(),
        );
      }
      if (item is Map) {
        return _ChatParticipant(
          name: (item['name'] ?? 'Пользователь').toString(),
          userId: item['id']?.toString() ?? item['userId']?.toString(),
        );
      }
      return _ChatParticipant(name: item.toString(), userId: null);
    }).toList();
  }

  void _setReplyTo(Map<String, dynamic> message) {
    setState(() => _replyTo = message);
  }

  Future<void> _showReactionPicker(String messageId) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        const emojis = ['👍', '🔥', '❤️', '👏', '😂', '😮'];
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Wrap(
            spacing: 12,
            children: emojis
                .map(
                  (emoji) => GestureDetector(
                    onTap: () => Navigator.pop(context, emoji),
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
        );
      },
    );

    if (!mounted || selected == null) return;
    setState(() => _reactions[messageId] = selected);
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

  void _openParticipantsSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Участники',
                style: GoogleFonts.lexendDeca(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AuthColors.title,
                ),
              ),
              const SizedBox(height: 10),
              if (_participants.isEmpty)
                Text('Список участников недоступен', style: authSubtitleStyle())
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _participants.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AuthColors.divider),
                    itemBuilder: (context, index) {
                      final user = _participants[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor:
                              AuthColors.primaryGreen.withValues(alpha: 0.16),
                          child: Text(
                            user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        title: Text(
                          user.name,
                          style: GoogleFonts.lexendDeca(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AuthColors.title,
                          ),
                        ),
                        trailing:
                            user.userId == null ? null : const Icon(Icons.chevron_right),
                        onTap: user.userId == null
                            ? null
                            : () {
                                Navigator.pop(context);
                                Navigator.of(this.context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        UserProfilePage(userId: user.userId!),
                                  ),
                                );
                              },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
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
                  : '${_participants.length} участников',
              style: authSubtitleStyle().copyWith(fontSize: 11),
            ),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                onPressed: () => setState(() => _newIncomingCount = 0),
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
                            final reaction = _reactions[messageId];

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
                                  onLongPress: () => _showReactionPicker(messageId),
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
                                              const Icon(
                                                Icons.done_all_rounded,
                                                size: 14,
                                                color: Color(0xFF6AA7D8),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (reaction != null)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(
                                                    color: const Color(0xFFD8D8D8)),
                                              ),
                                              child: Text(reaction),
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
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
                          icon: const FaIcon(
                            FontAwesomeIcons.route,
                            size: 18,
                            color: Color(0xFF7A7A7A),
                          ),
                          tooltip: 'Прикрепить маршрут',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => const AttachRouteDialog(),
                            );
                          },
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
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        Container(
                          decoration: const BoxDecoration(
                            color: AuthColors.primaryGreen,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: _isSending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const FaIcon(
                                    FontAwesomeIcons.paperPlane,
                                    size: 16,
                                    color: Colors.black87,
                                  ),
                            onPressed: _isSending ? null : _sendMessage,
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

class _ChatParticipant {
  const _ChatParticipant({required this.name, required this.userId});

  final String name;
  final String? userId;
}
