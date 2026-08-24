import 'package:flutter/material.dart';

class AvatarPreset {
  final int index;
  final String name;
  final List<Color> gradientColors;
  final IconData icon;

  const AvatarPreset({
    required this.index,
    required this.name,
    required this.gradientColors,
    required this.icon,
  });
}

class AvatarPresets {
  static const List<AvatarPreset> presets = [
    AvatarPreset(
      index: 0,
      name: 'Radar Blue',
      gradientColors: [Color(0xFF1E88E5), Color(0xFF00B4D8)],
      icon: Icons.radar_rounded,
    ),
    AvatarPreset(
      index: 1,
      name: 'Neon Purple',
      gradientColors: [Color(0xFF8E24AA), Color(0xFFE040FB)],
      icon: Icons.auto_awesome_rounded,
    ),
    AvatarPreset(
      index: 2,
      name: 'Emerald Shield',
      gradientColors: [Color(0xFF00897B), Color(0xFF43A047)],
      icon: Icons.shield_rounded,
    ),
    AvatarPreset(
      index: 3,
      name: 'Solar Amber',
      gradientColors: [Color(0xFFFB8C00), Color(0xFFFDD835)],
      icon: Icons.wb_sunny_rounded,
    ),
    AvatarPreset(
      index: 4,
      name: 'Crimson Flame',
      gradientColors: [Color(0xFFE53935), Color(0xFFFF7043)],
      icon: Icons.local_fire_department_rounded,
    ),
    AvatarPreset(
      index: 5,
      name: 'Cosmic Indigo',
      gradientColors: [Color(0xFF3949AB), Color(0xFF7E57C2)],
      icon: Icons.rocket_launch_rounded,
    ),
    AvatarPreset(
      index: 6,
      name: 'Teal Compass',
      gradientColors: [Color(0xFF00ACC1), Color(0xFF26A69A)],
      icon: Icons.explore_rounded,
    ),
    AvatarPreset(
      index: 7,
      name: 'Midnight Slate',
      gradientColors: [Color(0xFF263238), Color(0xFF455A64)],
      icon: Icons.navigation_rounded,
    ),
  ];

  static AvatarPreset getPreset(int? index) {
    if (index == null || index < 0 || index >= presets.length) {
      return presets[0];
    }
    return presets[index];
  }
}
