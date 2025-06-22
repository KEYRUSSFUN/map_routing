import 'package:flutter/material.dart';
import 'package:map_routing/UIWidgets/friend.dart';
import 'package:map_routing/UIWidgets/chat.dart';
import 'package:map_routing/usersData/group_service.dart';

class CreateChatDialog extends StatefulWidget {
  final List<Friend> friends;
  final GroupChatService chatService;
  final void Function(Chat newChat) onChatCreated;
  final String currentUserId;

  const CreateChatDialog({
    super.key,
    required this.friends,
    required this.chatService,
    required this.onChatCreated,
    required this.currentUserId,
  });

  @override
  State<CreateChatDialog> createState() => _CreateChatDialogState();
}

class _CreateChatDialogState extends State<CreateChatDialog> {
  final TextEditingController _titleController = TextEditingController();
  final Set<String> _selectedFriendIds = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text("Создание нового чата"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Название чата'),
            ),
            const SizedBox(height: 10),
            const Text("Выберите участников:",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              height: 300,
              width: double.maxFinite,
              child: ListView.builder(
                itemCount: widget.friends.length,
                itemBuilder: (context, index) {
                  final friend = widget.friends[index];
                  final isSelected = _selectedFriendIds.contains(friend.id);

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(friend.avatarUrl),
                    ),
                    title: Text(friend.name),
                    trailing: Checkbox(
                      value: isSelected,
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedFriendIds.add(friend.id);
                          } else {
                            _selectedFriendIds.remove(friend.id);
                          }
                        });
                      },
                    ),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedFriendIds.remove(friend.id);
                        } else {
                          _selectedFriendIds.add(friend.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Отмена"),
        ),
        ElevatedButton(
          onPressed: () async {
            final title = _titleController.text.trim();
            if (title.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Введите название чата.")),
              );
              return;
            }

            final participants = <String>{
              widget.currentUserId,
              ..._selectedFriendIds
            };

            if (participants.length < 2) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Выберите хотя бы одного участника.")),
              );
              return;
            }

            final newChat = await widget.chatService.createGroupChat(
              title,
              participants.toList(),
            );
            widget.onChatCreated(newChat);
            Navigator.pop(context);
          },
          child: const Text("Создать"),
        ),
      ],
    );
  }
}
