import 'package:flutter/material.dart';
import 'package:map_routing/features/home/presentation/home_models.dart';
import 'package:map_routing/features/home/presentation/home_ui.dart';

/// Горизонтальный блок «Активные челенджи» + рекомендованные в конце.
class HomeChallengesRow extends StatelessWidget {
  const HomeChallengesRow({
    super.key,
    required this.challenges,
    required this.onSeeAllTap,
    required this.onChallengeTap,
    required this.onJoinChallenge,
  });

  final List<HomeChallenge> challenges;
  final VoidCallback onSeeAllTap;
  final ValueChanged<HomeChallenge> onChallengeTap;

  /// Принять участие в рекомендованном челендже.
  final ValueChanged<HomeChallenge> onJoinChallenge;

  @override
  Widget build(BuildContext context) {
    // Активные — в начале, рекомендованные — после разделителя.
    final active =
        challenges.where((c) => !c.isRecommended).toList(growable: false);
    final recommended =
        challenges.where((c) => c.isRecommended).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Text('Активные челенджи', style: homeSectionTitleStyle()),
              ),
              GestureDetector(
                onTap: onSeeAllTap,
                child: Text('Все', style: homeLinkStyle()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 168,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final challenge in active) ...[
                _ChallengeCard(
                  challenge: challenge,
                  onTap: () => onChallengeTap(challenge),
                ),
                const SizedBox(width: 12),
              ],
              if (recommended.isNotEmpty && active.isNotEmpty)
                const _RecommendedDivider(),
              for (final challenge in recommended) ...[
                _ChallengeCard(
                  challenge: challenge,
                  onTap: () => onChallengeTap(challenge),
                  onJoinTap: () => onJoinChallenge(challenge),
                ),
                const SizedBox(width: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RecommendedDivider extends StatelessWidget {
  const _RecommendedDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 1,
            height: 80,
            color: const Color(0xFFE0E0E0),
          ),
          const SizedBox(height: 6),
          RotatedBox(
            quarterTurns: 3,
            child: Text(
              'Для вас',
              style: homeChallengeMetaStyle().copyWith(
                color: HomeColors.body,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.challenge,
    required this.onTap,
    this.onJoinTap,
  });

  final HomeChallenge challenge;
  final VoidCallback onTap;

  /// Только для рекомендованных — кнопка «Участвовать».
  final VoidCallback? onJoinTap;

  @override
  Widget build(BuildContext context) {
    final isRecommended = challenge.isRecommended;

    return SizedBox(
      width: 220,
      height: 168,
      child: Material(
        color: HomeColors.challengeBg,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isRecommended ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: isRecommended
                  ? Border.all(
                      color: HomeColors.primaryGreen.withValues(alpha: 0.5),
                      width: 1,
                    )
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: HomeColors.primaryGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isRecommended
                            ? Icons.auto_awesome_rounded
                            : Icons.emoji_events_outlined,
                        color: HomeColors.primaryGreen,
                        size: 18,
                      ),
                    ),
                    const Spacer(),
                    if (isRecommended)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: HomeColors.primaryGreen.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Новый',
                          style: homeChallengeMetaStyle().copyWith(
                            color: HomeColors.primaryGreen,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  challenge.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: homeChallengeTitleStyle().copyWith(height: 1.2),
                ),
                const SizedBox(height: 4),
                Text(
                  '${challenge.participantsCount} участников',
                  style: homeChallengeMetaStyle(),
                ),
                const Spacer(),
                if (isRecommended && onJoinTap != null)
                  // Кнопка участия — после нажатия челендж станет активным.
                  SizedBox(
                    width: double.infinity,
                    height: 34,
                    child: TextButton.icon(
                      onPressed: onJoinTap,
                      style: TextButton.styleFrom(
                        backgroundColor: HomeColors.primaryGreen,
                        foregroundColor: const Color(0xFF030303),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(
                        'Участвовать',
                        style: homeChallengeMetaStyle().copyWith(
                          color: const Color(0xFF030303),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                else ...[
                  Text(
                    '${challenge.daysLeft} дн. осталось',
                    style: homeChallengeMetaStyle().copyWith(
                      color: HomeColors.challengeAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: challenge.progress.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: const Color(0xFF333333),
                      color: HomeColors.primaryGreen,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
