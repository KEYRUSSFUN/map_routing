import 'dart:convert';
import 'dart:io';

import 'package:map_routing/data/models/chat.dart';
import 'package:map_routing/data/models/friend.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CommunityListSnapshot {
  const CommunityListSnapshot({
    required this.chats,
    required this.friends,
    required this.friendRequests,
    required this.unreadFriendRequestCount,
    required this.unreadGroupInvitationCount,
  });

  final List<Chat> chats;
  final List<Friend> friends;
  final List<Map<String, dynamic>> friendRequests;
  final int unreadFriendRequestCount;
  final int unreadGroupInvitationCount;
}

class CommunityListCache {
  CommunityListCache._();

  static final CommunityListCache instance = CommunityListCache._();

  static const _cacheRootName = 'community_list';

  Future<Directory?> _cacheRoot() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, _cacheRootName));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  File? _cacheFile(Directory root, String userId) {
    final safeUserId = userId.replaceAll(RegExp(r'[^\w\-]'), '_');
    return File(p.join(root.path, safeUserId, 'community.json'));
  }

  Future<CommunityListSnapshot?> load({required String userId}) async {
    final root = await _cacheRoot();
    if (root == null) return null;

    final file = _cacheFile(root, userId);
    if (file == null || !file.existsSync()) return null;

    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map<String, dynamic>) return null;

      final chatsRaw = raw['chats'];
      final friendsRaw = raw['friends'];
      final requestsRaw = raw['friendRequests'];

      return CommunityListSnapshot(
        chats: chatsRaw is List
            ? chatsRaw
                .whereType<Map>()
                .map((item) => Chat.fromJson(Map<String, dynamic>.from(item)))
                .toList()
            : const [],
        friends: friendsRaw is List
            ? friendsRaw
                .whereType<Map>()
                .map(
                  (item) => Friend(
                    id: item['id']?.toString() ?? '',
                    avatarUrl: item['avatar_url']?.toString(),
                    isOnline: item['isOnline'] == true,
                    name: item['name']?.toString() ?? 'Пользователь',
                  ),
                )
                .toList()
            : const [],
        friendRequests: requestsRaw is List
            ? requestsRaw
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : const [],
        unreadFriendRequestCount:
            (raw['unreadFriendRequestCount'] as num?)?.toInt() ?? 0,
        unreadGroupInvitationCount:
            (raw['unreadGroupInvitationCount'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save({
    required String userId,
    required List<Chat> chats,
    required List<Friend> friends,
    required List<Map<String, dynamic>> friendRequests,
    required int unreadFriendRequestCount,
    required int unreadGroupInvitationCount,
  }) async {
    final root = await _cacheRoot();
    if (root == null) return;

    final file = _cacheFile(root, userId);
    if (file == null) return;

    await file.parent.create(recursive: true);

    final payload = {
      'chats': chats.map((chat) => chat.toJson()).toList(),
      'friends': friends
          .map(
            (friend) => {
              'id': friend.id,
              'avatar_url': friend.avatarUrl,
              'isOnline': friend.isOnline,
              'name': friend.name,
            },
          )
          .toList(),
      'friendRequests': friendRequests
          .map((request) => Map<String, dynamic>.from(request))
          .toList(),
      'unreadFriendRequestCount': unreadFriendRequestCount,
      'unreadGroupInvitationCount': unreadGroupInvitationCount,
      'cachedAt': DateTime.now().toIso8601String(),
    };

    await file.writeAsString(jsonEncode(payload));
  }

  Future<void> clear({required String userId}) async {
    final root = await _cacheRoot();
    if (root == null) return;

    final file = _cacheFile(root, userId);
    if (file != null && file.existsSync()) {
      await file.delete();
    }
  }

  Future<void> removeChat({
    required String userId,
    required String chatId,
  }) async {
    final snapshot = await load(userId: userId);
    if (snapshot == null) return;

    final filtered =
        snapshot.chats.where((chat) => chat.id != chatId).toList();
    if (filtered.length == snapshot.chats.length) return;

    await save(
      userId: userId,
      chats: filtered,
      friends: snapshot.friends,
      friendRequests: snapshot.friendRequests,
      unreadFriendRequestCount: snapshot.unreadFriendRequestCount,
      unreadGroupInvitationCount: snapshot.unreadGroupInvitationCount,
    );
  }

  Future<void> addChat({
    required String userId,
    required Chat chat,
  }) async {
    final snapshot = await load(userId: userId);
    if (snapshot != null && snapshot.chats.any((item) => item.id == chat.id)) {
      return;
    }

    final chats = snapshot != null
        ? [chat, ...snapshot.chats.where((item) => item.id != chat.id)]
        : [chat];
    final unreadInvites = snapshot?.unreadGroupInvitationCount ?? 0;
    final invitationCount =
        chat.isInvitationUnread ? unreadInvites + 1 : unreadInvites;

    await save(
      userId: userId,
      chats: chats,
      friends: snapshot?.friends ?? const [],
      friendRequests: snapshot?.friendRequests ?? const [],
      unreadFriendRequestCount: snapshot?.unreadFriendRequestCount ?? 0,
      unreadGroupInvitationCount: invitationCount,
    );
  }
}
