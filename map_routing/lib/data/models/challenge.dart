import 'package:font_awesome_flutter/font_awesome_flutter.dart';

enum ChallengeMetricType {
  distance,
  steps;

  static ChallengeMetricType fromString(String? value) {
    switch (value) {
      case 'steps':
        return ChallengeMetricType.steps;
      default:
        return ChallengeMetricType.distance;
    }
  }

  String get labelRu {
    switch (this) {
      case ChallengeMetricType.distance:
        return 'км';
      case ChallengeMetricType.steps:
        return 'шагов';
    }
  }
}

class ChallengeSummary {
  const ChallengeSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.metricType,
    required this.targetValue,
    required this.startDate,
    required this.endDate,
    required this.iconKey,
    required this.participantsCount,
    required this.isJoined,
    required this.statusLabel,
    required this.daysRemaining,
    this.myProgress,
  });

  final int id;
  final String title;
  final String description;
  final ChallengeMetricType metricType;
  final double targetValue;
  final DateTime startDate;
  final DateTime endDate;
  final String iconKey;
  final int participantsCount;
  final bool isJoined;
  final String statusLabel;
  final int daysRemaining;
  final double? myProgress;

  factory ChallengeSummary.fromJson(Map<String, dynamic> json) {
    return ChallengeSummary(
      id: (json['id'] as num).toInt(),
      title: json['title']?.toString() ?? 'Челлендж',
      description: json['description']?.toString() ?? '',
      metricType: ChallengeMetricType.fromString(
        json['metric_type']?.toString(),
      ),
      targetValue: (json['target_value'] as num?)?.toDouble() ?? 0,
      startDate: DateTime.parse(json['start_date'].toString()),
      endDate: DateTime.parse(json['end_date'].toString()),
      iconKey: json['icon_key']?.toString() ?? 'running',
      participantsCount: (json['participants_count'] as num?)?.toInt() ?? 0,
      isJoined: json['is_joined'] == true,
      statusLabel: json['status_label']?.toString() ?? '',
      daysRemaining: (json['days_remaining'] as num?)?.toInt() ?? 0,
      myProgress: (json['my_progress'] as num?)?.toDouble(),
    );
  }

  FaIconData get icon {
    switch (iconKey) {
      case 'cycling':
        return FontAwesomeIcons.bicycle;
      case 'steps':
        return FontAwesomeIcons.shoePrints;
      default:
        return FontAwesomeIcons.personRunning;
    }
  }

  String get participantsLabel {
    final count = participantsCount;
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod100 >= 11 && mod100 <= 14) {
      return '$count участников';
    }
    if (mod10 == 1) return '$count участник';
    if (mod10 >= 2 && mod10 <= 4) return '$count участника';
    return '$count участников';
  }

  String formatProgress(double value) {
    if (metricType == ChallengeMetricType.steps) {
      return _formatInt(value);
    }
    if (value == value.roundToDouble()) {
      return '${value.toInt()} км';
    }
    return '${value.toStringAsFixed(1)} км';
  }

  String get targetLabel {
    if (metricType == ChallengeMetricType.steps) {
      return '${_formatInt(targetValue)} шагов';
    }
    if (targetValue == targetValue.roundToDouble()) {
      return '${targetValue.toInt()} км';
    }
    return '${targetValue.toStringAsFixed(1)} км';
  }

  double get progressPercent {
    if (targetValue <= 0 || myProgress == null) return 0;
    return (myProgress! / targetValue).clamp(0.0, 1.0);
  }

  String get daysLeftLabel {
    if (daysRemaining <= 0) return 'Завершён';
    return '$daysRemaining дн. осталось';
  }

  bool get isActive => daysRemaining > 0;

  static String _formatInt(double value) {
    final intValue = value.round();
    final text = intValue.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final posFromEnd = text.length - i;
      buffer.write(text[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) {
        buffer.write(' ');
      }
    }
    return buffer.toString();
  }
}

class ChallengeParticipantProgress {
  const ChallengeParticipantProgress({
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.progress,
    required this.rank,
  });

  final int userId;
  final String name;
  final String? avatarUrl;
  final double progress;
  final int rank;

  factory ChallengeParticipantProgress.fromJson(Map<String, dynamic> json) {
    return ChallengeParticipantProgress(
      userId: (json['user_id'] as num).toInt(),
      name: json['name']?.toString() ?? 'Пользователь',
      avatarUrl: json['avatar_url']?.toString(),
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
    );
  }
}

class ChallengeDetails extends ChallengeSummary {
  const ChallengeDetails({
    required super.id,
    required super.title,
    required super.description,
    required super.metricType,
    required super.targetValue,
    required super.startDate,
    required super.endDate,
    required super.iconKey,
    required super.participantsCount,
    required super.isJoined,
    required super.statusLabel,
    required super.daysRemaining,
    required super.myProgress,
    required this.topParticipants,
    required this.friendsProgress,
  });

  final List<ChallengeParticipantProgress> topParticipants;
  final List<ChallengeParticipantProgress> friendsProgress;

  factory ChallengeDetails.fromJson(Map<String, dynamic> json) {
    final summary = ChallengeSummary.fromJson(json);
    return ChallengeDetails(
      id: summary.id,
      title: summary.title,
      description: summary.description,
      metricType: summary.metricType,
      targetValue: summary.targetValue,
      startDate: summary.startDate,
      endDate: summary.endDate,
      iconKey: summary.iconKey,
      participantsCount: summary.participantsCount,
      isJoined: summary.isJoined,
      statusLabel: summary.statusLabel,
      daysRemaining: summary.daysRemaining,
      myProgress: summary.myProgress ?? 0,
      topParticipants: (json['top_participants'] as List<dynamic>? ?? const [])
          .map(
            (item) => ChallengeParticipantProgress.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      friendsProgress: (json['friends_progress'] as List<dynamic>? ?? const [])
          .map(
            (item) => ChallengeParticipantProgress.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }

  @override
  double get progressPercent {
    if (targetValue <= 0) return 0;
    return (myProgress! / targetValue).clamp(0.0, 1.0);
  }
}
