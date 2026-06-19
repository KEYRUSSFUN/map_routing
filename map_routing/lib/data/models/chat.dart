import 'package:map_routing/core/network/backend_urls.dart';

class Chat {
  final String id;
  final String title;
  final String lastMessage;
  final String lastMessageSender;
  final int unreadCount;
  final int? creatorId;
  final String? creatorName;
  final bool isInvitationUnread;
  final String? photoUrl;
  final bool notificationsMuted;

  Chat({
    required this.id,
    required this.title,
    required this.lastMessage,
    this.lastMessageSender = '',
    this.unreadCount = 0,
    this.creatorId,
    this.creatorName,
    this.isInvitationUnread = false,
    this.photoUrl,
    this.notificationsMuted = false,
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
      photoUrl: absoluteBackendUrl(json['photoUrl']?.toString()),
      notificationsMuted: json['notificationsMuted'] == true,
    );
  }

  Chat copyWith({
    String? id,
    String? title,
    String? lastMessage,
    String? lastMessageSender,
    int? unreadCount,
    int? creatorId,
    String? creatorName,
    bool? isInvitationUnread,
    String? photoUrl,
    bool? notificationsMuted,
  }) {
    return Chat(
      id: id ?? this.id,
      title: title ?? this.title,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSender: lastMessageSender ?? this.lastMessageSender,
      unreadCount: unreadCount ?? this.unreadCount,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      isInvitationUnread: isInvitationUnread ?? this.isInvitationUnread,
      photoUrl: photoUrl ?? this.photoUrl,
      notificationsMuted: notificationsMuted ?? this.notificationsMuted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'lastMessage': lastMessage,
      'lastMessageSender': lastMessageSender,
      'unreadCount': unreadCount,
      if (creatorId != null) 'creatorId': creatorId,
      if (creatorName != null) 'creatorName': creatorName,
      'isInvitationUnread': isInvitationUnread,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'notificationsMuted': notificationsMuted,
    };
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
