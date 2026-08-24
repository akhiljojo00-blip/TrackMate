import 'package:flutter/material.dart';

class GeofencePreset {
  final int index;
  final String name;
  final IconData icon;
  final List<Color> gradientColors;

  const GeofencePreset({
    required this.index,
    required this.name,
    required this.icon,
    required this.gradientColors,
  });
}

class GeofencePresets {
  static const List<GeofencePreset> presets = [
    GeofencePreset(
      index: 0,
      name: 'Home',
      icon: Icons.home_rounded,
      gradientColors: [Color(0xFF1E88E5), Color(0xFF00B4D8)],
    ),
    GeofencePreset(
      index: 1,
      name: 'Work',
      icon: Icons.work_rounded,
      gradientColors: [Color(0xFF5E35B1), Color(0xFF8E24AA)],
    ),
    GeofencePreset(
      index: 2,
      name: 'School / College',
      icon: Icons.school_rounded,
      gradientColors: [Color(0xFF00897B), Color(0xFF43A047)],
    ),
    GeofencePreset(
      index: 3,
      name: 'Gym / Sports',
      icon: Icons.fitness_center_rounded,
      gradientColors: [Color(0xFFFB8C00), Color(0xFFFDD835)],
    ),
    GeofencePreset(
      index: 4,
      name: 'Family / Haven',
      icon: Icons.favorite_rounded,
      gradientColors: [Color(0xFFE53935), Color(0xFFFF5252)],
    ),
    GeofencePreset(
      index: 5,
      name: 'Cafe / Hangout',
      icon: Icons.local_cafe_rounded,
      gradientColors: [Color(0xFF6D4C41), Color(0xFF8D6E63)],
    ),
    GeofencePreset(
      index: 6,
      name: 'Safe Zone',
      icon: Icons.shield_rounded,
      gradientColors: [Color(0xFF3949AB), Color(0xFF1E88E5)],
    ),
  ];

  static GeofencePreset getPreset(int index) {
    if (index >= 0 && index < presets.length) {
      return presets[index];
    }
    return presets[0];
  }
}
