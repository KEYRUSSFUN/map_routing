import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

List<Map<String, dynamic>> decodeChatMessagesJson(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  } catch (_) {
    return [];
  }
}

List<Map<String, dynamic>> cloneChatMessages(List<Map<String, dynamic>> messages) {
  return messages
      .map((message) => Map<String, dynamic>.from(message))
      .toList();
}

class ChatMessageCache {
  ChatMessageCache._();

  static final ChatMessageCache instance = ChatMessageCache._();

  static const _cacheRootName = 'chat_messages';
  static const _maxMessagesPerChat = 500;

  Timer? _saveDebounceTimer;
  String? _pendingUserId;
  String? _pendingChatId;
  List<Map<String, dynamic>>? _pendingMessages;

  void scheduleSave({
    required String userId,
    required String chatId,
    required List<Map<String, dynamic>> messages,
  }) {
    _pendingUserId = userId;
    _pendingChatId = chatId;
    _pendingMessages = messages;
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(_flushScheduledSave());
    });
  }

  Future<void> flushScheduledSave() => _flushScheduledSave();

  Future<void> _flushScheduledSave() async {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = null;

    final userId = _pendingUserId;
    final chatId = _pendingChatId;
    final messages = _pendingMessages;
    _pendingUserId = null;
    _pendingChatId = null;
    _pendingMessages = null;

    if (userId == null || chatId == null || messages == null) return;
    await saveMessages(userId: userId, chatId: chatId, messages: messages);
  }

  Future<Directory?> _cacheRoot() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, _cacheRootName));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  File? _chatFile(Directory root, String userId, String chatId) {
    final safeUserId = userId.replaceAll(RegExp(r'[^\w\-]'), '_');
    final safeChatId = chatId.replaceAll(RegExp(r'[^\w\-]'), '_');
    return File(p.join(root.path, safeUserId, '$safeChatId.json'));
  }

  Future<List<Map<String, dynamic>>> loadMessages({
    required String userId,
    required String chatId,
  }) async {
    final root = await _cacheRoot();
    if (root == null) return [];

    final file = _chatFile(root, userId, chatId);
    if (file == null || !file.existsSync()) return [];

    try {
      final raw = await file.readAsString();
      if (raw.length > 32 * 1024) {
        return compute(decodeChatMessagesJson, raw);
      }
      return decodeChatMessagesJson(raw);
    } catch (_) {
      return [];
    }
  }

  Future<void> saveMessages({
    required String userId,
    required String chatId,
    required List<Map<String, dynamic>> messages,
  }) async {
    final root = await _cacheRoot();
    if (root == null) return;

    final file = _chatFile(root, userId, chatId);
    if (file == null) return;

    await file.parent.create(recursive: true);

    final trimmed = messages.length <= _maxMessagesPerChat
        ? messages
        : messages.sublist(0, _maxMessagesPerChat);

    final serializable = trimmed
        .map((message) => Map<String, dynamic>.from(message))
        .toList();

    await file.writeAsString(jsonEncode(serializable));
  }

  Future<void> clearChat({
    required String userId,
    required String chatId,
  }) async {
    final root = await _cacheRoot();
    if (root == null) return;

    final file = _chatFile(root, userId, chatId);
    if (file != null && file.existsSync()) {
      await file.delete();
    }
  }

  int? lastServerMessageId(List<Map<String, dynamic>> messages) {
    var maxId = 0;
    var found = false;
    for (final message in messages) {
      final id = int.tryParse(message['id']?.toString() ?? '');
      if (id != null && id > maxId) {
        maxId = id;
        found = true;
      }
    }
    return found ? maxId : null;
  }
}
