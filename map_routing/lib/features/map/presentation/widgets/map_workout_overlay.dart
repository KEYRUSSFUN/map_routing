import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/data/models/workout_session_data.dart';
import 'package:map_routing/features/map/presentation/map_ui_styles.dart';

class MapWorkoutOverlay extends StatelessWidget {
  const MapWorkoutOverlay({
    super.key,
    required this.speedKmh,
    required this.distanceKm,
    required this.duration,
    required this.calories,
    required this.elevationM,
    required this.motionStatus,
    this.isGuided = false,
    this.routeRemainingKm = 0,
    this.routeProgress = 0,
    this.isOffRoute = false,
    required this.isLocked,
    required this.isManualPaused,
    required this.onStop,
    required this.onStatusTap,
    required this.onToggleLock,
    required this.onMinimize,
    required this.onSwipeUpHint,
    required this.metricsSheetProgress,
  });

  final double speedKmh;
  final double distanceKm;
  final Duration duration;
  final double calories;
  final double elevationM;
  final WorkoutMotionStatus motionStatus;
  final bool isGuided;
  final double routeRemainingKm;
  final double routeProgress;
  final bool isOffRoute;
  final bool isLocked;
  final bool isManualPaused;
  final VoidCallback onStop;
  final VoidCallback onStatusTap;
  final VoidCallback onToggleLock;
  final VoidCallback onMinimize;
  final VoidCallback onSwipeUpHint;
  final double metricsSheetProgress;

  Color get _statusColor {
    if (isManualPaused) return MapUiColors.statusPaused;
    switch (motionStatus) {
      case WorkoutMotionStatus.moving:
        return MapUiColors.statusMoving;
      case WorkoutMotionStatus.paused:
        return MapUiColors.statusPaused;
      case WorkoutMotionStatus.stationary:
        return MapUiColors.statusStationary;
    }
  }

  IconData get _statusIcon {
    if (isManualPaused) return Icons.pause_rounded;
    switch (motionStatus) {
      case WorkoutMotionStatus.moving:
        return Icons.directions_run_rounded;
      case WorkoutMotionStatus.paused:
        return Icons.pause_rounded;
      case WorkoutMotionStatus.stationary:
        return Icons.accessibility_new_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        if (isLocked)
          Positioned.fill(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                  color: const Color.fromARGB(255, 0, 0, 0)
                      .withValues(alpha: 0.08)),
            ),
          ),
        Positioned(
          top: top + 8,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: _MinimizeButton(
                  isLocked: isLocked,
                  onPressed: onMinimize,
                ),
              ),
              if (isGuided) ...[
                const SizedBox(height: 8),
                _GuidedRouteBanner(
                  remainingKm: routeRemainingKm,
                  progress: routeProgress,
                  isOffRoute: isOffRoute,
                ),
              ],
              const SizedBox(height: 8),
              _MainMetricsCard(
                speedKmh: speedKmh,
                distanceKm: distanceKm,
                duration: duration,
                isGuided: isGuided,
                routeRemainingKm: routeRemainingKm,
                routeProgress: routeProgress,
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 150 + metricsSheetProgress * 40,
          child: Row(
            children: [
              Expanded(
                child: _MetricPill(
                  icon: Icons.local_fire_department_outlined,
                  value: formatCalories(calories),
                  label: 'ККАЛ',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricPill(
                  icon: Icons.terrain_outlined,
                  value: formatElevation(elevationM),
                  label: 'ВЫСОТА',
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 24 + metricsSheetProgress * 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StopButton(onTap: isLocked ? () {} : onStop),
                  const SizedBox(width: 28),
                  _StatusButton(
                    color: _statusColor,
                    icon: _statusIcon,
                    onTap: isLocked ? () {} : onStatusTap,
                  ),
                  const SizedBox(width: 28),
                  _LockButton(
                    isLocked: isLocked,
                    onTap: onToggleLock,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onVerticalDragUpdate: (d) {
                  if (d.delta.dy < -4) onSwipeUpHint();
                },
                onTap: onSwipeUpHint,
                child: Column(
                  children: [
                    Icon(Icons.keyboard_arrow_up_rounded,
                        color: Colors.white.withValues(alpha: 0.85)),
                    Text(
                      'СВАЙП ВВЕРХ — БОЛЬШЕ МЕТРИК',
                      style: GoogleFonts.lexendDeca(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MinimizeButton extends StatelessWidget {
  const _MinimizeButton({
    required this.isLocked,
    required this.onPressed,
  });

  final bool isLocked;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black26,
      child: IconButton(
        tooltip: 'Свернуть',
        onPressed: isLocked ? null : onPressed,
        icon: const Icon(Icons.open_in_full_rounded, size: 20),
      ),
    );
  }
}

class _GuidedRouteBanner extends StatelessWidget {
  const _GuidedRouteBanner({
    required this.remainingKm,
    required this.progress,
    required this.isOffRoute,
  });

  final double remainingKm;
  final double progress;
  final bool isOffRoute;

  @override
  Widget build(BuildContext context) {
    final finished = progress >= 0.995;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: isOffRoute
            ? const Color(0xFFFFF3E0)
            : Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOffRoute
              ? MapUiColors.statusPaused
              : MapUiColors.primaryGreen.withValues(alpha: 0.35),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                finished
                    ? Icons.flag_rounded
                    : isOffRoute
                        ? Icons.warning_amber_rounded
                        : Icons.route_rounded,
                color: finished
                    ? MapUiColors.primaryGreen
                    : isOffRoute
                        ? MapUiColors.statusPaused
                        : MapUiColors.primaryGreen,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  finished
                      ? 'Маршрут пройден!'
                      : isOffRoute
                          ? 'Вы отклонились от маршрута'
                          : 'Осталось ${remainingKm.toStringAsFixed(2)} км',
                  style: GoogleFonts.lexendDeca(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MapUiColors.title,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: GoogleFonts.lexendDeca(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MapUiColors.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 6,
              backgroundColor: const Color(0xFFE8E8E8),
              color: MapUiColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _MainMetricsCard extends StatelessWidget {
  const _MainMetricsCard({
    required this.speedKmh,
    required this.distanceKm,
    required this.duration,
    this.isGuided = false,
    this.routeRemainingKm = 0,
    this.routeProgress = 0,
  });

  final double speedKmh;
  final double distanceKm;
  final Duration duration;
  final bool isGuided;
  final double routeRemainingKm;
  final double routeProgress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            speedKmh.toStringAsFixed(2),
            style: mapMetricValueStyle(size: 36),
          ),
          const SizedBox(height: 4),
          Text(
            'СКОРОСТЬ (км/ч)',
            style: mapMetricLabelStyle(color: MapUiColors.primaryGreen),
          ),
          Container(
            margin: const EdgeInsets.only(top: 6),
            height: 3,
            width: 48,
            decoration: BoxDecoration(
              color: MapUiColors.primaryGreen,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      isGuided
                          ? routeRemainingKm.toStringAsFixed(2)
                          : distanceKm.toStringAsFixed(2),
                      style: mapMetricValueStyle(size: 22),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isGuided ? 'ОСТАЛОСЬ (КМ)' : 'ДИСТАНЦИЯ (КМ)',
                      style: mapMetricLabelStyle(),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 36, color: const Color(0xFFE0E0E0)),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      formatWorkoutDuration(duration),
                      style: mapMetricValueStyle(size: 22),
                    ),
                    const SizedBox(height: 2),
                    Text('ДЛИТЕЛЬНОСТЬ', style: mapMetricLabelStyle()),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: MapUiColors.glassDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.lexendDeca(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                label,
                style: mapMetricLabelStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  const _StopButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MapUiColors.stopRed,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 56,
          height: 56,
          child: Icon(Icons.stop_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 8,
      shadowColor: color.withValues(alpha: 0.5),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 72,
          height: 72,
          child:
              Icon(icon, color: const Color.fromARGB(255, 0, 0, 0), size: 32),
        ),
      ),
    );
  }
}

class _LockButton extends StatelessWidget {
  const _LockButton({
    required this.isLocked,
    required this.onTap,
  });

  final bool isLocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(
            isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
            color: MapUiColors.title,
            size: 24,
          ),
        ),
      ),
    );
  }
}
