import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/widgets/app_confirm_dialog.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:map_routing/data/models/planned_workout.dart';
import 'package:map_routing/data/services/gpx_workout_service.dart';
import 'package:map_routing/data/services/planned_workout_service.dart';
import 'package:map_routing/data/services/user_workout_storage.dart';
import 'package:map_routing/features/profile/presentation/create_planned_workout_page.dart';
import 'package:map_routing/features/profile/presentation/profile_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlannedWorkoutsSection extends StatefulWidget {
  const PlannedWorkoutsSection({
    super.key,
    required this.onOpenOnMap,
  });

  final ValueChanged<PlannedWorkout> onOpenOnMap;

  @override
  State<PlannedWorkoutsSection> createState() => PlannedWorkoutsSectionState();
}

class PlannedWorkoutsSectionState extends State<PlannedWorkoutsSection> {
  List<PlannedWorkout> _workouts = [];
  bool _loading = true;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _workouts.isNotEmpty) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> reload({bool force = false}) => _load(force: force);

  Future<void> _load({bool force = false}) async {
    if (!force && !_loading && _workouts.isNotEmpty) return;

    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final userId = await UserWorkoutStorage.instance.syncUserIdFromToken(
      prefs.getString('jwt_token'),
    );
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final workouts = await PlannedWorkoutService.instance.loadUpcoming(userId);
    if (!mounted) return;
    setState(() {
      _workouts = workouts;
      _loading = false;
    });
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(builder: (_) => const CreatePlannedWorkoutPage()),
    );
    if (created == true) {
      await _load(force: true);
    }
  }

  Future<void> _deleteWorkout(PlannedWorkout workout) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await UserWorkoutStorage.instance.syncUserIdFromToken(
      prefs.getString('jwt_token'),
    );
    if (userId == null) return;

    await PlannedWorkoutService.instance.delete(userId, workout);
    await _load(force: true);
  }

  Future<void> _confirmDelete(PlannedWorkout workout) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Удалить тренировку?',
      message: '«${workout.title}» будет удалена из плана.',
      confirmLabel: 'Удалить',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed == true) {
      await _deleteWorkout(workout);
      if (mounted) {
        AppSnackBar.show(context, 'Тренировка удалена');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProfileSectionHeader(title: 'Менеджер тренировок'),
        const SizedBox(height: 12),
        if (_loading && _workouts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _workouts.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _CreateWorkoutCard(onTap: _openCreate);
                }
                final workout = _workouts[index - 1];
                return _PlannedWorkoutCard(
                  workout: workout,
                  onTap: () => widget.onOpenOnMap(workout),
                  onLongPress: () => _confirmDelete(workout),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _CreateWorkoutCard extends StatelessWidget {
  const _CreateWorkoutCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: profileElevatedDecoration(
              backgroundColor: ProfileColors.cardBg,
              borderColor: ProfileColors.primaryGreen.withValues(alpha: 0.35),
              radius: 18,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ProfileColors.primaryGreen.withValues(alpha: 0.12),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: ProfileColors.primaryGreen,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Создать\nтренировку',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lexendDeca(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ProfileColors.title,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlannedWorkoutCard extends StatelessWidget {
  const _PlannedWorkoutCard({
    required this.workout,
    required this.onTap,
    required this.onLongPress,
  });

  final PlannedWorkout workout;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final countdown = formatPlannedWorkoutCountdown(workout.scheduledAt);
    final isDue = workout.isDue;
    final duration = Duration(seconds: workout.estimatedDurationSeconds);

    return SizedBox(
      width: 240,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE3E8EE)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            ProfileColors.primaryGreen,
                            Color(0xFF00C853),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ProfileColors.primaryGreen.withValues(
                              alpha: 0.22,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        workout.activityType.icon,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            workout.title.trim().isNotEmpty
                                ? workout.title.trim()
                                : workout.activityType.labelRu,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: profileTitleStyle(size: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatPlannedWorkoutSchedule(workout.scheduledAt),
                            style: profileSubtitleStyle(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _PlannedWorkoutMetric(
                          icon: Icons.straighten_rounded,
                          label: WorkoutFormatters.formatDistanceKm(
                            workout.distanceMeters,
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color: const Color(0xFFE3E8EE),
                      ),
                      Expanded(
                        child: _PlannedWorkoutMetric(
                          icon: Icons.timer_outlined,
                          label: duration.inMinutes > 0
                              ? WorkoutFormatters.formatDurationLong(duration)
                              : '—',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color: const Color(0xFFE3E8EE),
                      ),
                      Expanded(
                        child: _PlannedWorkoutMetric(
                          icon: Icons.local_fire_department_outlined,
                          label: '${workout.estimatedCalories}',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDue
                        ? ProfileColors.orange.withValues(alpha: 0.08)
                        : ProfileColors.primaryGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDue ? Icons.play_circle_outline : Icons.schedule,
                        size: 16,
                        color: isDue
                            ? ProfileColors.orange
                            : ProfileColors.primaryGreen,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          countdown,
                          style: GoogleFonts.lexendDeca(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDue
                                ? ProfileColors.orange
                                : ProfileColors.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlannedWorkoutMetric extends StatelessWidget {
  const _PlannedWorkoutMetric({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 14, color: ProfileColors.body),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.lexendDeca(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: ProfileColors.title,
          ),
        ),
      ],
    );
  }
}
