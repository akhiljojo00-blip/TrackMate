import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/sos_provider.dart';
import '../../widgets/glass_card.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final connectionProvider = context.watch<ConnectionProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final sosProvider = context.watch<SosProvider>();

    final userName = authProvider.userModel?.name ?? authProvider.user?.displayName ?? 'You';
    final connections = connectionProvider.connections;
    final incomingRequests = connectionProvider.incomingRequests;
    final isTracking = locationProvider.isTracking;
    final sosTriggered = sosProvider.isTriggered;

    // Build a live activity list from current provider state
    final List<_ActivityItem> activityItems = [];

    // SOS active takes highest priority
    if (sosTriggered) {
      activityItems.add(_ActivityItem(
        title: 'SOS BEACON ACTIVE',
        subtitle: 'Broadcasting live GPS to all connections',
        iconData: Icons.sos_rounded,
        iconColor: AppColors.revocationCrimson,
        isUrgent: true,
      ));
    }

    // Incoming friend requests
    for (final req in incomingRequests.take(3)) {
      activityItems.add(_ActivityItem(
        title: '${req.senderName} sent a friend request',
        subtitle: 'Tap Connections to accept or decline',
        iconData: Icons.person_add_rounded,
        iconColor: AppColors.primary,
      ));
    }

    // Location sharing status
    if (isTracking) {
      activityItems.add(_ActivityItem(
        title: '$userName is sharing location',
        subtitle: 'Live GPS broadcast is active',
        iconData: Icons.my_location_rounded,
        iconColor: AppColors.broadcastLive,
      ));
    }

    // Active SOS alerts from friends
    for (final alert in sosProvider.activeFriendAlerts.values) {
      activityItems.add(_ActivityItem(
        title: 'SOS from ${alert.senderName}',
        subtitle: 'Emergency beacon active — check map',
        iconData: Icons.warning_rounded,
        iconColor: AppColors.revocationCrimson,
        isUrgent: true,
      ));
    }

    // Connections summary
    if (connections.isNotEmpty) {
      activityItems.add(_ActivityItem(
        title: 'You have ${connections.length} active friend${connections.length == 1 ? '' : 's'}',
        subtitle: 'Tap Map to see who\'s sharing location',
        iconData: Icons.people_rounded,
        iconColor: AppColors.solarGold,
      ));
    }

    // Empty state or no live events
    if (activityItems.isEmpty) {
      activityItems.add(_ActivityItem(
        title: 'All Clear',
        subtitle: 'No active events right now. Start sharing your location or connect with friends.',
        iconData: Icons.check_circle_outline_rounded,
        iconColor: AppColors.broadcastLive,
      ));
    }

    return Scaffold(
      backgroundColor: AppColors.midnightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Activity',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.glassSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  children: [
                    Text(
                      'Live',
                      style: TextStyle(
                        color: isTracking || sosTriggered
                            ? AppColors.broadcastLive
                            : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isTracking || sosTriggered
                            ? AppColors.broadcastLive
                            : Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: activityItems.length,
          itemBuilder: (context, index) {
            final item = activityItems[index];
            return _ActivityTile(item: item);
          },
        ),
      ),
    );
  }
}

class _ActivityItem {
  final String title;
  final String? subtitle;
  final IconData iconData;
  final Color iconColor;
  final bool isUrgent;

  const _ActivityItem({
    required this.title,
    this.subtitle,
    required this.iconData,
    required this.iconColor,
    this.isUrgent = false,
  });
}

class _ActivityTile extends StatelessWidget {
  final _ActivityItem item;

  const _ActivityTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        child: Row(
          crossAxisAlignment: item.subtitle != null
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.iconColor.withValues(alpha: 0.1),
                border: Border.all(
                  color: item.iconColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: item.iconColor.withValues(alpha: 0.15),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  item.iconData,
                  color: item.iconColor,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            color: item.isUrgent
                                ? AppColors.revocationCrimson
                                : Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (item.isUrgent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.revocationCrimson
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.revocationCrimson
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            'URGENT',
                            style: TextStyle(
                              color: AppColors.revocationCrimson,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle!,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
