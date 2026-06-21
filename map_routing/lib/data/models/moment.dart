class MomentItem {
  const MomentItem({
    required this.id,
    required this.userId,
    required this.userName,
    required this.createdAt,
    required this.likesCount,
    required this.commentsCount,
    required this.likedByMe,
    required this.isMe,
    this.avatarUrl,
    this.text,
    this.photoUrl,
    this.clubId,
    this.clubTitle,
    this.clubAvatarUrl,
    this.isClubPost = false,
  });

  final int id;
  final int userId;
  final String userName;
  final String? avatarUrl;
  final String? text;
  final String? photoUrl;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;
  final bool likedByMe;
  final bool isMe;
  final int? clubId;
  final String? clubTitle;
  final String? clubAvatarUrl;
  final bool isClubPost;

  MomentItem copyWith({
    int? likesCount,
    int? commentsCount,
    bool? likedByMe,
    String? text,
    String? photoUrl,
    bool clearPhoto = false,
  }) {
    return MomentItem(
      id: id,
      userId: userId,
      userName: userName,
      avatarUrl: avatarUrl,
      text: text ?? this.text,
      photoUrl: clearPhoto ? null : (photoUrl ?? this.photoUrl),
      createdAt: createdAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      likedByMe: likedByMe ?? this.likedByMe,
      isMe: isMe,
      clubId: clubId,
      clubTitle: clubTitle,
      clubAvatarUrl: clubAvatarUrl,
      isClubPost: isClubPost,
    );
  }

  factory MomentItem.fromJson(Map<String, dynamic> json) {
    return MomentItem(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      userName: json['user_name']?.toString() ?? 'Пользователь',
      avatarUrl: json['avatar_url']?.toString(),
      text: json['text']?.toString(),
      photoUrl: json['photo_url']?.toString(),
      createdAt: DateTime.parse(json['created_at'].toString()),
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      likedByMe: json['liked_by_me'] == true,
      isMe: json['is_me'] == true,
      clubId: (json['club_id'] as num?)?.toInt(),
      clubTitle: json['club_title']?.toString(),
      clubAvatarUrl: json['club_avatar_url']?.toString(),
      isClubPost: json['is_club_post'] == true || json['club_id'] != null,
    );
  }
}

class MomentCommentItem {
  const MomentCommentItem({
    required this.id,
    required this.userId,
    required this.userName,
    required this.text,
    required this.createdAt,
    required this.isMe,
    this.avatarUrl,
  });

  final int id;
  final int userId;
  final String userName;
  final String? avatarUrl;
  final String text;
  final DateTime createdAt;
  final bool isMe;

  factory MomentCommentItem.fromJson(Map<String, dynamic> json) {
    return MomentCommentItem(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      userName: json['user_name']?.toString() ?? 'Пользователь',
      avatarUrl: json['avatar_url']?.toString(),
      text: json['text']?.toString() ?? '',
      createdAt: DateTime.parse(json['created_at'].toString()),
      isMe: json['is_me'] == true,
    );
  }
}

class MomentFeedPage {
  const MomentFeedPage({
    required this.moments,
    required this.page,
    required this.hasMore,
  });

  final List<MomentItem> moments;
  final int page;
  final bool hasMore;

  factory MomentFeedPage.fromJson(Map<String, dynamic> json) {
    final items = json['moments'];
    return MomentFeedPage(
      moments: items is List
          ? items
              .map(
                (item) => MomentItem.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList()
          : const [],
      page: (json['page'] as num?)?.toInt() ?? 1,
      hasMore: json['has_more'] == true,
    );
  }
}
