import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/avatar_presets.dart';
import '../../models/connection_model.dart';
import '../../models/group_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connection_provider.dart';
import '../../services/database_service.dart';
import 'chat_screen.dart';
import 'create_group_screen.dart';
import 'group_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  final int initialTabIndex;

  const ChatListScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final connectionProvider = context.watch<ConnectionProvider>();
    final currentUid = authProvider.user?.uid ?? '';
    final connections = connectionProvider.connections;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats & Groups'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text('Direct (${connections.length})'),
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.groups_rounded, size: 18),
                  SizedBox(width: 6),
                  Text('Groups'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Direct 1-to-1 Chats
          connections.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 64,
                        color: AppColors.textSecondary.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No direct chats yet',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Add friends from Connections to start chatting!',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: connections.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 70),
                  itemBuilder: (context, index) {
                    final ConnectionUser friend = connections[index];

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        child: Text(
                          friend.name.isNotEmpty ? friend.name[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      title: Text(
                        friend.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      subtitle: Text(
                        '@${friend.username}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              peerUid: friend.uid,
                              peerName: friend.name,
                              peerUsername: friend.username,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

          // Tab 2: Group Chats
          StreamBuilder<List<GroupModel>>(
            stream: _databaseService.listenToUserGroups(currentUid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final groups = snapshot.data ?? [];

              if (groups.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.groups_outlined,
                        size: 64,
                        color: AppColors.textSecondary.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No groups yet',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Create a group to chat with multiple friends together!',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.group_add_rounded, size: 18),
                        label: const Text('Create Group'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: groups.length,
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 70),
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return _GroupTile(
                    group: group,
                    currentUid: currentUid,
                    databaseService: _databaseService,
                  );
                },
              );
            },
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.group_add_rounded),
              label: const Text('New Group', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                );
              },
            )
          : null,
    );
  }
}

class _GroupTile extends StatelessWidget {
  final GroupModel group;
  final String currentUid;
  final DatabaseService databaseService;

  const _GroupTile({
    required this.group,
    required this.currentUid,
    required this.databaseService,
  });

  @override
  Widget build(BuildContext context) {
    final preset = AvatarPresets.getPreset(group.avatarPresetIndex);

    final timeStr = group.lastMessageTimestamp != null
        ? DateFormat('hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(group.lastMessageTimestamp!))
        : '';

    return StreamBuilder<int?>(
      stream: databaseService.listenToGroupLastRead(
        groupId: group.id,
        uid: currentUid,
      ),
      builder: (context, readSnapshot) {
        final lastReadTimestamp = readSnapshot.data;
        final bool isUnread = group.lastMessageTimestamp != null &&
            (lastReadTimestamp == null || group.lastMessageTimestamp! > lastReadTimestamp) &&
            group.lastMessageSenderId != currentUid;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: preset.gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(preset.icon, size: 22, color: Colors.white),
                ),
              ),
              if (isUnread)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  group.name,
                  style: TextStyle(
                    fontWeight: isUnread ? FontWeight.w900 : FontWeight.bold,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (timeStr.isNotEmpty)
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                    color: isUnread ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          subtitle: Row(
            children: [
              Expanded(
                child: Text(
                  group.lastMessageText != null
                      ? '${group.lastMessageSenderName != null ? '${group.lastMessageSenderName}: ' : ''}${group.lastMessageText}'
                      : '${group.memberCount} members',
                  style: TextStyle(
                    color: isUnread
                        ? AppColors.textPrimary
                        : (group.lastMessageText != null ? AppColors.textSecondary : AppColors.primary),
                    fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isUnread ? AppColors.primary.withValues(alpha: 0.12) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${group.memberCount}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isUnread ? AppColors.primary : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GroupChatScreen(group: group),
              ),
            );
          },
        );
      },
    );
  }
}
