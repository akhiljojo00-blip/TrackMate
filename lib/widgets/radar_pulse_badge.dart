import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum BroadcastMode { live, blurred, ghost }

class RadarPulseBadge extends StatefulWidget {
  final BroadcastMode mode;
  final String label;

  const RadarPulseBadge({
    super.key,
    required this.mode,
    required this.label,
  });

  @override
  State<RadarPulseBadge> createState() => _RadarPulseBadgeState();
}

class _RadarPulseBadgeState extends State<RadarPulseBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _statusColor {
    switch (widget.mode) {
      case BroadcastMode.live:
        return AppColors.broadcastLive;
      case BroadcastMode.blurred:
        return AppColors.broadcastBlurred;
      case BroadcastMode.ghost:
        return AppColors.sapphireGlow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary( // CRITICAL: Isolates continuous ticker from Map rebuilds
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xCC0F1B2B), // Solid base for badge inner fill
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _statusColor.withValues(alpha: 0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: _statusColor.withValues(alpha: 0.15),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: const Size(14, 14),
              painter: _RadarPulsePainter(
                animation: _controller,
                color: _statusColor,
                isPulsing: widget.mode != BroadcastMode.ghost,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              widget.label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarPulsePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;
  final bool isPulsing;

  _RadarPulsePainter({
    required this.animation,
    required this.color,
    required this.isPulsing,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    if (isPulsing) {
      // Outer expanding ring
      final outerProgress = animation.value;
      final outerPaint = Paint()
        ..color = color.withValues(alpha: (1.0 - outerProgress) * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, maxRadius * (0.4 + 0.6 * outerProgress), outerPaint);

      // Inner secondary ring
      final innerProgress = (animation.value + 0.5) % 1.0;
      final innerPaint = Paint()
        ..color = color.withValues(alpha: (1.0 - innerProgress) * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(center, maxRadius * (0.4 + 0.6 * innerProgress), innerPaint);
    }

    // Core Solid Dot
    final corePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3.5, corePaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPulsePainter oldDelegate) {
    return oldDelegate.animation.value != animation.value ||
           oldDelegate.color != color ||
           oldDelegate.isPulsing != isPulsing;
  }
}
