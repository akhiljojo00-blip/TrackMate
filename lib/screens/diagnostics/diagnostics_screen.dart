import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/geofence_service.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Periodic refresh every second to update tracking timer duration smoothly
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  static String _formatDuration(Duration? duration) {
    if (duration == null) return 'Not tracking';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<LocationProvider>();
    final connectivityProvider = context.watch<ConnectivityProvider?>();
    final isOnline = connectivityProvider?.isConnected ?? true;
    final isTracking = locationProvider.isTracking;
    final position = locationProvider.currentPosition;
    final geofenceService = GeofenceService();
    final activeGeofences = geofenceService.activeGeofenceCount;

    final rawFixes = locationProvider.rawFixCount;
    final syncDispatches = locationProvider.syncDispatchCount;
    final savingsPercent = locationProvider.throttlingSavingsPercent;
    final durationText = _formatDuration(locationProvider.trackingDuration);

    final outboundCount = locationProvider.outboundPermissions.values.where((p) => p).length;
    final inboundCount = locationProvider.activeFriendLocations.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics & Telemetry'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. GPS & Sensor Telemetry Card
          _buildCard(
            context: context,
            title: 'GPS & Sensor Telemetry',
            icon: Icons.gps_fixed_rounded,
            iconColor: isTracking ? AppColors.success : AppColors.primary,
            children: [
              _buildMetricRow(
                context: context,
                label: 'Broadcast Status',
                value: isTracking ? 'Active (Live)' : 'Idle (Off)',
                valueColor: isTracking ? AppColors.success : AppColors.textSecondaryColor(context),
                leadingBadge: Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isTracking ? AppColors.success : Colors.grey,
                  ),
                ),
              ),
              const Divider(height: 16),
              _buildMetricRow(
                context: context,
                label: 'Sensor Accuracy',
                value: position != null ? '±${position.accuracy.toStringAsFixed(1)} m' : '—',
              ),
              const Divider(height: 16),
              _buildMetricRow(
                context: context,
                label: 'Ground Speed',
                value: position != null ? '${(position.speed * 3.6).toStringAsFixed(1)} km/h' : '—',
              ),
              const Divider(height: 16),
              _buildMetricRow(
                context: context,
                label: 'Bearing / Heading',
                value: position != null ? '${position.heading.toStringAsFixed(0)}°' : '—',
              ),
              const Divider(height: 16),
              _buildMetricRow(
                context: context,
                label: 'Altitude',
                value: position != null ? '${position.altitude.toStringAsFixed(1)} m' : '—',
              ),
              const Divider(height: 16),
              _buildMetricRow(
                context: context,
                label: 'Session Duration',
                value: durationText,
                valueColor: isTracking ? AppColors.primary : AppColors.textSecondaryColor(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2. Battery & Bandwidth Saver Card
          _buildCard(
            context: context,
            title: 'Battery & Bandwidth Optimization',
            icon: Icons.battery_charging_full_rounded,
            iconColor: AppColors.success,
            children: [
              _buildMetricRow(
                context: context,
                label: 'Raw Hardware Fixes',
                value: '$rawFixes fixes',
              ),
              const Divider(height: 16),
              _buildMetricRow(
                context: context,
                label: 'Cloud Sync Dispatches',
                value: '$syncDispatches writes',
              ),
              const Divider(height: 16),
              _buildMetricRow(
                context: context,
                label: 'Network Savings',
                value: '${savingsPercent.toStringAsFixed(1)}%',
                valueColor: AppColors.success,
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, size: 16, color: AppColors.success),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Throttled: Min 3s interval or 5m displacement',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3. Privacy & Safe Zone Matrix Card
          _buildCard(
            context: context,
            title: 'Privacy & Safe Zone Matrix',
            icon: Icons.security_rounded,
            iconColor: Colors.deepPurple,
            children: [
              _buildMetricRow(
                context: context,
                label: 'Active Safe Zones',
                value: '$activeGeofences active',
                valueColor: activeGeofences > 0 ? AppColors.primary : AppColors.textSecondaryColor(context),
              ),
              const Divider(height: 16),
              _buildMetricRow(
                context: context,
                label: 'Outbound Visibility',
                value: '$outboundCount friends permitted',
              ),
              const Divider(height: 16),
              _buildMetricRow(
                context: context,
                label: 'Inbound Live Peers',
                value: '$inboundCount friends live',
              ),
              const SizedBox(height: 8),
              Text(
                '• 100% on-device geofence evaluation with zero external function overhead.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondaryColor(context)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4. Network Link Card
          _buildCard(
            context: context,
            title: 'Network & Cloud Database',
            icon: Icons.cloud_done_rounded,
            iconColor: isOnline ? AppColors.primary : Colors.amber.shade900,
            children: [
              _buildMetricRow(
                context: context,
                label: 'Realtime Database',
                value: isOnline ? 'Connected (Live)' : 'Offline (Cached)',
                valueColor: isOnline ? AppColors.success : Colors.amber.shade900,
                leadingBadge: Icon(
                  isOnline ? Icons.check_circle : Icons.offline_bolt_rounded,
                  size: 14,
                  color: isOnline ? AppColors.success : Colors.amber.shade900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isOnline
                    ? 'All sync pipelines operating with low-latency WebSocket connection.'
                    : 'Writes queued in local SQLite/RTDB cache; will sync upon reconnect.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondaryColor(context)),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textPrimaryColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildMetricRow({
    required BuildContext context,
    required String label,
    required String value,
    Color? valueColor,
    Widget? leadingBadge,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondaryColor(context),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ?leadingBadge,
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: valueColor ?? AppColors.textPrimaryColor(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
