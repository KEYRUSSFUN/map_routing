import 'package:flutter/material.dart';
import 'package:map_routing/data/models/club.dart';
import 'package:map_routing/data/models/workout_activity_type.dart';
import 'package:map_routing/data/services/gpx_workout_service.dart';
import 'package:map_routing/features/profile/presentation/profile_ui.dart';

class ClubWorkoutCard extends StatelessWidget {
  const ClubWorkoutCard({
    super.key,
    required this.workout,
    required this.onTap,
  });

  final ClubMemberWorkout workout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activity = workout.activityType != null
        ? WorkoutActivityType.fromId(workout.activityType)
        : null;
    final duration = workout.durationSeconds != null
        ? Duration(seconds: workout.durationSeconds!)
        : null;
    final distanceMeters = workout.distanceMeters ?? 0;
    final title = workout.title?.trim().isNotEmpty == true
        ? workout.title!.trim()
        : 'Тренировка';

    final subtitleParts = <String>[
      if (workout.startedAt != null)
        WorkoutFormatters.formatDateTime(workout.startedAt!),
      if (activity != null) activity.labelRu,
    ];

    String? detailLine;
    if (workout.tags.isNotEmpty) {
      detailLine = workout.tags.map((tag) => '#$tag').join(' ');
    } else if (workout.description != null &&
        workout.description!.isNotEmpty) {
      detailLine = workout.description;
    }

    return ActivityCard(
      title: title,
      subtitle: subtitleParts.join(' · '),
      detailLine: detailLine,
      icon: activity?.icon ?? Icons.directions_run,
      ownerName: workout.userName,
      ownerAvatarUrl: workout.avatarUrl,
      onTap: onTap,
      stats: [
        ActivityStat(
          value: WorkoutFormatters.formatDistanceKm(distanceMeters),
          label: 'Дистанция',
        ),
        ActivityStat(
          value: WorkoutFormatters.formatPace(duration, distanceMeters),
          label: 'Средний темп',
        ),
        ActivityStat(
          value: duration != null
              ? WorkoutFormatters.formatDurationLong(duration)
              : '—',
          label: 'Время',
        ),
      ],
    );
  }
}
