import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../map/map_screen.dart';
import '../chat/chat_list_screen.dart';
import '../activity/activity_screen.dart';
import '../profile/profile_screen.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const MapScreen(),
    const ChatListScreen(initialTabIndex: 0),
    const ChatListScreen(initialTabIndex: 1),
    const ActivityScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnightBackground,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.midnightBackground,
            border: Border(
              top: BorderSide(color: AppColors.glassBorder, width: 1),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppColors.midnightBackground,
            selectedItemColor: AppColors.solarGold,
            unselectedItemColor: Colors.white54,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
            items: [
              _buildItem(Icons.map_rounded, 'Map', 0),
              _buildItem(Icons.chat_bubble_outline_rounded, 'Chats', 1),
              _buildItem(Icons.people_outline_rounded, 'Groups', 2),
              _buildItem(Icons.notifications_none_rounded, 'Activity', 3),
              _buildItem(Icons.person_outline_rounded, 'Profile', 4),
            ],
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return BottomNavigationBarItem(
      icon: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(8),
        decoration: isSelected
            ? BoxDecoration(
                color: AppColors.solarGold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.solarGold.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              )
            : null,
        child: Icon(
          icon,
          size: 24,
          color: isSelected ? AppColors.solarGold : Colors.white54,
        ),
      ),
      label: label,
    );
  }
}

