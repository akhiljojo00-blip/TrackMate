import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../widgets/consent_duration_picker.dart';

class SharingDurationOption {
  final Duration? duration; // null represents indefinite / continuous sharing
  final bool revoke;
  const SharingDurationOption(this.duration, {this.revoke = false});
}

class TimedSharingBottomSheet extends StatefulWidget {
  final bool isCurrentlySharing;

  const TimedSharingBottomSheet({
    super.key,
    required this.isCurrentlySharing,
  });

  static Future<SharingDurationOption?> show(BuildContext context, {bool isSharing = false}) {
    return showModalBottomSheet<SharingDurationOption?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => TimedSharingBottomSheet(isCurrentlySharing: isSharing),
    );
  }

  @override
  State<TimedSharingBottomSheet> createState() => _TimedSharingBottomSheetState();
}

class _TimedSharingBottomSheetState extends State<TimedSharingBottomSheet> {
  int _selectedDurationIndex = 1; // Default to 1h
  final List<Duration?> _durations = [
    const Duration(minutes: 15),
    const Duration(hours: 1),
    const Duration(hours: 8),
    null,
  ];
  final List<String> _durationLabels = ['15m', '1h', '8h', 'Until Off'];

  void _handleStartSharing() {
    final selectedDuration = _durations[_selectedDurationIndex];
    Navigator.of(context).pop(SharingDurationOption(selectedDuration));
  }

  void _handleRevokeSharing() {
    Navigator.of(context).pop(const SharingDurationOption(null, revoke: true));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.midnightBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppColors.glassBorder, width: 1),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
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
                    Icons.security_rounded,
                    color: AppColors.sapphireGlow,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location Consent',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Control who sees your position',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Duration Selector
            const Text(
              'SHARE DURATION',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white54,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            ConsentDurationPicker(
              options: _durationLabels,
              selectedIndex: _selectedDurationIndex,
              onSelected: (index) {
                setState(() {
                  _selectedDurationIndex = index;
                });
              },
            ),
            const SizedBox(height: 32),

            // Precision Selector Card (UI visual placeholder for design)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1B2B), // GlassSurface
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gps_fixed_rounded, color: AppColors.solarGold),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exact Precision',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'High accuracy GPS telemetry',
                          style: TextStyle(fontSize: 12, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: true, // Hardcoded for this mockup phase
                    onChanged: (val) {},
                    activeColor: AppColors.solarGold,
                    activeTrackColor: AppColors.solarGold.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Primary Action Buttons
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              onPressed: _handleStartSharing,
              child: Text(
                widget.isCurrentlySharing ? 'Update Consent Settings' : 'Start Sharing Location',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            if (widget.isCurrentlySharing) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.revocationCrimson,
                  side: const BorderSide(color: AppColors.revocationCrimson, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.power_settings_new_rounded),
                label: const Text(
                  'Stop Sharing Now',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: _handleRevokeSharing,
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
