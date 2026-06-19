import 'package:flutter/material.dart';

enum AchievementId {
  firstWorkout,
  earlyBird,
  speedDemon,
  peakForm,
  streak7,
  century,
  marathoner,
  ninja,
  explorer,
  photographer,
  traveler,
  worldTraveler,
}

class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });

  final AchievementId id;
  final String title;
  final String description;
  final IconData icon;

  String get storageKey => id.name;
}

class AchievementStatus {
  const AchievementStatus({
    required this.definition,
    required this.unlocked,
    this.unlockedAt,
  });

  final AchievementDefinition definition;
  final bool unlocked;
  final DateTime? unlockedAt;

  bool get isNew =>
      unlocked &&
      unlockedAt != null &&
      DateTime.now().difference(unlockedAt!).inHours < 24;
}

class AchievementSyncResult {
  const AchievementSyncResult({
    required this.all,
    required this.newlyUnlocked,
  });

  final List<AchievementStatus> all;
  final List<AchievementStatus> newlyUnlocked;
}
