import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/sos_provider.dart';

class SosButton extends StatefulWidget {
  final VoidCallback? onTriggered;

  const SosButton({
    super.key,
    this.onTriggered,
  });

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> with TickerProviderStateMixin {
  late final AnimationController _holdController;
  late final AnimationController _pulseController;
  
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _holdController.addListener(() {
      if (mounted) {
        context.read<SosProvider>().updateHoldProgress(_holdController.value);
      }
    });

    _holdController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        context.read<SosProvider>().triggerSos();
        widget.onTriggered?.call();
      }
    });
  }

  @override
  void dispose() {
    _holdController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onHoldStart() {
    final isTriggered = context.read<SosProvider>().isTriggered;
    if (isTriggered) return;

    setState(() => _isHolding = true);
    HapticFeedback.mediumImpact();
    _holdController.forward(from: 0.0);
  }

  void _onHoldEnd() {
    if (_holdController.status != AnimationStatus.completed) {
      _holdController.reverse();
      context.read<SosProvider>().cancelHold();
    }
    setState(() => _isHolding = false);
  }

  @override
  Widget build(BuildContext context) {
    final sosProvider = context.watch<SosProvider>();
    final isTriggered = sosProvider.isTriggered;

    return Semantics(
      button: true,
      label: 'Emergency SOS button. Press and hold for 3 seconds to activate.',
      child: GestureDetector(
        onTapDown: (_) => _onHoldStart(),
        onTapUp: (_) => _onHoldEnd(),
        onTapCancel: () => _onHoldEnd(),
        child: AnimatedBuilder(
          animation: Listenable.merge([_holdController, _pulseController]),
          builder: (context, child) {
            final progress = isTriggered ? 1.0 : _holdController.value;
            final scale = 1.0 - (progress * 0.05); // slight shrink while holding
            
            return Transform.scale(
              scale: scale,
              child: SizedBox(
                width: 90,
                height: 90,
                child: CustomPaint(
                  painter: _SosButtonPainter(
                    progress: progress,
                    pulseValue: isTriggered || _isHolding ? _pulseController.value : 0.0,
                    isTriggered: isTriggered,
                  ),
                  child: Center(
                    child: Text(
                      isTriggered ? 'ACTIVE' : 'SOS',
                      style: TextStyle(
                        color: isTriggered ? Colors.white : AppColors.error,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        shadows: [
                          BoxShadow(
                            color: AppColors.error.withValues(alpha: 0.8),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SosButtonPainter extends CustomPainter {
  final double progress;
  final double pulseValue;
  final bool isTriggered;

  _SosButtonPainter({
    required this.progress,
    required this.pulseValue,
    required this.isTriggered,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.75;
    
    // Background (Midnight Sapphire / Glass effect)
    final bgPaint = Paint()
      ..color = AppColors.midnightBackground.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;
    
    // Inner Button Body
    final innerBgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          isTriggered ? AppColors.error : AppColors.midnightBackground,
          AppColors.midnightBackground.withValues(alpha: 0.9),
        ],
        stops: const [0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: innerRadius))
      ..style = PaintingStyle.fill;
      
    // Inner border / rim
    final rimPaint = Paint()
      ..color = AppColors.glassBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw base circles
    canvas.drawCircle(center, innerRadius, bgPaint);
    canvas.drawCircle(center, innerRadius, innerBgPaint);
    canvas.drawCircle(center, innerRadius, rimPaint);

    // Pulse Ripples (Active Zone Ripple Effect)
    if (pulseValue > 0) {
      final maxRippleRadius = outerRadius;
      final rippleRadius = innerRadius + (maxRippleRadius - innerRadius) * pulseValue;
      final rippleAlpha = (1.0 - pulseValue).clamp(0.0, 1.0) * 0.5;
      
      final ripplePaint = Paint()
        ..color = AppColors.error.withValues(alpha: rippleAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
        
      canvas.drawCircle(center, rippleRadius, ripplePaint);
      
      final secondaryRippleRadius = innerRadius + (maxRippleRadius - innerRadius) * (pulseValue * 0.5);
      final secondaryRippleAlpha = (1.0 - (pulseValue * 0.5)).clamp(0.0, 1.0) * 0.3;
      
      final secondaryRipplePaint = Paint()
        ..color = AppColors.error.withValues(alpha: secondaryRippleAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
        
      canvas.drawCircle(center, secondaryRippleRadius, secondaryRipplePaint);
    }

    // Progress Ring (Hold-to-activate)
    if (progress > 0) {
      final ringPaint = Paint()
        ..color = AppColors.error
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.0); // Glow effect
        
      final rect = Rect.fromCircle(center: center, radius: innerRadius + 6);
      final startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress;
      
      canvas.drawArc(rect, startAngle, sweepAngle, false, ringPaint);
      
      // Core ring line (bright center of glow)
      final coreRingPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
        
      canvas.drawArc(rect, startAngle, sweepAngle, false, coreRingPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SosButtonPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.pulseValue != pulseValue ||
           oldDelegate.isTriggered != isTriggered;
  }
}
