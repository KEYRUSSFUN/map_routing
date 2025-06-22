import 'dart:async';
import 'package:flutter/material.dart';
import 'package:map_routing/UIWidgets/attach_route_dialog.dart';
import 'package:map_routing/usersData/sockect_chat_service.dart';
import 'package:map_routing/usersData/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:map_routing/usersData/group_service.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class ChatScreen extends StatefulWidget {
  final String chatId;

  const ChatScreen({super.key, required this.chatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with RouteAware {
  final TextEditingController _messageController = TextEditingController();
  late SocketChatService _socketService;
  String? _token;
  String? _currentUserId;
  String? _currentUserName;
  final UserService _userService = UserService();

  String chatTitle = '';
  List<String> participants = [];
  List<Map<String, dynamic>> messages = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _socketService = SocketChatService();
    _loadTokenAndInitializeSocket();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _socketService.disconnect();
    _messageController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _reconnectSocketAndReload();
  }

  Future<void> _loadTokenAndInitializeSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token != null && token.isNotEmpty) {
      setState(() {
        _token = token;
      });

      try {
        await _loadUserInfo();
        await _initializeSocket();
        await _fetchChatData();
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка инициализации: $e')),
        );
      }
    } else {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Токен не найден. Пожалуйста, войдите в систему')),
      );
    }
  }

  Future<void> _loadUserInfo() async {
    final userInfo = await _userService.fetchUserInfo();
    if (userInfo != null) {
      _currentUserId = userInfo['id'].toString();
      _currentUserName = userInfo['name'].toString();
    } else {
      throw Exception('Не удалось загрузить данные пользователя');
    }
  }

  Future<void> _initializeSocket() async {
    _socketService.off('new_message');
    await _socketService.initialize('http://192.168.1.81:5000');
    _socketService.on('new_message', (data) {
      setState(() {
        messages.insert(0, {
          'sender_id': data['sender_id']?.toString() ?? 'unknown',
          'sender': data['sender'] ?? 'Неизвестный пользователь',
          'content': data['content'] ?? '',
        });
      });
    });
    _socketService.joinChat(widget.chatId);
  }

  Future<void> _reconnectSocketAndReload() async {
    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null || token.isEmpty) {
        throw Exception('Токен не найден');
      }
      setState(() {
        _token = token;
      });

      await _loadUserInfo();
      _socketService.disconnect();
      await _initializeSocket();
      await _fetchChatData();
      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при переподключении: $e')),
      );
    }
  }

  Future<void> _fetchChatData() async {
    try {
      final groupChatService =
          GroupChatService(baseUrl: 'http://192.168.1.81:5000', token: _token!);
      final chatDetails =
          await groupChatService.getChatDetails(widget.chatId).timeout(
                const Duration(seconds: 10),
                onTimeout: () => throw TimeoutException(
                    'Превышено время ожидания загрузки чата'),
              );

      setState(() {
        chatTitle = chatDetails['title'] ?? '';
        participants = List<String>.from(chatDetails['participants'] ?? []);
        messages = List<Map<String, dynamic>>.from(
          (chatDetails['messages'] ?? []).map((m) => {
                'sender_id': m['sender_id']?.toString() ?? 'unknown',
                'sender': m['sender'] ?? 'Неизвестный пользователь',
                'content': m['content'] ?? '',
              }),
        );
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при загрузке чата: $e')),
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _token == null) return;

    if (!_socketService.isConnected) {
      await _reconnectSocketAndReload();
      if (!_socketService.isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось подключиться к серверу')),
        );
        return;
      }
    }

    _socketService.sendMessage(widget.chatId, text);
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(chatTitle),
            if (participants.isNotEmpty)
              Text(
                participants.join(', '),
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: messages.isEmpty
                      ? const Center(child: Text("Нет сообщений"))
                      : ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.all(12),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final isCurrentUser =
                                message['sender_id'] == _currentUserId;
                            final sender = isCurrentUser
                                ? 'Вы'
                                : (message['sender'] ?? _currentUserName);
                            return Align(
                              alignment: isCurrentUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isCurrentUser
                                      ? Colors.blue[200]
                                      : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('$sender: ${message['content']}'),
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: Colors.grey[100],
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                              hintText: "Введите сообщение..."),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _sendMessage,
                      ),
                      IconButton(
                        icon: const Icon(Icons.alt_route),
                        tooltip: 'Прикрепить маршрут',
                        onPressed: () async {
                          showDialog(
                            context: context,
                            builder: (_) => const AttachRouteDialog(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
