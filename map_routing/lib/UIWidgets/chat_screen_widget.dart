import 'package:flutter/material.dart';
import 'package:map_routing/usersData/group_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;

  const ChatScreen({super.key, required this.chatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  String chatTitle = '';
  List<String> participants = [];
  List<String> messages = [];

  bool isLoading = true;

  String? _token; // Токен

  @override
  void initState() {
    super.initState();
    _loadTokenAndFetchData();
  }

  Future<void> _fetchChatDataWithToken(String token) async {
    try {
      final groupChatService =
          GroupChatService(baseUrl: 'http://192.168.1.81:5000', token: token);
      final chatDetails = await groupChatService.getChatDetails(widget.chatId);

      setState(() {
        chatTitle = chatDetails['title'] ?? '';
        participants = List<String>.from(chatDetails['participants'] ?? []);
        messages = List<String>.from(
          (chatDetails['messages'] ?? [])
              .map((m) => '${m['sender']}: ${m['content']}'),
        );
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при загрузке чата: $e')),
        );
      });
    }
  }

  Future<void> _loadTokenAndFetchData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token != null && token.isNotEmpty) {
      setState(() {
        _token = token;
      });

      await _fetchChatDataWithToken(token);
    } else {
      setState(() {
        isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Токен не найден. Пожалуйста, войдите в систему')),
        );
      });
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.insert(
          0, 'Вы: $text'); // Добавляем новое сообщение с префиксом "Вы"
      _messageController.clear();
    });

    // Здесь нужно добавить вызов GroupChatService.sendMessage(widget.chatId, text)
    // с обработкой ошибок и обновлением сообщений с сервера при необходимости
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
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(message),
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
                      )
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
