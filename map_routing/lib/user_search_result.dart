import 'package:flutter/material.dart';

class UserSearchResult extends StatefulWidget {
  final String userId;
  final String name;
  final Future<void> Function(String userId)
      onAddFriend; // Изменим на асинхронную функцию

  const UserSearchResult({
    super.key,
    required this.userId,
    required this.name,
    required this.onAddFriend,
  });

  @override
  State<UserSearchResult> createState() => _UserSearchResultState();
}

class _UserSearchResultState extends State<UserSearchResult> {
  bool _isFriendRequestSent = false;

  @override
  Widget build(BuildContext context) {
    print(
        'Rendering UserSearchResult: userId=${widget.userId}, name=${widget.name}');
    try {
      return ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        leading: CircleAvatar(
          radius: 20,
          backgroundImage:
              NetworkImage('https://i.pravatar.cc/100?img=${widget.userId}'),
        ),
        title: Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: SizedBox(
          width: 90,
          child: ElevatedButton(
            onPressed: _isFriendRequestSent
                ? null // Отключаем кнопку, если заявка отправлена
                : () async {
                    try {
                      await widget.onAddFriend(
                          widget.userId); // Выполняем асинхронный вызов
                      setState(() {
                        _isFriendRequestSent = true; // Обновляем состояние
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Запрос на дружбу отправлен")),
                      );
                    } catch (e) {
                      print('Error sending friend request: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Ошибка: $e")),
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              minimumSize: const Size(0, 36),
              backgroundColor: _isFriendRequestSent
                  ? Colors.grey
                  : null, // Серый цвет для отправленной заявки
            ),
            child: Text(_isFriendRequestSent ? 'Отправлено' : 'Добавить'),
          ),
        ),
      );
    } catch (e) {
      print('Error in UserSearchResult: $e');
      return ListTile(title: Text('Ошибка: ${widget.name}'));
    }
  }
}
