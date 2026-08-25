import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

class AppMapTileLayer extends StatelessWidget {
  final String urlTemplate;
  final String userAgentPackageName;

  const AppMapTileLayer({
    super.key,
    this.urlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    this.userAgentPackageName = 'com.trackmate.app',
  });

  /// Inversion matrix that shifts standard OSM tiles to an eye-friendly dark/night palette
  /// without requiring external paid map services.
  static const List<double> darkMapFilterMatrix = <double>[
    -0.80, 0.0, 0.0, 0.0, 235.0,
    0.0, -0.80, 0.0, 0.0, 235.0,
    0.0, 0.0, -0.80, 0.0, 235.0,
    0.0, 0.0, 0.0, 1.0, 0.0,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tileLayer = TileLayer(
      urlTemplate: urlTemplate,
      userAgentPackageName: userAgentPackageName,
    );

    if (isDark) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix(darkMapFilterMatrix),
        child: tileLayer,
      );
    }

    return tileLayer;
  }
}
