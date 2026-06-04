import 'package:flutter/material.dart';

enum WorkoutActivityType {
  run('run', 'Бег', Icons.directions_run),
  walk('walk', 'Прогулка', Icons.directions_walk),
  bike('bike', 'Велосипед', Icons.directions_bike),
  hike('hike', 'Поход', Icons.terrain),
  trail('trail', 'Трейлран', Icons.hiking),
  roller('roller', 'Ролики', Icons.skateboarding),
  ski('ski', 'Лыжи', Icons.downhill_skiing),
  swim('swim', 'Плавание', Icons.pool);

  const WorkoutActivityType(this.id, this.labelRu, this.icon);

  final String id;
  final String labelRu;
  final IconData icon;

  static WorkoutActivityType fromId(String? id) {
    if (id == null) return WorkoutActivityType.run;
    return WorkoutActivityType.values.firstWhere(
      (t) => t.id == id,
      orElse: () => WorkoutActivityType.run,
    );
  }

  double get met {
    switch (this) {
      case WorkoutActivityType.run:
        return 9.0;
      case WorkoutActivityType.walk:
        return 3.8;
      case WorkoutActivityType.bike:
        return 7.5;
      case WorkoutActivityType.hike:
        return 6.0;
      case WorkoutActivityType.trail:
        return 9.5;
      case WorkoutActivityType.roller:
        return 7.0;
      case WorkoutActivityType.ski:
        return 8.0;
      case WorkoutActivityType.swim:
        return 8.3;
    }
  }
}

enum WorkoutPrivacy {
  everyone('everyone', 'Все'),
  friends('friends', 'Только друзья'),
  private_('private', 'Только я');

  const WorkoutPrivacy(this.id, this.labelRu);

  final String id;
  final String labelRu;

  static WorkoutPrivacy fromId(String? id) {
    if (id == null) return WorkoutPrivacy.friends;
    return WorkoutPrivacy.values.firstWhere(
      (p) => p.id == id,
      orElse: () => WorkoutPrivacy.friends,
    );
  }
}
