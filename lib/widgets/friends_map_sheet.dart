import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../constants/app_colors.dart';
import '../models/connection_model.dart';
import '../models/location_model.dart';
import '../providers/location_provider.dart';

class FriendsMapSheet extends StatelessWidget {
  final List<ConnectionUser> connections;
  final Map<String, LocationModel> activeFriendLocations;
  final Map<String, double> friendDistances;
  final void Function(LatLng coordinates, String friendName) onSelectFriend;
  final void Function(ConnectionUser friend) onOpenChat;
  final void Function(String friendName) onLocationUnavailable;

  const FriendsMapSheet({
    super.key,
    required this.connections,
    required this.activeFriendLocations,
    required this.friendDistances,
    required this.onSelectFriend,
    required this.onOpenChat,
    required this.onLocationUnavailable,
  });

  @override
  Widget build(BuildContext context) {
    if (connections.isEmpty) {
      return Container(
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.people_outline, color: AppColors.textSecondary, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No connections yet • Add friends in Connections tab',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 76,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: connections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final friend = connections[index];
          final friendLoc = activeFriendLocations[friend.uid];
          final isLive = friendLoc != null;
          final distance = friendDistances[friend.uid];

          return Container(
            width: 210,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isLive
                    ? AppColors.success.withValues(alpha: 0.4)
                    : Colors.grey.withValues(alpha: 0.2),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  if (isLive) {
                    onSelectFriend(
                      LatLng(friendLoc.latitude, friendLoc.longitude),
                      friend.name,
                    );
                  } else {
                    onLocationUnavailable(friend.name);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      // Avatar with Live indicator badge
                      Stack(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isLive ? Colors.purple.shade600 : Colors.grey.shade400,
                            ),
                            child: Center(
                              child: Text(
                                friend.name.isNotEmpty ? friend.name[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isLive ? AppColors.success : Colors.grey.shade500,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),

                      // Friend Name & Status
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              friend.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isLive
                                  ? (distance != null
                                      ? 'Live • ${LocationProvider.formatDistance(distance)}'
                                      : 'Sharing Live')
                                  : 'Location Off',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isLive ? FontWeight.w600 : FontWeight.normal,
                                color: isLive ? AppColors.success : AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Quick Chat Shortcut Button
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        iconSize: 20,
                        color: AppColors.primary,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        tooltip: 'Message ${friend.name}',
                        onPressed: () => onOpenChat(friend),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
