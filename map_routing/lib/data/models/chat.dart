class Chat {
  final String id;
  final String title;
  final String lastMessage;
  final String lastMessageSender;
  final int unreadCount;
  final int? creatorId;
  final String? creatorName;
  final bool isInvitationUnread;

  Chat({
    required this.id,
    required this.title,
    required this.lastMessage,
    this.lastMessageSender = '',
    this.unreadCount = 0,
    this.creatorId,
    this.creatorName,
    this.isInvitationUnread = false,
  });

  String get lastMessagePreview {
    if (lastMessage.isEmpty) return 'Начните обсуждение в группе';
    if (lastMessageSender.isEmpty) return lastMessage;
    return '$lastMessageSender: $lastMessage';
  }

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      lastMessage: json['lastMessage'] ?? '',
      lastMessageSender: json['lastMessageSender']?.toString() ?? '',
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      creatorId: (json['creatorId'] as num?)?.toInt(),
      creatorName: json['creatorName']?.toString(),
      isInvitationUnread: json['isInvitationUnread'] == true,
    );
  }
}

class GroupChatsResponse {
  const GroupChatsResponse({
    required this.chats,
    required this.unreadInvitationCount,
  });

  final List<Chat> chats;
  final int unreadInvitationCount;
}
