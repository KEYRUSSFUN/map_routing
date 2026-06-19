import 'dart:convert';
import 'dart:io';

import 'package:map_routing/core/network/backend_urls.dart';
import 'package:map_routing/data/models/chat_participant.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ChatDetailsSnapshot {
  const ChatDetailsSnapshot({
    required this.title,
    this.photoUrl,
    this.creatorId,
    this.creatorName,
    this.participants = const [],
  });

  final String title;
  final String? photoUrl;
  final int? creatorId;
  final String? creatorName;
  final List<ChatParticipant> participants;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (creatorId != null) 'creatorId': creatorId,
      if (creatorName != null) 'creatorName': creatorName,
      'participants': participants
          .map(
            (participant) => {
              'id': participant.userId,
              'name': participant.name,
              'isCreator': participant.isCreator,
              if (participant.avatarUrl != null)
                'avatar_url': participant.avatarUrl,
            },
          )
          .toList(),
    };
  }

  factory ChatDetailsSnapshot.fromJson(Map<String, dynamic> json) {
    final creatorId = (json['creatorId'] as num?)?.toInt();
    final participantsRaw = json['participants'];
    return ChatDetailsSnapshot(
      title: json['title']?.toString() ?? '',
      photoUrl: absoluteBackendUrl(json['photoUrl']?.toString()),
      creatorId: creatorId,
      creatorName: json['creatorName']?.toString(),
      participants: participantsRaw is List
          ? ChatParticipant.fromJsonList(participantsRaw, creatorId: creatorId)
          : const [],
    );
  }
}

class ChatDetailsCache {
  ChatDetailsCache._();

  static final ChatDetailsCache instance = ChatDetailsCache._();

  static const _cacheRootName = 'chat_details';

  Future<Directory?> _cacheRoot() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, _cacheRootName));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  File? _detailsFile(Directory root, String userId, String chatId) {
    final safeUserId = userId.replaceAll(RegExp(r'[^\w\-]'), '_');
    final safeChatId = chatId.replaceAll(RegExp(r'[^\w\-]'), '_');
    return File(p.join(root.path, safeUserId, '$safeChatId.json'));
  }

  Future<ChatDetailsSnapshot?> load({
    required String userId,
    required String chatId,
  }) async {
    final root = await _cacheRoot();
    if (root == null) return null;

    final file = _detailsFile(root, userId, chatId);
    if (file == null || !file.existsSync()) return null;

    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map<String, dynamic>) return null;
      return ChatDetailsSnapshot.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> save({
    required String userId,
    required String chatId,
    required ChatDetailsSnapshot snapshot,
  }) async {
    final root = await _cacheRoot();
    if (root == null) return;

    final file = _detailsFile(root, userId, chatId);
    if (file == null) return;

    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(snapshot.toJson()));
  }

  Future<void> clear({
    required String userId,
    required String chatId,
  }) async {
    final root = await _cacheRoot();
    if (root == null) return;

    final file = _detailsFile(root, userId, chatId);
    if (file != null && file.existsSync()) {
      await file.delete();
    }
  }
}
