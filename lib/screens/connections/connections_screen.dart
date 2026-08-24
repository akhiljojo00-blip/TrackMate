import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/chat_provider.dart';
import '../chat/chat_screen.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<ConnectionProvider>().initializeForUser(user.uid);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  UserModel? _getCurrentUser(AuthProvider authProvider) {
    final userModel = authProvider.userModel;
    if (userModel != null) return userModel;

    final user = authProvider.user;
    if (user != null) {
      final fallbackUsername = (user.email?.split('@').first ?? 'user').toLowerCase().trim();
      final fallbackName = user.displayName?.isNotEmpty == true ? user.displayName! : fallbackUsername;
      return UserModel(
        uid: user.uid,
        name: fallbackName,
        username: fallbackUsername,
        email: user.email ?? '',
        isLocationSharing: false,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final connectionProvider = context.watch<ConnectionProvider>();
    final user = authProvider.user;

    if (user != null) {
      connectionProvider.initializeForUser(user.uid);
      if (connectionProvider.connections.isNotEmpty) {
        context.read<ChatProvider>().listenToFriendChats(
          currentUid: user.uid,
          connections: connectionProvider.connections,
        );
      }
    }

    final pendingCount = connectionProvider.incomingRequests.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connections'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: [
            const Tab(
              icon: Icon(Icons.search),
              text: 'Discover',
            ),
            Tab(
              icon: const Icon(Icons.people),
              text: 'Friends (${connectionProvider.connections.length})',
            ),
            Tab(
              icon: Badge(
                isLabelVisible: pendingCount > 0,
                label: Text('$pendingCount'),
                child: const Icon(Icons.person_add),
              ),
              text: 'Requests',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDiscoverTab(),
          _buildFriendsTab(),
          _buildRequestsTab(),
        ],
      ),
    );
  }

  Widget _buildDiscoverTab() {
    final authProvider = context.watch<AuthProvider>();
    final connectionProvider = context.watch<ConnectionProvider>();
    final currentUser = _getCurrentUser(authProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search users by @username...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        connectionProvider.clearSearch();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppColors.surface,
            ),
            onChanged: (val) {
              if (currentUser != null) {
                connectionProvider.searchUsers(val, currentUser.uid);
              }
            },
          ),
        ),
        if (connectionProvider.isSearching)
          const Expanded(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (connectionProvider.searchError != null)
          Expanded(
            child: Center(
              child: Text(
                connectionProvider.searchError!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          )
        else if (_searchController.text.trim().isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'Type a username above to find and connect with friends.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else if (connectionProvider.searchResults.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'No users found matching this username.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: connectionProvider.searchResults.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final targetUser = connectionProvider.searchResults[index];
                final isConnected = connectionProvider.isConnectedWith(targetUser.uid);
                final isPending = connectionProvider.isRequestPending(targetUser.uid);

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      targetUser.name.isNotEmpty ? targetUser.name[0].toUpperCase() : 'U',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(targetUser.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('@${targetUser.username}'),
                  trailing: isConnected
                      ? const Chip(
                          label: Text('Friends', style: TextStyle(fontSize: 12, color: AppColors.success)),
                          backgroundColor: Color(0xFFE8F5E9),
                        )
                      : isPending
                          ? OutlinedButton(
                              onPressed: () {
                                if (currentUser != null) {
                                  connectionProvider.cancelSentRequest(
                                    currentUid: currentUser.uid,
                                    targetUid: targetUser.uid,
                                  );
                                }
                              },
                              child: const Text('Requested'),
                            )
                          : ElevatedButton.icon(
                              icon: const Icon(Icons.person_add, size: 16),
                              label: const Text('Connect'),
                              onPressed: () async {
                                if (currentUser != null) {
                                  await connectionProvider.sendRequest(
                                    sender: currentUser,
                                    targetUid: targetUser.uid,
                                  );
                                }
                              },
                            ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFriendsTab() {
    final connectionProvider = context.watch<ConnectionProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currentUid = authProvider.user?.uid;
    final friends = connectionProvider.connections;

    if (friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            const Text(
              'No connections yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Discover friends using the search tab above.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _tabController.animateTo(0),
              child: const Text('Find Friends'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: friends.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final friend = friends[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.primary,
            child: Text(
              friend.name.isNotEmpty ? friend.name[0].toUpperCase() : 'U',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(friend.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('@${friend.username}'),
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
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'chat') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      peerUid: friend.uid,
                      peerName: friend.name,
                      peerUsername: friend.username,
                    ),
                  ),
                );
              } else if (value == 'remove' && currentUid != null) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Remove Connection'),
                    content: Text('Are you sure you want to unfriend ${friend.name}?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Remove', style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await connectionProvider.removeFriend(
                    currentUid: currentUid,
                    targetUid: friend.uid,
                  );
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'chat',
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 18),
                    SizedBox(width: 8),
                    Text('Message'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(Icons.person_remove_outlined, color: AppColors.error, size: 18),
                    SizedBox(width: 8),
                    Text('Unfriend', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestsTab() {
    final connectionProvider = context.watch<ConnectionProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currentUser = _getCurrentUser(authProvider);
    final requests = connectionProvider.incomingRequests;

    if (requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mark_email_read_outlined, size: 64, color: AppColors.textSecondary),
            SizedBox(height: 12),
            Text(
              'No pending requests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            SizedBox(height: 6),
            Text(
              'You are all caught up!',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: requests.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final request = requests[index];

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.accent.withValues(alpha: 0.2),
            child: Text(
              request.senderName.isNotEmpty ? request.senderName[0].toUpperCase() : 'U',
              style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(request.senderName, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('@${request.senderUsername} sent you a connection request'),
          isThreeLine: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.check_circle, color: AppColors.success),
                tooltip: 'Accept',
                onPressed: () async {
                  if (currentUser != null) {
                    await connectionProvider.acceptRequest(
                      currentUser: currentUser,
                      request: request,
                    );
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.cancel, color: AppColors.error),
                tooltip: 'Decline',
                onPressed: () async {
                  if (currentUser != null) {
                    await connectionProvider.declineRequest(
                      currentUser: currentUser,
                      request: request,
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
