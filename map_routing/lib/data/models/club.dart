import 'dart:convert';

class ClubSummary {
  const ClubSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.sportType,
    required this.clubType,
    required this.privacy,
    required this.locationScope,
    this.locationLabel,
    this.profileLink,
    this.avatarUrl,
    this.coverUrl,
    this.groupChatId,
    required this.memberCount,
    required this.pendingCount,
    required this.isAdmin,
    required this.isOwner,
    required this.isMember,
    required this.canPost,
    required this.showActivityFeed,
    required this.showLeaderboards,
    required this.adminsOnlyPosting,
    this.membershipStatus,
    this.membershipRole,
    this.notificationLevel,
  });

  final int id;
  final String title;
  final String description;
  final String sportType;
  final String clubType;
  final String privacy;
  final String locationScope;
  final String? locationLabel;
  final String? profileLink;
  final String? avatarUrl;
  final String? coverUrl;
  final int? groupChatId;
  final int memberCount;
  final int pendingCount;
  final bool isAdmin;
  final bool isOwner;
  final bool isMember;
  final bool canPost;
  final bool showActivityFeed;
  final bool showLeaderboards;
  final bool adminsOnlyPosting;
  final String? membershipStatus;
  final String? membershipRole;
  final String? notificationLevel;

  bool get isOpen => privacy == 'open';
  bool get isClosed => privacy == 'closed';
  bool get membershipPending => membershipStatus == 'pending';

  factory ClubSummary.fromJson(Map<String, dynamic> json) {
    return ClubSummary(
      id: json['id'] as int,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      sportType: json['sportType']?.toString() ?? 'all_sports',
      clubType: json['clubType']?.toString() ?? 'casual',
      privacy: json['privacy']?.toString() ?? 'open',
      locationScope: json['locationScope']?.toString() ?? 'worldwide',
      locationLabel: json['locationLabel']?.toString(),
      profileLink: json['profileLink']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      coverUrl: json['coverUrl']?.toString(),
      groupChatId: (json['groupChatId'] as num?)?.toInt(),
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      pendingCount: (json['pendingCount'] as num?)?.toInt() ?? 0,
      isAdmin: json['isAdmin'] == true,
      isOwner: json['isOwner'] == true,
      isMember: json['isMember'] == true,
      canPost: json['canPost'] == true,
      showActivityFeed: json['showActivityFeed'] != false,
      showLeaderboards: json['showLeaderboards'] != false,
      adminsOnlyPosting: json['adminsOnlyPosting'] == true,
      membershipStatus: json['membershipStatus']?.toString(),
      membershipRole: json['membershipRole']?.toString(),
      notificationLevel: json['notificationLevel']?.toString(),
    );
  }
}

class ClubMemberItem {
  const ClubMemberItem({
    required this.userId,
    required this.name,
    required this.role,
    required this.isMe,
    this.avatarUrl,
    this.location,
  });

  final int userId;
  final String name;
  final String role;
  final bool isMe;
  final String? avatarUrl;
  final String? location;

  factory ClubMemberItem.fromJson(Map<String, dynamic> json) {
    return ClubMemberItem(
      userId: (json['userId'] as num).toInt(),
      name: json['name']?.toString() ?? 'Участник',
      role: json['role']?.toString() ?? 'member',
      isMe: json['isMe'] == true,
      avatarUrl: json['avatarUrl']?.toString(),
      location: json['location']?.toString(),
    );
  }

  String get roleLabel => switch (role) {
        'owner' => 'ВЛАДЕЛЕЦ',
        'admin' => 'АДМИНИСТРАТОР',
        _ => '',
      };
}

class ClubLeaderboardEntry {
  const ClubLeaderboardEntry({
    required this.userId,
    required this.name,
    required this.distanceKm,
    required this.elevationM,
    this.avatarUrl,
  });

  final int userId;
  final String name;
  final double distanceKm;
  final double elevationM;
  final String? avatarUrl;

  factory ClubLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return ClubLeaderboardEntry(
      userId: (json['userId'] as num).toInt(),
      name: json['name']?.toString() ?? 'Участник',
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      elevationM: (json['elevationM'] as num?)?.toDouble() ?? 0,
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }
}

class ClubWeeklyStats {
  const ClubWeeklyStats({
    required this.totalDistanceKm,
    required this.workoutsCount,
    required this.topDistanceKm,
    required this.topElevationM,
    required this.myDistanceKm,
    required this.myElevationM,
    required this.leaderboard,
  });

  final double totalDistanceKm;
  final int workoutsCount;
  final double topDistanceKm;
  final double topElevationM;
  final double myDistanceKm;
  final double myElevationM;
  final List<ClubLeaderboardEntry> leaderboard;

  factory ClubWeeklyStats.fromJson(Map<String, dynamic> json) {
    final raw = json['leaderboard'];
    return ClubWeeklyStats(
      totalDistanceKm: (json['totalDistanceKm'] as num?)?.toDouble() ?? 0,
      workoutsCount: (json['workoutsCount'] as num?)?.toInt() ?? 0,
      topDistanceKm: (json['topDistanceKm'] as num?)?.toDouble() ?? 0,
      topElevationM: (json['topElevationM'] as num?)?.toDouble() ?? 0,
      myDistanceKm: (json['myDistanceKm'] as num?)?.toDouble() ?? 0,
      myElevationM: (json['myElevationM'] as num?)?.toDouble() ?? 0,
      leaderboard: raw is List
          ? raw
              .whereType<Map>()
              .map(
                (item) => ClubLeaderboardEntry.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const [],
    );
  }
}

class CreateClubPayload {
  const CreateClubPayload({
    required this.title,
    required this.sportType,
    required this.privacy,
    this.description,
    this.locationLabel,
  });

  final String title;
  final String sportType;
  final String privacy;
  final String? description;
  final String? locationLabel;

  Map<String, String> toFields() => {
        'title': title,
        'sport_type': sportType,
        'privacy': privacy,
        if (description != null && description!.isNotEmpty) 'description': description!,
        if (locationLabel != null && locationLabel!.isNotEmpty)
          'location_label': locationLabel!,
      };
}

class UpdateClubPayload {
  const UpdateClubPayload({
    required this.title,
    required this.sportType,
    this.description,
    this.locationLabel,
  });

  final String title;
  final String sportType;
  final String? description;
  final String? locationLabel;

  Map<String, String> toFields() => {
        'title': title,
        'sport_type': sportType,
        if (description != null) 'description': description!,
        'location_label': locationLabel ?? '',
      };
}

class ClubMemberWorkout {
  const ClubMemberWorkout({
    required this.routeId,
    required this.userId,
    required this.userName,
    this.avatarUrl,
    this.title,
    this.activityType,
    this.description,
    this.tags = const [],
    this.effortLevel,
    this.privacy,
    this.distanceKm,
    this.durationSeconds,
    this.calories,
    this.elevationGainM,
    this.avgSpeedKmh,
    this.startedAt,
    this.photoUrl,
    this.path,
  });

  final int routeId;
  final int userId;
  final String userName;
  final String? avatarUrl;
  final String? title;
  final String? activityType;
  final String? description;
  final List<String> tags;
  final int? effortLevel;
  final String? privacy;
  final double? distanceKm;
  final int? durationSeconds;
  final int? calories;
  final double? elevationGainM;
  final double? avgSpeedKmh;
  final DateTime? startedAt;
  final String? photoUrl;
  final Map<String, dynamic>? path;

  factory ClubMemberWorkout.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? value) {
      if (value == null || value.isEmpty) return null;
      return DateTime.tryParse(value)?.toLocal();
    }

    final rawPath = json['path'];
    Map<String, dynamic>? pathMap;
    if (rawPath is Map) {
      pathMap = Map<String, dynamic>.from(rawPath);
    } else if (rawPath is String && rawPath.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPath);
        if (decoded is Map) {
          pathMap = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    final rawTags = json['tags'];
    final tags = rawTags is List
        ? rawTags.map((item) => item.toString()).toList()
        : const <String>[];

    return ClubMemberWorkout(
      routeId: (json['id_Route'] as num?)?.toInt() ?? 0,
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      userName: json['userName']?.toString() ?? 'Участник',
      avatarUrl: json['avatarUrl']?.toString(),
      title: json['title']?.toString(),
      activityType: json['activity_type']?.toString(),
      description: json['description']?.toString(),
      tags: tags,
      effortLevel: (json['effort_level'] as num?)?.toInt(),
      privacy: json['privacy']?.toString(),
      distanceKm: (json['distance'] as num?)?.toDouble(),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      calories: (json['calories'] as num?)?.toInt(),
      elevationGainM: (json['elevation_gain_m'] as num?)?.toDouble(),
      avgSpeedKmh: (json['avg_speed_kmh'] as num?)?.toDouble(),
      startedAt: parseDate(json['started_at']?.toString()) ??
          parseDate(json['creation_date']?.toString()),
      photoUrl: json['photo_url']?.toString(),
      path: pathMap,
    );
  }
}

class ClubSettingsPayload {
  const ClubSettingsPayload({
    this.showActivityFeed,
    this.showLeaderboards,
    this.adminsOnlyPosting,
    this.privacy,
    this.notificationLevel,
  });

  final bool? showActivityFeed;
  final bool? showLeaderboards;
  final bool? adminsOnlyPosting;
  final String? privacy;
  final String? notificationLevel;

  Map<String, dynamic> toJson() => {
        if (showActivityFeed != null) 'showActivityFeed': showActivityFeed,
        if (showLeaderboards != null) 'showLeaderboards': showLeaderboards,
        if (adminsOnlyPosting != null) 'adminsOnlyPosting': adminsOnlyPosting,
        if (privacy != null) 'privacy': privacy,
        if (notificationLevel != null) 'notificationLevel': notificationLevel,
      };
}
