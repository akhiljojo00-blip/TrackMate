import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CustomSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color activeColor;

  const CustomSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor = AppColors.primary,
  });

  @override
  State<CustomSwitch> createState() => _CustomSwitchState();
}

class _CustomSwitchState extends State<CustomSwitch> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Alignment> _slideAnimation;
  late Animation<Color?> _trackColorAnimation;
  late Animation<Color?> _thumbColorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _setupAnimations();

    if (widget.value) {
      _controller.value = 1.0;
    }
  }

  void _setupAnimations() {
    _slideAnimation = AlignmentTween(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _trackColorAnimation = ColorTween(
      begin: Colors.white.withValues(alpha: 0.1),
      end: widget.activeColor.withValues(alpha: 0.3),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _thumbColorAnimation = ColorTween(
      begin: Colors.grey.shade400,
      end: widget.activeColor,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant CustomSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeColor != widget.activeColor) {
      _setupAnimations();
    }
    if (widget.value != oldWidget.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onChanged != null) {
      widget.onChanged!(!widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final isOn = _controller.value > 0.5;
          return Container(
            width: 52,
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: _trackColorAnimation.value,
              border: Border.all(
                color: isOn 
                    ? widget.activeColor.withValues(alpha: 0.5) 
                    : Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
              boxShadow: isOn
                  ? [
                      BoxShadow(
                        color: widget.activeColor.withValues(alpha: 0.2 * _controller.value),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: Align(
              alignment: _slideAnimation.value,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _thumbColorAnimation.value,
                  boxShadow: isOn
                      ? [
                          BoxShadow(
                            color: widget.activeColor.withValues(alpha: 0.5 * _controller.value),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
