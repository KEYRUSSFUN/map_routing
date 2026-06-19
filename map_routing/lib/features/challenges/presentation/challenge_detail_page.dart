import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/navigation/open_user_profile.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:map_routing/core/widgets/user_avatar.dart';
import 'package:map_routing/data/models/challenge.dart';
import 'package:map_routing/data/services/challenge_service.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';

class ChallengeDetailPage extends StatefulWidget {
  const ChallengeDetailPage({
    super.key,
    required this.challengeId,
    required this.challengeService,
  });

  final int challengeId;
  final ChallengeService challengeService;

  @override
  State<ChallengeDetailPage> createState() => _ChallengeDetailPageState();
}

class _ChallengeDetailPageState extends State<ChallengeDetailPage> {
  ChallengeDetails? _details;
  bool _loading = true;
  bool _leaving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final details =
          await widget.challengeService.fetchChallengeDetails(widget.challengeId);
      if (!mounted) return;
      setState(() {
        _details = details;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
    ];
    return '${date.day} ${months[date.month - 1]}. ${date.year}';
  }

  Future<void> _confirmLeave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Выйти из челленджа?',
          style: GoogleFonts.lexendDeca(
            fontWeight: FontWeight.w700,
            color: AuthColors.title,
          ),
        ),
        content: Text(
          'Ваш прогресс сохранится в статистике, но вы перестанете участвовать в рейтинге.',
          style: authSubtitleStyle(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Отмена', style: authLinkStyle()),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Выйти',
              style: authLinkStyle().copyWith(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _leave();
    }
  }

  Future<void> _leave() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    try {
      await widget.challengeService.leaveChallenge(widget.challengeId);
      if (!mounted) return;
      AppSnackBar.show(context, 'Вы вышли из челленджа');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Ошибка: $e');
      setState(() => _leaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AuthColors.title,
        elevation: 0,
        title: Text(
          'Челлендж',
          style: GoogleFonts.lexendDeca(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AuthColors.title,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error.toString(), onRetry: _load)
              : _details == null
                  ? const SizedBox.shrink()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          _ChallengeHeader(
                            details: _details!,
                            formatDate: _formatDate,
                          ),
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: 'Топ-10 участников',
                            child: _details!.topParticipants.isEmpty
                                ? Text(
                                    'Пока нет результатов',
                                    style: authSubtitleStyle(),
                                  )
                                : Column(
                                    children: [
                                      for (final participant
                                          in _details!.topParticipants)
                                        _ParticipantRow(
                                          participant: participant,
                                          challenge: _details!,
                                        ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 12),
                          _SectionCard(
                            title: 'Прогресс друзей',
                            child: _details!.friendsProgress.isEmpty
                                ? Text(
                                    'Среди ваших друзей пока никто не участвует',
                                    style: authSubtitleStyle(),
                                  )
                                : Column(
                                    children: [
                                      for (final participant
                                          in _details!.friendsProgress)
                                        _ParticipantRow(
                                          participant: participant,
                                          challenge: _details!,
                                        ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _leaving ? null : _confirmLeave,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _leaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'Выйти из челленджа',
                                      style: GoogleFonts.lexendDeca(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

class _ChallengeHeader extends StatelessWidget {
  const _ChallengeHeader({
    required this.details,
    required this.formatDate,
  });

  final ChallengeDetails details;
  final String Function(DateTime date) formatDate;

  @override
  Widget build(BuildContext context) {
    final progress = details.myProgress ?? 0;
  final percent = details.progressPercent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E7E7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AuthColors.primaryGreen.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: FaIcon(details.icon, size: 22, color: AuthColors.title),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      details.title,
                      style: GoogleFonts.lexendDeca(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AuthColors.title,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(details.statusLabel, style: authSubtitleStyle()),
                  ],
                ),
              ),
            ],
          ),
          if (details.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(details.description, style: authSubtitleStyle()),
          ],
          const SizedBox(height: 12),
          Text(
            '${formatDate(details.startDate)} — ${formatDate(details.endDate)}',
            style: authSubtitleStyle().copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            details.participantsLabel,
            style: authSubtitleStyle().copyWith(
              color: AuthColors.primaryGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ваш прогресс',
                style: GoogleFonts.lexendDeca(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AuthColors.title,
                ),
              ),
              Text(
                '${details.formatProgress(progress)} / ${details.targetLabel}',
                style: authSubtitleStyle().copyWith(
                  fontWeight: FontWeight.w600,
                  color: AuthColors.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 10,
              backgroundColor: const Color(0xFFECECEC),
              color: AuthColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(percent * 100).round()}% выполнено',
            style: authSubtitleStyle(),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E7E7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.lexendDeca(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AuthColors.title,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.participant,
    required this.challenge,
  });

  final ChallengeParticipantProgress participant;
  final ChallengeDetails challenge;

  @override
  Widget build(BuildContext context) {
    final progressPercent = challenge.targetValue <= 0
        ? 0.0
        : (participant.progress / challenge.targetValue).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '#${participant.rank}',
                style: GoogleFonts.lexendDeca(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AuthColors.body,
                ),
              ),
            ),
            UserAvatar(
              name: participant.name,
              avatarUrl: participant.avatarUrl,
              radius: 20,
              onTap: () => openUserProfile(context, participant.userId),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    participant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lexendDeca(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AuthColors.title,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progressPercent,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFECECEC),
                      color: AuthColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              challenge.formatProgress(participant.progress),
              style: authSubtitleStyle().copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: authSubtitleStyle()),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AuthColors.primaryGreen,
              ),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
