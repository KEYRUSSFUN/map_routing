import 'package:flutter/material.dart';

/// Тип истории в горизонтальной ленте: пользователь или клуб/сообщество.
enum HomeStoryKind { user, club }

/// Элемент ленты историй (Stories).
class HomeStory {
  const HomeStory({
    required this.id,
    required this.name,
    required this.kind,
    this.avatarLabel,
    this.avatarColor,
    this.isCreateButton = false,
    this.isViewed = false,
  });

  final String id;
  final String name;
  final HomeStoryKind kind;

  /// Буква/инициал внутри аватара, если нет фото.
  final String? avatarLabel;

  /// Цвет фона аватара-заглушки.
  final Color? avatarColor;

  /// Первая «история» — кнопка создания (аватар пользователя + плюс).
  final bool isCreateButton;

  /// Просмотренные истории теряют зелёную обводку.
  final bool isViewed;

  HomeStory copyWith({bool? isViewed}) => HomeStory(
        id: id,
        name: name,
        kind: kind,
        avatarLabel: avatarLabel,
        avatarColor: avatarColor,
        isCreateButton: isCreateButton,
        isViewed: isViewed ?? this.isViewed,
      );
}

/// Челендж: активный (пользователь уже участвует) или рекомендованный.
class HomeChallenge {
  const HomeChallenge({
    required this.id,
    required this.title,
    required this.participantsCount,
    required this.daysLeft,
    required this.progress,
    required this.isRecommended,
  });

  final String id;
  final String title;
  final int participantsCount;
  final int daysLeft;

  /// Прогресс от 0.0 до 1.0 для полоски внизу карточки.
  final double progress;

  /// Рекомендованные челенджи показываются в конце горизонтального списка.
  final bool isRecommended;

  HomeChallenge copyWith({
    bool? isRecommended,
    int? participantsCount,
    double? progress,
  }) =>
      HomeChallenge(
        id: id,
        title: title,
        participantsCount: participantsCount ?? this.participantsCount,
        daysLeft: daysLeft,
        progress: progress ?? this.progress,
        isRecommended: isRecommended ?? this.isRecommended,
      );
}

/// Тип записи в ленте «Недавняя активность».
enum HomeFeedPostKind {
  /// Моя опубликованная тренировка.
  ownWorkout,

  /// Публичная тренировка друга.
  friendWorkout,

  /// Пост из клуба / сообщества.
  clubPost,
}

/// Карточка активности в вертикальной ленте.
class HomeFeedPost {
  const HomeFeedPost({
    required this.id,
    required this.kind,
    required this.authorName,
    required this.timeAgo,
    required this.title,
    required this.distanceKm,
    required this.pace,
    required this.elevationM,
    required this.activityTypeLabel,
    required this.activityIcon,
    this.clubName,
    this.avatarLabel,
    this.avatarColor,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLiked = false,
  });

  final String id;
  final HomeFeedPostKind kind;
  final String authorName;
  final String timeAgo;
  final String title;
  final double distanceKm;
  final String pace;
  final double elevationM;
  final String activityTypeLabel;
  final IconData activityIcon;

  /// Для постов клуба — название сообщества.
  final String? clubName;
  final String? avatarLabel;
  final Color? avatarColor;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;

  HomeFeedPost copyWith({
    int? likesCount,
    int? commentsCount,
    bool? isLiked,
  }) =>
      HomeFeedPost(
        id: id,
        kind: kind,
        authorName: authorName,
        timeAgo: timeAgo,
        title: title,
        distanceKm: distanceKm,
        pace: pace,
        elevationM: elevationM,
        activityTypeLabel: activityTypeLabel,
        activityIcon: activityIcon,
        clubName: clubName,
        avatarLabel: avatarLabel,
        avatarColor: avatarColor,
        likesCount: likesCount ?? this.likesCount,
        commentsCount: commentsCount ?? this.commentsCount,
        isLiked: isLiked ?? this.isLiked,
      );
}
