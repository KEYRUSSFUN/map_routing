import 'package:flutter/material.dart';
import 'package:map_routing/features/home/presentation/home_models.dart';
import 'package:map_routing/features/home/presentation/home_ui.dart';

/// Горизонтальная лента историй (Stories) пользователей и клубов.
///
/// Первая ячейка — кнопка «Создать историю» (аватар + плюс).
/// Непросмотренные истории обведены зелёным кольцом; после тапа кольцо исчезает.
class HomeStoriesRow extends StatelessWidget {
  const HomeStoriesRow({
    super.key,
    required this.stories,
    required this.viewedStoryIds,
    required this.onStoryTap,
    required this.onCreateStoryTap,
  });

  final List<HomeStory> stories;

  /// Множество id просмотренных историй — хранится в состоянии [HomePage].
  final Set<String> viewedStoryIds;
  final ValueChanged<HomeStory> onStoryTap;
  final VoidCallback onCreateStoryTap;

  static const _avatarSize = 64.0;
  static const _ringWidth = 2.5;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final story = stories[index];
          final isViewed =
              story.isCreateButton || viewedStoryIds.contains(story.id);

          return _StoryBubble(
            story: story,
            isViewed: isViewed,
            onTap: () {
              if (story.isCreateButton) {
                onCreateStoryTap();
              } else {
                onStoryTap(story);
              }
            },
          );
        },
      ),
    );
  }
}

class _StoryBubble extends StatelessWidget {
  const _StoryBubble({
    required this.story,
    required this.isViewed,
    required this.onTap,
  });

  final HomeStory story;
  final bool isViewed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Цвет кольца: зелёный для новых, серый для просмотренных.
    final ringColor =
        isViewed ? HomeColors.storyRingViewed : HomeColors.storyRing;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Внешнее кольцо истории.
                Container(
                  width: HomeStoriesRow._avatarSize + 6,
                  height: HomeStoriesRow._avatarSize + 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ringColor,
                      width: HomeStoriesRow._ringWidth,
                    ),
                  ),
                  child: Center(
                    child: _StoryAvatar(story: story),
                  ),
                ),
                // Значок «+» только на кнопке создания истории.
                if (story.isCreateButton)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: HomeColors.primaryGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 14,
                        color: Color(0xFF030303),
                      ),
                    ),
                  ),
                // Метка клуба — маленькая иконка группы.
                if (story.kind == HomeStoryKind.club && !story.isCreateButton)
                  Positioned(
                    right: -2,
                    bottom: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: HomeColors.title,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.groups_rounded,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              story.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: homeStoryNameStyle(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Круглый аватар-заглушка с инициалами (пока нет загрузки фото с сервера).
class _StoryAvatar extends StatelessWidget {
  const _StoryAvatar({required this.story});

  final HomeStory story;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: HomeStoriesRow._avatarSize / 2 - 2,
      backgroundColor: story.avatarColor ?? HomeColors.primaryGreen,
      child: Text(
        story.avatarLabel ?? '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
    );
  }
}
