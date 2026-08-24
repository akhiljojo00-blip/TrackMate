import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../constants/app_colors.dart';
import '../models/sos_alert_model.dart';

class EmergencyAlertDialog extends StatelessWidget {
  final SosAlertModel alert;
  final void Function(LatLng coordinates)? onViewOnMap;
  final VoidCallback? onDismiss;

  const EmergencyAlertDialog({
    super.key,
    required this.alert,
    this.onViewOnMap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('hh:mm a').format(
      DateTime.fromMillisecondsSinceEpoch(alert.timestamp),
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 16,
      backgroundColor: AppColors.surface,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.error, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glowing Warning Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.error,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'EMERGENCY SOS BEACON',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${alert.senderName} is requesting emergency assistance!',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Telemetry Badges
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (alert.batteryLevel != null)
                    Row(
                      children: [
                        Icon(
                          alert.batteryLevel! <= 20
                              ? Icons.battery_alert_rounded
                              : Icons.battery_charging_full_rounded,
                          color: alert.batteryLevel! <= 20 ? AppColors.error : AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${alert.batteryLevel}% battery',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, color: AppColors.textSecondary, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        timeStr,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onDismiss?.call();
                    },
                    child: const Text('Dismiss'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                    ),
                    icon: const Icon(Icons.pin_drop_rounded, size: 18),
                    label: const Text('View on Map', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onViewOnMap?.call(LatLng(alert.latitude, alert.longitude));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
