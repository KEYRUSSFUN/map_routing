class StoryItem {
  const StoryItem({
    required this.id,
    required this.mediaUrl,
    required this.createdAt,
    required this.expiresAt,
    this.caption,
    this.isViewed = false,
  });

  final int id;
  final String mediaUrl;
  final String? caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isViewed;

  factory StoryItem.fromJson(Map<String, dynamic> json) {
    return StoryItem(
      id: (json['id'] as num).toInt(),
      mediaUrl: json['media_url']?.toString() ?? '',
      caption: json['caption']?.toString(),
      createdAt: DateTime.parse(json['created_at'].toString()),
      expiresAt: DateTime.parse(json['expires_at'].toString()),
      isViewed: json['is_viewed'] == true,
    );
  }
}

class StoryFeedUser {
  const StoryFeedUser({
    required this.userId,
    required this.name,
    required this.hasStory,
    required this.hasUnviewed,
    required this.isMe,
    required this.storyCount,
    this.avatarUrl,
    this.isOnline = false,
  });

  final int userId;
  final String name;
  final String? avatarUrl;
  final bool hasStory;
  final bool hasUnviewed;
  final bool isMe;
  final int storyCount;
  final bool isOnline;

  factory StoryFeedUser.fromJson(Map<String, dynamic> json) {
    return StoryFeedUser(
      userId: (json['user_id'] as num).toInt(),
      name: json['name']?.toString() ?? 'Пользователь',
      avatarUrl: json['avatar_url']?.toString(),
      hasStory: json['has_story'] == true,
      hasUnviewed: json['has_unviewed'] == true,
      isMe: json['is_me'] == true,
      storyCount: (json['story_count'] as num?)?.toInt() ?? 0,
      isOnline: json['is_online'] == true,
    );
  }
}

class StoryUserBundle {
  const StoryUserBundle({
    required this.userId,
    required this.name,
    required this.stories,
    this.avatarUrl,
  });

  final int userId;
  final String name;
  final String? avatarUrl;
  final List<StoryItem> stories;

  factory StoryUserBundle.fromJson(Map<String, dynamic> json) {
    return StoryUserBundle(
      userId: (json['user_id'] as num).toInt(),
      name: json['name']?.toString() ?? 'Пользователь',
      avatarUrl: json['avatar_url']?.toString(),
      stories: (json['stories'] as List<dynamic>? ?? const [])
          .map(
            (item) => StoryItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}
