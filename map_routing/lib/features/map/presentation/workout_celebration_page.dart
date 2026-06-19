import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/data/models/achievement.dart';
import 'package:map_routing/features/map/presentation/map_ui_styles.dart';
import 'package:map_routing/features/profile/presentation/profile_ui.dart';

class WorkoutCelebrationPage extends StatefulWidget {
  const WorkoutCelebrationPage({
    super.key,
    this.newAchievements = const [],
  });

  final List<AchievementStatus> newAchievements;

  static const phrases = [
    'Отличная работа!',
    'Ты молодец!',
    'Сильная тренировка!',
    'Так держать!',
    'Невероятный результат!',
    'Ты на высоте!',
  ];

  @override
  State<WorkoutCelebrationPage> createState() => _WorkoutCelebrationPageState();
}

class _WorkoutCelebrationPageState extends State<WorkoutCelebrationPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final String _phrase;
  bool _showPhrase = false;
  bool _showAchievements = false;

  @override
  void initState() {
    super.initState();
    _phrase = WorkoutCelebrationPage.phrases[
        math.Random().nextInt(WorkoutCelebrationPage.phrases.length)];
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..forward();

    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _showPhrase = true);
    });

    if (widget.newAchievements.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 2200), () {
        if (mounted) setState(() => _showAchievements = true);
      });
    }

    final closeDelay = widget.newAchievements.isEmpty
        ? const Duration(milliseconds: 3600)
        : const Duration(milliseconds: 5200);

    Future.delayed(closeDelay, () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 280,
                  height: 180,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _RunningLinePainter(progress: _controller.value),
                      );
                    },
                  ),
                ),
                AnimatedOpacity(
                  opacity: _showPhrase ? 1 : 0,
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    _phrase,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lexendDeca(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: MapUiColors.title,
                    ),
                  ),
                ),
                if (widget.newAchievements.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  AnimatedOpacity(
                    opacity: _showAchievements ? 1 : 0,
                    duration: const Duration(milliseconds: 500),
                    child: Column(
                      children: [
                        Text(
                          widget.newAchievements.length == 1
                              ? 'Новое достижение!'
                              : 'Новые достижения!',
                          style: GoogleFonts.lexendDeca(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: ProfileColors.orange,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: widget.newAchievements
                              .map(
                                (status) => AchievementBadge(
                                  icon: status.definition.icon,
                                  label: status.definition.title,
                                  highlighted: true,
                                ),
                              )
                              .toList(),
                        ),
                      ],
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

class _RunningLinePainter extends CustomPainter {
  _RunningLinePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = MapUiColors.primaryGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    const segments = 24;
    final visible = (segments * progress).ceil().clamp(1, segments);

    for (var i = 0; i <= visible; i++) {
      final t = i / segments;
      final x = t * size.width;
      final y = size.height * 0.5 +
          math.sin(t * math.pi * 4 + progress * math.pi * 2) * 28 +
          math.cos(t * math.pi * 6) * 12;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RunningLinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
