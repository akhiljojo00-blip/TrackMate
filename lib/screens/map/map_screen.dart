import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connection_provider.dart';
import '../connections/connections_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<ConnectionProvider>().initializeForUser(user.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final connectionProvider = context.watch<ConnectionProvider>();
    final userModel = authProvider.userModel;
    final pendingRequestsCount = connectionProvider.incomingRequests.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trackmate'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: pendingRequestsCount > 0,
              label: Text('$pendingRequestsCount'),
              child: const Icon(Icons.people_outline),
            ),
            tooltip: 'Connections',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ConnectionsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                context.read<ConnectionProvider>().clear();
                await context.read<AuthProvider>().signOut();
              }
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppColors.primary),
              accountName: Text(userModel?.name ?? 'User'),
              accountEmail: Text(userModel?.email ?? authProvider.user?.email ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  (userModel?.name.isNotEmpty == true)
                      ? userModel!.name[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(fontSize: 24.0, color: AppColors.primary),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Live Map'),
              selected: true,
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              leading: Badge(
                isLabelVisible: pendingRequestsCount > 0,
                label: Text('$pendingRequestsCount'),
                child: const Icon(Icons.people),
              ),
              title: const Text('Connections'),
              subtitle: Text('${connectionProvider.connections.length} friends'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ConnectionsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              subtitle: Text('@${userModel?.username ?? ''}'),
              onTap: () => Navigator.of(context).pop(),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
              onTap: () async {
                Navigator.of(context).pop();
                context.read<ConnectionProvider>().clear();
                await context.read<AuthProvider>().signOut();
              },
            ),
          ],
        ),
      ),
      body: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(0, 0),
          initialZoom: 13.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.trackmate.app',
          ),
        ],
      ),
    );
  }
}
