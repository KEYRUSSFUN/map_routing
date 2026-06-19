import 'dart:collection';

import 'package:map_routing/data/models/chat_participant.dart';
import 'package:map_routing/data/services/chat_details_cache.dart';
import 'package:map_routing/data/services/chat_message_cache.dart';

class ChatSessionData {
  ChatSessionData({
    required this.messages,
    required this.chatTitle,
    this.photoUrl,
    this.creatorId,
    this.creatorName,
    this.participants = const [],
    this.currentUserId,
    this.currentUserName,
  });

  final List<Map<String, dynamic>> messages;
  final String chatTitle;
  final String? photoUrl;
  final int? creatorId;
  final String? creatorName;
  final List<ChatParticipant> participants;
  final String? currentUserId;
  final String? currentUserName;

  ChatSessionData copyWith({
    List<Map<String, dynamic>>? messages,
    String? chatTitle,
    String? photoUrl,
    int? creatorId,
    String? creatorName,
    List<ChatParticipant>? participants,
    String? currentUserId,
    String? currentUserName,
  }) {
    return ChatSessionData(
      messages: messages ?? this.messages,
      chatTitle: chatTitle ?? this.chatTitle,
      photoUrl: photoUrl ?? this.photoUrl,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      participants: participants ?? this.participants,
      currentUserId: currentUserId ?? this.currentUserId,
      currentUserName: currentUserName ?? this.currentUserName,
    );
  }
}

/// In-memory LRU cache for recently opened chats (instant reopen).
class ChatSessionCache {
  ChatSessionCache._();

  static final ChatSessionCache instance = ChatSessionCache._();

  static const _maxEntries = 15;
  final LinkedHashMap<String, ChatSessionData> _entries = LinkedHashMap();

  ChatSessionData? get(String chatId) => _entries[chatId];

  void put(String chatId, ChatSessionData data) {
    _entries.remove(chatId);
    _entries[chatId] = data;
    while (_entries.length > _maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  void remove(String chatId) {
    _entries.remove(chatId);
  }

  void clear() {
    _entries.clear();
  }

  Future<void> warmFromDisk({
    required String userId,
    required String chatId,
    String? fallbackTitle,
  }) async {
    if (_entries.containsKey(chatId)) return;

    final messagesFuture = ChatMessageCache.instance.loadMessages(
      userId: userId,
      chatId: chatId,
    );
    final detailsFuture = ChatDetailsCache.instance.load(
      userId: userId,
      chatId: chatId,
    );

    final messages = await messagesFuture;
    final details = await detailsFuture;
    if (messages.isEmpty && details == null) return;

    put(
      chatId,
      ChatSessionData(
        messages: messages
            .map((message) => Map<String, dynamic>.from(message))
            .toList(),
        chatTitle: details?.title ?? fallbackTitle ?? '',
        photoUrl: details?.photoUrl,
        creatorId: details?.creatorId,
        creatorName: details?.creatorName,
        participants: details?.participants ?? const [],
      ),
    );
  }
}
