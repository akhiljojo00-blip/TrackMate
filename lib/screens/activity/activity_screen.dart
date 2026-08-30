import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../widgets/glass_card.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                child: const Row(
                  children: [
                    Text(
                      'All',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            _ActivityTile(
              title: 'Akhil started sharing location',
              time: '10:30 AM',
              iconData: Icons.my_location_rounded,
              iconColor: AppColors.broadcastLive,
            ),
            _ActivityTile(
              title: 'Rahul accepted your request',
              time: '09:45 AM',
              iconData: Icons.person_add_alt_1_rounded,
              iconColor: AppColors.primary,
            ),
            _ActivityTile(
              title: 'College Friends',
              subtitle: 'New message',
              time: '09:30 AM',
              iconData: Icons.shield_rounded,
              iconColor: AppColors.solarGold,
            ),
            _ActivityTile(
              title: 'Safe Zone alert: Home',
              subtitle: 'You entered safe zone',
              time: '08:15 AM',
              iconData: Icons.location_on_rounded,
              iconColor: AppColors.broadcastLive,
            ),
            _ActivityTile(
              title: 'SOS alert resolved',
              time: '07:10 AM',
              iconData: Icons.favorite_rounded, // or health_and_safety
              iconColor: AppColors.revocationCrimson,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String time;
  final IconData iconData;
  final Color iconColor;

  const _ActivityTile({
    required this.title,
    this.subtitle,
    required this.time,
    required this.iconData,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        child: Row(
          crossAxisAlignment: subtitle != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withValues(alpha: 0.1),
                border: Border.all(color: iconColor.withValues(alpha: 0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.15),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  iconData,
                  color: iconColor,
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
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ]
                ],
              ),
            ),
            
            // Trailing Time (only if subtitle exists, based on layout)
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Text(
                  time,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
