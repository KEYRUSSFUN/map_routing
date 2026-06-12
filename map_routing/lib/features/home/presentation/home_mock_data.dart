import 'package:flutter/material.dart';
import 'package:map_routing/features/home/presentation/home_models.dart';

/// Заглушки данных для домашней ленты.
/// После подключения бэкенда заменить на вызовы API.
abstract final class HomeMockData {
  /// Истории пользователей и клубов.
  static List<HomeStory> stories() => const [
        HomeStory(
          id: 'create',
          name: 'Вы',
          kind: HomeStoryKind.user,
          avatarLabel: 'Я',
          avatarColor: Color(0xFF4CAF50),
          isCreateButton: true,
        ),
        HomeStory(
          id: 'story_marcus',
          name: 'Марк',
          kind: HomeStoryKind.user,
          avatarLabel: 'М',
          avatarColor: Color(0xFF5C6BC0),
        ),
        HomeStory(
          id: 'story_sarah',
          name: 'Сара',
          kind: HomeStoryKind.user,
          avatarLabel: 'С',
          avatarColor: Color(0xFFEC407A),
        ),
        HomeStory(
          id: 'story_leo',
          name: 'Лео',
          kind: HomeStoryKind.user,
          avatarLabel: 'Л',
          avatarColor: Color(0xFF26A69A),
        ),
        HomeStory(
          id: 'story_club_runners',
          name: 'Бегуны МСК',
          kind: HomeStoryKind.club,
          avatarLabel: 'Б',
          avatarColor: Color(0xFF212121),
        ),
        HomeStory(
          id: 'story_club_trail',
          name: 'Трейл-клуб',
          kind: HomeStoryKind.club,
          avatarLabel: 'Т',
          avatarColor: Color(0xFF795548),
        ),
      ];

  /// Активные челенджи + рекомендованные в конце списка.
  static List<HomeChallenge> challenges() =>
      List<HomeChallenge>.from(_challengesData);

  static const _challengesData = [
        HomeChallenge(
          id: 'ch_1',
          title: '100 км за месяц',
          participantsCount: 128,
          daysLeft: 12,
          progress: 0.62,
          isRecommended: false,
        ),
        HomeChallenge(
          id: 'ch_2',
          title: '5 тренировок за неделю',
          participantsCount: 54,
          daysLeft: 3,
          progress: 0.8,
          isRecommended: false,
        ),
        HomeChallenge(
          id: 'ch_3',
          title: 'Набор 2000 м',
          participantsCount: 31,
          daysLeft: 18,
          progress: 0.35,
          isRecommended: false,
        ),
        // Рекомендованные — пользователь ещё не участвует.
        HomeChallenge(
          id: 'ch_rec_1',
          title: 'Утренний старт',
          participantsCount: 89,
          daysLeft: 7,
          progress: 0,
          isRecommended: true,
        ),
        HomeChallenge(
          id: 'ch_rec_2',
          title: '10 000 шагов ежедневно',
          participantsCount: 210,
          daysLeft: 14,
          progress: 0,
          isRecommended: true,
        ),
      ];

  /// Смешанная лента: свои тренировки, друзья, посты клубов.
  /// Возвращает изменяемую копию — иначе лайки/комментарии упадут с UnsupportedError.
  static List<HomeFeedPost> feedPosts() =>
      List<HomeFeedPost>.from(_feedPostsData);

  static const _feedPostsData = [
        HomeFeedPost(
          id: 'post_own_1',
          kind: HomeFeedPostKind.ownWorkout,
          authorName: 'Вы',
          timeAgo: '2 часа назад',
          title: 'Утренний забег по набережной',
          distanceKm: 8.4,
          pace: '5:12 /км',
          elevationM: 42,
          activityTypeLabel: 'Бег',
          activityIcon: Icons.directions_run,
          avatarLabel: 'Я',
          avatarColor: Color(0xFF4CAF50),
          likesCount: 12,
          commentsCount: 3,
        ),
        HomeFeedPost(
          id: 'post_friend_1',
          kind: HomeFeedPostKind.friendWorkout,
          authorName: 'Марк',
          timeAgo: '5 часов назад',
          title: 'Интервалы на стадионе',
          distanceKm: 6.2,
          pace: '4:48 /км',
          elevationM: 18,
          activityTypeLabel: 'Бег',
          activityIcon: Icons.directions_run,
          avatarLabel: 'М',
          avatarColor: Color(0xFF5C6BC0),
          likesCount: 24,
          commentsCount: 7,
        ),
        HomeFeedPost(
          id: 'post_club_1',
          kind: HomeFeedPostKind.clubPost,
          authorName: 'Анна',
          clubName: 'Бегуны МСК',
          timeAgo: 'вчера',
          title: 'Совместная пробежка в парке Сокольники',
          distanceKm: 10.0,
          pace: '5:30 /км',
          elevationM: 65,
          activityTypeLabel: 'Бег',
          activityIcon: Icons.directions_run,
          avatarLabel: 'А',
          avatarColor: Color(0xFF212121),
          likesCount: 45,
          commentsCount: 11,
        ),
        HomeFeedPost(
          id: 'post_friend_2',
          kind: HomeFeedPostKind.friendWorkout,
          authorName: 'Сара',
          timeAgo: 'вчера',
          title: 'Велопрогулка выходного дня',
          distanceKm: 32.5,
          pace: '18.2 км/ч',
          elevationM: 120,
          activityTypeLabel: 'Велосипед',
          activityIcon: Icons.directions_bike,
          avatarLabel: 'С',
          avatarColor: Color(0xFFEC407A),
          likesCount: 18,
          commentsCount: 2,
        ),
        HomeFeedPost(
          id: 'post_club_2',
          kind: HomeFeedPostKind.clubPost,
          authorName: 'Трейл-клуб',
          clubName: 'Трейл-клуб',
          timeAgo: '2 дня назад',
          title: 'Горный маршрут: отчёт с тренировки',
          distanceKm: 15.8,
          pace: '6:45 /км',
          elevationM: 480,
          activityTypeLabel: 'Трейлран',
          activityIcon: Icons.terrain,
          avatarLabel: 'Т',
          avatarColor: Color(0xFF795548),
          likesCount: 67,
          commentsCount: 19,
        ),
      ];
}
