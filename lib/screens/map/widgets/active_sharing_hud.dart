import 'dart:async';
import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';

class ActiveSharingHud extends StatefulWidget {
  final bool isTracking;
  final int? expiresAt;
  final int visibleFriendsCount;
  final VoidCallback onStopPressed;

  const ActiveSharingHud({
    super.key,
    required this.isTracking,
    this.expiresAt,
    this.visibleFriendsCount = 0,
    required this.onStopPressed,
  });

  @override
  State<ActiveSharingHud> createState() => _ActiveSharingHudState();
}

class _ActiveSharingHudState extends State<ActiveSharingHud> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  Timer? _tickerTimer;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _tickerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && widget.isTracking && widget.expiresAt != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatRemainingDuration() {
    if (widget.expiresAt == null) return 'Indefinite';

    final remainingMs = widget.expiresAt! - DateTime.now().millisecondsSinceEpoch;
    if (remainingMs <= 0) return 'Expiring...';

    final totalMinutes = (remainingMs / 60000).ceil();
    if (totalMinutes >= 60) {
      final hours = totalMinutes ~/ 60;
      final minutes = totalMinutes % 60;
      return minutes > 0 ? '${hours}h ${minutes}m left' : '${hours}h left';
    } else if (totalMinutes > 1) {
      return '$totalMinutes mins left';
    } else {
      return '< 1 min left';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isTracking) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade800.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_off_outlined,
              color: Colors.white70,
              size: 18,
            ),
            const SizedBox(width: 8),
            const Text(
              'Sharing is OFF',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            if (widget.visibleFriendsCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.visibleFriendsCount} friend${widget.visibleFriendsCount > 1 ? 's' : ''} visible',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ],
        ),
      );
    }

    final isTimed = widget.expiresAt != null;
    final accentColor = isTimed ? const Color(0xFFFBBF24) : AppColors.success;
    final remainingText = _formatRemainingDuration();

    return Container(
      padding: const EdgeInsets.only(left: 12, right: 6, top: 5, bottom: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1426).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.25),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulsing Live Indicator Dot
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: _pulseAnimation.value),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: _pulseAnimation.value * 0.8),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 10),

          // Status & Countdown Text
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Sharing Live',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '• $remainingText',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (widget.visibleFriendsCount > 0)
                Text(
                  '${widget.visibleFriendsCount} friend${widget.visibleFriendsCount > 1 ? 's' : ''} visible',
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                ),
            ],
          ),
          const SizedBox(width: 10),

          // Direct Stop Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onStopPressed,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.stop_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    SizedBox(width: 3),
                    Text(
                      'Stop',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
