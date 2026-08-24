import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _SosButtonState extends State<SosButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _controller.addListener(() {
      if (mounted) {
        context.read<SosProvider>().updateHoldProgress(_controller.value);
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        context.read<SosProvider>().triggerSos();
        widget.onTriggered?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHoldStart() {
    final isTriggered = context.read<SosProvider>().isTriggered;
    if (isTriggered) return;

    setState(() => _isHolding = true);
    HapticFeedback.mediumImpact();
    _controller.forward(from: 0.0);
  }

  void _onHoldEnd() {
    if (_controller.status != AnimationStatus.completed) {
      _controller.reverse();
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
          animation: _controller,
          builder: (context, child) {
            final progress = isTriggered ? 1.0 : _controller.value;

            return Stack(
              alignment: Alignment.center,
              children: [
                // Outer Hold Progress Ring
                SizedBox(
                  width: 68,
                  height: 68,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 4.5,
                    backgroundColor: isTriggered
                        ? AppColors.error.withValues(alpha: 0.3)
                        : (_isHolding ? Colors.red.withValues(alpha: 0.3) : Colors.transparent),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isTriggered ? AppColors.error : const Color(0xFFFF1744),
                    ),
                  ),
                ),
                // Inner Button Container
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isTriggered ? AppColors.error : const Color(0xFFD32F2F),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isTriggered ? AppColors.error : Colors.red).withValues(alpha: 0.45),
                        blurRadius: _isHolding ? 14 : 8,
                        spreadRadius: _isHolding ? 3 : 1,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        Text(
                          isTriggered ? 'ACTIVE' : 'SOS',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
