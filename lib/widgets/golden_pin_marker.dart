import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class GoldenPinMarker extends StatelessWidget {
  final bool isGlowing;
  final double scale;
  final String? label;
  final String? travelMode;

  const GoldenPinMarker({
    super.key,
    this.isGlowing = true,
    this.scale = 1.0,
    this.label,
    this.travelMode,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (label != null)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.midnightBackground.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.solarGold.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (travelMode != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        _getTravelModeIcon(travelMode!),
                        size: 12,
                        color: AppColors.solarGold,
                      ),
                    ),
                  Text(
                    label!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: 48,
            height: 64,
            child: Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                // Base Glow
                if (isGlowing)
                  Positioned(
                    bottom: -8,
                    child: Container(
                      width: 24,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.solarGold.withValues(alpha: 0.6),
                            blurRadius: 12,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                // 3D Pin Painter
                CustomPaint(
                  size: const Size(36, 54),
                  painter: _GoldenPinPainter(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTravelModeIcon(String mode) {
    switch (mode) {
      case 'driving':
        return Icons.directions_car_rounded;
      case 'cycling':
        return Icons.directions_bike_rounded;
      default:
        return Icons.directions_walk_rounded;
    }
  }
}

class _GoldenPinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    
    // Path for the classic teardrop pin shape
    final path = Path();
    path.moveTo(width / 2, height);
    path.cubicTo(
      width / 2, height,
      0, height * 0.6,
      0, width / 2,
    );
    path.arcToPoint(
      Offset(width, width / 2),
      radius: Radius.circular(width / 2),
      clockwise: true,
    );
    path.cubicTo(
      width, height * 0.6,
      width / 2, height,
      width / 2, height,
    );
    path.close();

    // The golden gradient fill
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFF8E1), // very light gold/white
          Color(0xFFFFD54F), // solar gold
          Color(0xFFFFA000), // deep gold
          Color(0xFFB28000), // dark golden brown edge
        ],
        stops: [0.0, 0.4, 0.8, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, width, height));

    // Outer glow for the pin itself
    canvas.drawShadow(path, Colors.black, 4.0, true);
    
    // Draw the main pin body
    canvas.drawPath(path, fillPaint);

    // Inner hole (the eye of the pin)
    final holePath = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(width / 2, width / 2),
        radius: width * 0.18,
      ));

    // Fill hole with background or dark shade to look like a cutout
    final holePaint = Paint()..color = AppColors.midnightBackground;
    canvas.drawPath(holePath, holePaint);

    // Inner highlight ring around the hole
    final innerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFB28000), Color(0xFFFFF8E1)],
      ).createShader(Rect.fromCircle(center: Offset(width / 2, width / 2), radius: width * 0.18));
    
    canvas.drawPath(holePath, innerRingPaint);

    // Subtle edge highlight around the whole pin to give it that 3D bevel
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Colors.white, Color(0x00FFFFFF)],
      ).createShader(Rect.fromLTWH(0, 0, width, height));

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

