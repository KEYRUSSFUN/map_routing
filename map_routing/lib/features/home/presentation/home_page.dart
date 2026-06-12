import 'package:flutter/material.dart';
import 'package:map_routing/core/widgets/app_bottom_nav_bar.dart';
import 'package:map_routing/core/widgets/stride_track_logo.dart';
import 'package:map_routing/features/home/presentation/home_mock_data.dart';
import 'package:map_routing/features/home/presentation/home_models.dart';
import 'package:map_routing/features/home/presentation/home_ui.dart';
import 'package:map_routing/features/home/presentation/widgets/home_challenges_row.dart';
import 'package:map_routing/features/home/presentation/widgets/home_feed_card.dart';
import 'package:map_routing/features/home/presentation/widgets/home_stories_row.dart';

/// Главная страница StrideTrack — лента активности пользователя.
///
/// Секции (сверху вниз):
/// 1. Логотип приложения
/// 2. Истории (Stories) пользователей и клубов
/// 3. Активные и рекомендованные челенджи
/// 4. Недавняя активность: свои тренировки, друзья, посты клубов
///
/// Данные пока загружаются из [HomeMockData].
/// Лайки, комментарии и «Поделиться» работают локально в состоянии виджета.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// id просмотренных историй — у них пропадает зелёная обводка.
  final Set<String> _viewedStoryIds = {};

  /// Лента постов с локально изменяемыми лайками и счётчиками комментариев.
  late List<HomeFeedPost> _feedPosts;

  /// Челенджи: при «Участвовать» рекомендованный переходит в активные.
  late List<HomeChallenge> _challenges;

  @override
  void initState() {
    super.initState();
    _feedPosts = HomeMockData.feedPosts();
    _challenges = HomeMockData.challenges();
  }

  // ─── Обработчики историй ───────────────────────────────────────────────

  /// Открытие истории: помечаем как просмотренную и показываем заглушку.
  void _onStoryTap(HomeStory story) {
    setState(() => _viewedStoryIds.add(story.id));
    _showPlaceholderSnackBar(
      story.kind == HomeStoryKind.club
          ? 'История клуба «${story.name}» (скоро)'
          : 'История «${story.name}» (скоро)',
    );
  }

  /// Кнопка «Создать историю» — первая ячейка с плюсом.
  void _onCreateStoryTap() {
    _showPlaceholderSnackBar('Создание истории скоро будет доступно');
  }

  // ─── Обработчики челенджей ─────────────────────────────────────────────

  void _onSeeAllChallenges() {
    _showPlaceholderSnackBar('Список всех челенджей (скоро)');
  }

  void _onChallengeTap(HomeChallenge challenge) {
    if (challenge.isRecommended) return;
    _showPlaceholderSnackBar('Челендж «${challenge.title}» (скоро)');
  }

  /// Принять участие в рекомендованном челендже — перенос в активные.
  void _onJoinChallenge(HomeChallenge challenge) {
    final index = _challenges.indexWhere((c) => c.id == challenge.id);
    if (index < 0) return;

    setState(() {
      _challenges[index] = challenge.copyWith(
        isRecommended: false,
        participantsCount: challenge.participantsCount + 1,
        progress: 0,
      );
    });

    _showPlaceholderSnackBar('Вы участвуете в «${challenge.title}»');
  }

  // ─── Обработчики ленты активности ──────────────────────────────────────

  /// Переключение лайка: меняем флаг и счётчик только в локальном состоянии.
  void _onLikeTap(int index) {
    setState(() {
      final post = _feedPosts[index];
      final liked = !post.isLiked;
      _feedPosts[index] = post.copyWith(
        isLiked: liked,
        likesCount: (post.likesCount + (liked ? 1 : -1)).clamp(0, 999999),
      );
    });
  }

  /// Открытие листа комментариев; новый комментарий увеличивает счётчик.
  void _onCommentTap(int index) {
    final post = _feedPosts[index];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, __) => HomeCommentsSheet(
          postTitle: post.title,
          initialCommentsCount: post.commentsCount,
          onCommentAdded: () {
            setState(() {
              _feedPosts[index] = post.copyWith(
                commentsCount: post.commentsCount + 1,
              );
            });
          },
        ),
      ),
    );
  }

  void _onShareTap(HomeFeedPost post) {
    showHomeShareSheet(context, post);
  }

  void _onMenuTap(HomeFeedPost post) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bookmark_border),
              title: const Text('Сохранить'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Пожаловаться'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('Скрыть'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaceholderSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Отступ снизу, чтобы контент не перекрывался нижней навигацией.
    final bottomPadding = AppBottomNavBar.scrollEndPadding(context);

    return Scaffold(
      backgroundColor: HomeColors.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // ── Шапка с логотипом ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: const StrideTrackLogo(size: 28),
              ),
            ),

            // ── Лента историй ──
            SliverToBoxAdapter(
              child: HomeStoriesRow(
                stories: HomeMockData.stories(),
                viewedStoryIds: _viewedStoryIds,
                onStoryTap: _onStoryTap,
                onCreateStoryTap: _onCreateStoryTap,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // ── Челенджи (активные + рекомендованные) ──
            SliverToBoxAdapter(
              child: HomeChallengesRow(
                challenges: _challenges,
                onSeeAllTap: _onSeeAllChallenges,
                onChallengeTap: _onChallengeTap,
                onJoinChallenge: _onJoinChallenge,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Заголовок ленты активности ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Недавняя активность',
                  style: homeSectionTitleStyle(),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── Карточки ленты ──
            SliverList.separated(
              itemCount: _feedPosts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final post = _feedPosts[index];
                return HomeFeedCard(
                  post: post,
                  onLikeTap: () => _onLikeTap(index),
                  onCommentTap: () => _onCommentTap(index),
                  onShareTap: () => _onShareTap(post),
                  onMenuTap: () => _onMenuTap(post),
                );
              },
            ),

            // Нижний отступ под nav bar.
            SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
          ],
        ),
      ),
    );
  }
}
