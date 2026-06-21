import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/data/models/achievement.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:map_routing/features/profile/presentation/profile_ui.dart';

class AchievementDetailsSheet extends StatelessWidget {
  const AchievementDetailsSheet({
    super.key,
    required this.status,
  });

  final AchievementStatus status;

  static Future<void> show(
    BuildContext context, {
    required AchievementStatus status,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AchievementDetailsSheet(status: status),
    );
  }

  String _formatUnlockDate(DateTime? date) {
    if (date == null) return '—';
    const months = [
      'янв',
      'фев',
      'мар',
      'апр',
      'мая',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек',
    ];
    return '${date.day} ${months[date.month - 1]}. ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = status.unlocked;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Достижение',
                        style: GoogleFonts.lexendDeca(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AuthColors.title,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      color: AuthColors.title,
                    ),
                  ],
                ),
              ),
              AchievementMedallion(
                icon: status.definition.icon,
                locked: !unlocked,
                size: 88,
              ),
              const SizedBox(height: 16),
              Text(
                status.definition.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.lexendDeca(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: ProfileColors.title,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: unlocked
                      ? ProfileColors.tabActive
                      : const Color(0xFFF3F3F3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  unlocked ? 'Получено' : 'Не разблокировано',
                  style: GoogleFonts.lexendDeca(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: unlocked ? ProfileColors.orange : ProfileColors.body,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Material(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        status.definition.description,
                        style: GoogleFonts.lexendDeca(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: ProfileColors.title,
                          height: 1.45,
                        ),
                      ),
                      if (unlocked) ...[
                        const SizedBox(height: 14),
                        const Divider(height: 1, color: Color(0xFFE8E8E8)),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Icon(
                              Icons.event_available_outlined,
                              size: 20,
                              color: ProfileColors.orange,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Дата получения',
                                    style: profileSubtitleStyle(),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatUnlockDate(status.unlockedAt),
                                    style: GoogleFonts.lexendDeca(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: ProfileColors.title,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AuthPrimaryButton(
                label: 'Закрыть',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
