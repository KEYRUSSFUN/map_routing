import 'package:flutter/material.dart';

class ProfileCoverPreset {
  const ProfileCoverPreset({
    required this.id,
    required this.title,
    required this.colors,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
    this.icon = Icons.directions_run_rounded,
  });

  final String id;
  final String title;
  final List<Color> colors;
  final Alignment begin;
  final Alignment end;
  final IconData icon;
}

abstract final class ProfileCoverPresets {
  static const defaultPresetId = 'sport_trail';

  static const all = <ProfileCoverPreset>[
    ProfileCoverPreset(
      id: 'sport_trail',
      title: 'Трейл',
      colors: [Color(0xFF1B5E20), Color(0xFF004D40), Color(0xFF263238)],
      icon: Icons.terrain_rounded,
    ),
    ProfileCoverPreset(
      id: 'sport_sprint',
      title: 'Спринт',
      colors: [Color(0xFFFF5722), Color(0xFFE91E63), Color(0xFF880E4F)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      icon: Icons.speed_rounded,
    ),
    ProfileCoverPreset(
      id: 'sport_mountain',
      title: 'Горы',
      colors: [Color(0xFF3949AB), Color(0xFF5C6BC0), Color(0xFF1A237E)],
      icon: Icons.landscape_rounded,
    ),
    ProfileCoverPreset(
      id: 'sport_stadium',
      title: 'Стадион',
      colors: [Color(0xFF2E7D32), Color(0xFF43A047), Color(0xFF1B5E20)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      icon: Icons.stadium_outlined,
    ),
    ProfileCoverPreset(
      id: 'sport_cycling',
      title: 'Велосипед',
      colors: [Color(0xFFFFB300), Color(0xFFFF6F00), Color(0xFFE65100)],
      icon: Icons.directions_bike_rounded,
    ),
    ProfileCoverPreset(
      id: 'sport_sunset',
      title: 'Закат',
      colors: [Color(0xFFFF7043), Color(0xFFAB47BC), Color(0xFF311B92)],
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      icon: Icons.wb_twilight_rounded,
    ),
    ProfileCoverPreset(
      id: 'sport_ocean',
      title: 'Океан',
      colors: [Color(0xFF0288D1), Color(0xFF00ACC1), Color(0xFF006064)],
      icon: Icons.waves_rounded,
    ),
    ProfileCoverPreset(
      id: 'sport_forest',
      title: 'Лес',
      colors: [Color(0xFF33691E), Color(0xFF558B2F), Color(0xFF1B5E20)],
      icon: Icons.park_rounded,
    ),
  ];

  static ProfileCoverPreset? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final preset in all) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  static ProfileCoverPreset get fallback =>
      byId(defaultPresetId) ?? all.first;
}
