import 'dart:async';
import 'package:flutter/material.dart';
import 'package:map_routing/UIWidgets/chat.dart';
import 'package:map_routing/UIWidgets/chat_screen_widget.dart';
import 'package:map_routing/UIWidgets/friend.dart';
import 'package:map_routing/create_chat_dialog.dart';
import 'package:map_routing/user_search_result.dart';
import 'package:map_routing/usersData/group_service.dart';
import 'package:map_routing/usersData/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:map_routing/usersData/friend_service.dart';
import 'package:map_routing/usersData/user_search_service.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

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
  String? _currentUserId;
  bool _dataLoaded = false;
  bool _loading = false;
  Object? _loadError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
    loadData();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    loadData();
  }

  void loadData() {
    if (_loading) return;

    setState(() {
      _loading = true;
    });

    _initializeServiceAndLoadData().then((_) {
      setState(() {
        _dataLoaded = true;
        _loading = false;
        _loadError = null;
      });
    }).catchError((error) {
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
      Navigator.pushReplacementNamed(context, '/login_page');
      throw Exception('Токен не найден');
    }

    _chatService =
        GroupChatService(baseUrl: 'http://192.168.1.81:5000', token: token);
    _friendService =
        FriendService(baseUrl: 'http://192.168.1.81:5000', token: token);
    _userSearchService =
        UserSearchService(baseUrl: 'http://192.168.1.81:5000', token: token);
    final userService = UserService();
    final userInfo = await userService.fetchUserInfo();
    if (userInfo == null) {
      throw Exception('Не удалось получить информацию о пользователе');
    }
    final userId = userInfo['id']?.toString();
    if (userId == null) {
      throw Exception('Идентификатор пользователя не найден в данных сервера');
    }

    final chats = await _chatService!.fetchUserChats();
    final friends = await _friendService!.fetchFriends();

    setState(() {
      _chats = chats;
      _friends = friends;
      _currentUserId = userId;
    });
  }

  Future<void> _createNewChat() async {
    if (!_dataLoaded && !_loading) {
      setState(() {
        _loading = true;
      });
      try {
        await _initializeServiceAndLoadData();
        setState(() {
          _dataLoaded = true;
          _loading = false;
          _loadError = null;
        });
      } catch (error) {
        setState(() {
          _loadError = error;
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка загрузки данных: $error")),
        );
        return;
      }
    }

    if (_currentUserId == null || _chatService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Ошибка: данные пользователя не инициализированы")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => CreateChatDialog(
        friends: _friends,
        chatService: _chatService!,
        onChatCreated: (newChat) {
          setState(() => _chats.add(newChat));
        },
        currentUserId: _currentUserId!,
      ),
    );
  }

  void _showSearchDialog() {
    String searchQuery = '';
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('Поиск пользователя'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                        hintText: 'Введите имя пользователя'),
                    onChanged: (value) async {
                      setState(() {
                        searchQuery = value;
                        isSearching = true;
                      });
                      if (value.isNotEmpty) {
                        await Future.delayed(const Duration(milliseconds: 300));
                        if (searchQuery == value &&
                            _userSearchService != null) {
                          try {
                            final users =
                                await _userSearchService!.searchUsers(value);
                            print(
                                'Found users for "$value": $users'); // Отладка
                            setState(() {
                              searchResults = users;
                              isSearching = false;
                            });
                          } catch (e) {
                            print('Search error: $e');
                            setState(() {
                              searchResults = [];
                              isSearching = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Ошибка поиска: $e")),
                            );
                          }
                        }
                      } else {
                        setState(() {
                          searchResults = [];
                          isSearching = false;
                        });
                      }
                    },
                  ),
                  if (isSearching)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  SizedBox(
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final user = searchResults[index];
                        try {
                          return UserSearchResult(
                            userId: user['id']
                                .toString(), // ID целевого пользователя
                            name: user['name'] ?? 'Без имени',
                            onAddFriend: (targetUserId) async {
                              if (_friendService != null &&
                                  _currentUserId != null) {
                                print(
                                    'Sending request: from $_currentUserId to $targetUserId'); // Отладка
                                await _friendService!
                                    .sendFriendRequest(targetUserId);
                              }
                            },
                          );
                        } catch (e) {
                          print('Error rendering user $index: $e');
                          return ListTile(title: Text('Ошибка рендеринга'));
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        );
      },
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
            Text("Ошибка: $_loadError"),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _dataLoaded = false;
                  _loadError = null;
                });
                loadData();
              },
              child: const Text("Повторить"),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(""),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _dataLoaded ? _buildChatContent() : const SizedBox.shrink(),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewChat,
        backgroundColor: Colors.white,
        elevation: 4,
        tooltip: "Создать новый чат",
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildChatContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Text(
            "Друзья",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 81,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: IconButton(
                  icon: const Icon(Icons.add, size: 40, color: Colors.blue),
                  onPressed: _showSearchDialog,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 12),
                  itemCount: _friends.length,
                  itemBuilder: (context, index) {
                    final friend = _friends[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundImage: NetworkImage(friend.avatarUrl),
                              ),
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: friend.isOnline
                                        ? Colors.green
                                        : Colors.white,
                                    border: Border.all(
                                        color: Colors.black26, width: 1),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 60, // ограничиваем ширину
                            child: Text(
                              friend
                                  .name, // предполагается, что у `Friend` есть поле `name`
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(
            thickness: 1,
            color: Colors.grey,
            indent: 16,
            endIndent: 16,
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            "Чаты",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: _chats.isEmpty
              ? const Center(child: Text("Вы ещё не состоите в чатах."))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 0),
                  itemCount: _chats.length,
                  itemBuilder: (context, index) {
                    final chat = _chats[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 6.0),
                      child: Material(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ChatScreen(chatId: chat.id),
                                ));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(chat.title,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(chat.lastMessage,
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.black54)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
