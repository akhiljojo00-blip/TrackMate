import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';

class SharingDurationOption {
  final Duration? duration; // null represents indefinite / continuous sharing
  const SharingDurationOption(this.duration);
}

class TimedSharingBottomSheet extends StatelessWidget {
  final void Function(SharingDurationOption option) onDurationSelected;

  const TimedSharingBottomSheet({
    super.key,
    required this.onDurationSelected,
  });

  static Future<SharingDurationOption?> show(BuildContext context) {
    return showModalBottomSheet<SharingDurationOption?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => TimedSharingBottomSheet(
        onDurationSelected: (option) {
          Navigator.of(ctx).pop(option);
        },
      ),
    );
  }

  Future<void> _handleCustomTime(BuildContext context) async {
    final now = TimeOfDay.now();
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (now.hour + 1) % 24,
        minute: now.minute,
      ),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: Color(0xFF0F1F3D),
              onSurface: Colors.white,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (pickedTime != null && context.mounted) {
      final nowDt = DateTime.now();
      var targetDt = DateTime(
        nowDt.year,
        nowDt.month,
        nowDt.day,
        pickedTime.hour,
        pickedTime.minute,
      );

      // If target time is earlier today, assume next day
      if (targetDt.isBefore(nowDt)) {
        targetDt = targetDt.add(const Duration(days: 1));
      }

      final diff = targetDt.difference(nowDt);
      if (diff.inMinutes > 0) {
        onDurationSelected(SharingDurationOption(diff));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected time must be in the future.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0A1426) : const Color(0xFF0F1F3D),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.timer_outlined,
                    color: Color(0xFF00B4D8),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share Live Location',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Choose how long friends can see your position',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Options List
            _DurationOptionCard(
              title: '30 Minutes',
              subtitle: 'Quick trips and short meetups',
              icon: Icons.timer_outlined,
              badgeText: '30 MIN',
              onTap: () => onDurationSelected(const SharingDurationOption(Duration(minutes: 30))),
            ),
            const SizedBox(height: 10),

            _DurationOptionCard(
              title: '1 Hour',
              subtitle: 'Standard commute or dinner hangout',
              icon: Icons.hourglass_bottom_rounded,
              badgeText: '1 HOUR',
              isRecommended: true,
              onTap: () => onDurationSelected(const SharingDurationOption(Duration(hours: 1))),
            ),
            const SizedBox(height: 10),

            _DurationOptionCard(
              title: '2 Hours',
              subtitle: 'Longer outdoor activities and events',
              icon: Icons.schedule_rounded,
              badgeText: '2 HOURS',
              onTap: () => onDurationSelected(const SharingDurationOption(Duration(hours: 2))),
            ),
            const SizedBox(height: 10),

            _DurationOptionCard(
              title: 'Until a Specific Time',
              subtitle: 'Pick a custom time today',
              icon: Icons.edit_calendar_rounded,
              badgeText: 'CUSTOM',
              onTap: () => _handleCustomTime(context),
            ),
            const SizedBox(height: 10),

            _DurationOptionCard(
              title: 'Until Turned Off',
              subtitle: 'Continuous sharing until manually stopped',
              icon: Icons.all_inclusive_rounded,
              badgeText: 'INDEFINITE',
              onTap: () => onDurationSelected(const SharingDurationOption(null)),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _DurationOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String badgeText;
  final bool isRecommended;
  final VoidCallback onTap;

  const _DurationOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badgeText,
    this.isRecommended = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.primary.withValues(alpha: 0.2),
        highlightColor: AppColors.primary.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isRecommended
                ? const Color(0xFF142B58).withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRecommended
                  ? const Color(0xFF00B4D8).withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.08),
              width: isRecommended ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isRecommended
                      ? const Color(0xFF00B4D8).withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isRecommended ? const Color(0xFF00B4D8) : Colors.white70,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isRecommended ? FontWeight.w700 : FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        if (isRecommended) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00B4D8).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'POPULAR',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00B4D8),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
