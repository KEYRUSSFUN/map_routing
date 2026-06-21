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

  static const _celebrationColors = [
    MapUiColors.primaryGreen,
    Color(0xFF00C853),
    ProfileColors.greenBorder,
    MapUiColors.routeOrange,
    ProfileColors.orangeBorder,
  ];

  @override
  State<WorkoutCelebrationPage> createState() => _WorkoutCelebrationPageState();
}

class _WorkoutCelebrationPageState extends State<WorkoutCelebrationPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final String _phrase;
  late final List<_ConfettiParticle> _particles;
  bool _showPhrase = false;
  bool _showAchievements = false;

  @override
  void initState() {
    super.initState();
    _phrase = WorkoutCelebrationPage.phrases[
        math.Random().nextInt(WorkoutCelebrationPage.phrases.length)];
    _particles = _ConfettiParticle.generate(
      math.Random(),
      colors: WorkoutCelebrationPage._celebrationColors,
    );
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
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return CustomPaint(
                        size: Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        ),
                        painter: _ConfettiSalutePainter(
                          progress: _controller.value,
                          particles: _particles,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
          ],
        ),
      ),
    );
  }
}

enum _ConfettiShape { rect, circle, ribbon }

class _ConfettiParticle {
  const _ConfettiParticle({
    required this.originX,
    required this.originY,
    required this.vx,
    required this.vy,
    required this.delay,
    required this.color,
    required this.size,
    required this.rotation,
    required this.spin,
    required this.shape,
  });

  final double originX;
  final double originY;
  final double vx;
  final double vy;
  final double delay;
  final Color color;
  final double size;
  final double rotation;
  final double spin;
  final _ConfettiShape shape;

  static List<_ConfettiParticle> generate(
    math.Random rng, {
    required List<Color> colors,
    int count = 110,
  }) {
    const origins = [
      (x: 0.5, y: 0.46),
      (x: 0.28, y: 0.5),
      (x: 0.72, y: 0.5),
    ];

    return List.generate(count, (index) {
      final origin = origins[index % origins.length];
      final spread = rng.nextDouble() * math.pi * 0.9 - math.pi * 0.45;
      final angle = -math.pi / 2 + spread;
      final speed = 220 + rng.nextDouble() * 380;
      const shapes = _ConfettiShape.values;

      return _ConfettiParticle(
        originX: origin.x + (rng.nextDouble() - 0.5) * 0.06,
        originY: origin.y + (rng.nextDouble() - 0.5) * 0.04,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        delay: index % 3 == 0 ? rng.nextDouble() * 0.08 : 0,
        color: colors[rng.nextInt(colors.length)],
        size: 5 + rng.nextDouble() * 7,
        rotation: rng.nextDouble() * math.pi * 2,
        spin: (rng.nextDouble() - 0.5) * 10,
        shape: shapes[rng.nextInt(shapes.length)],
      );
    });
  }
}

class _ConfettiSalutePainter extends CustomPainter {
  _ConfettiSalutePainter({
    required this.progress,
    required this.particles,
  });

  final double progress;
  final List<_ConfettiParticle> particles;

  static const _durationSec = 2.8;
  static const _gravity = 520.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    for (final particle in particles) {
      final localProgress =
          ((progress - particle.delay) / (1 - particle.delay)).clamp(0.0, 1.0);
      if (localProgress <= 0) continue;

      final time = localProgress * _durationSec;
      final x = particle.originX * size.width + particle.vx * time;
      final y = particle.originY * size.height +
          particle.vy * time +
          0.5 * _gravity * time * time;

      if (x < -24 || x > size.width + 24 || y > size.height + 24) {
        continue;
      }

      const fadeStart = 0.35;
      final alpha = localProgress < fadeStart
          ? localProgress / fadeStart
          : (1 - (localProgress - fadeStart) / (1 - fadeStart)).clamp(0.0, 1.0);

      final paint = Paint()..color = particle.color.withValues(alpha: alpha);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(particle.rotation + particle.spin * localProgress);

      switch (particle.shape) {
        case _ConfettiShape.circle:
          canvas.drawCircle(Offset.zero, particle.size * 0.45, paint);
        case _ConfettiShape.rect:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: particle.size,
                height: particle.size * 0.55,
              ),
              const Radius.circular(2),
            ),
            paint,
          );
        case _ConfettiShape.ribbon:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: particle.size * 0.45,
                height: particle.size * 1.6,
              ),
              const Radius.circular(2),
            ),
            paint,
          );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiSalutePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
