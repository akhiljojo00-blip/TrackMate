import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/connection_model.dart';
import '../../models/location_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/sos_provider.dart';
import '../../models/sos_alert_model.dart';
import '../../widgets/sos_button.dart';
import '../../widgets/emergency_alert_dialog.dart';
import '../chat/chat_screen.dart';
import '../connections/connections_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  bool _hasInitialCentered = false;
  bool _isEmergencyDialogOpen = false;
  String? _activeDialogAlertUid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<ConnectionProvider>().initializeForUser(user.uid);
      }

      final locationProvider = context.read<LocationProvider>();
      final position = await locationProvider.fetchCurrentPosition();
      if (position != null && mounted) {
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          15.0,
        );
        _hasInitialCentered = true;
      }
    });
  }

  void _recenterOnUser() {
    final locationProvider = context.read<LocationProvider>();
    final latLng = locationProvider.currentLatLng;
    if (latLng != null) {
      _mapController.move(latLng, 16.0);
    } else {
      locationProvider.fetchCurrentPosition().then((pos) {
        if (pos != null && mounted) {
          _mapController.move(LatLng(pos.latitude, pos.longitude), 16.0);
        }
      });
    }
  }

  Future<void> _handleToggleSharing() async {
    final authProvider = context.read<AuthProvider>();
    final locationProvider = context.read<LocationProvider>();
    final currentUid = authProvider.user?.uid;

    if (currentUid == null) return;

    if (locationProvider.isTracking) {
      await locationProvider.stopTracking(currentUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Live location sharing stopped.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      final success = await locationProvider.startTracking(currentUid);
      if (success && mounted) {
        final latLng = locationProvider.currentLatLng;
        if (latLng != null) {
          _mapController.move(latLng, 16.0);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Live location sharing is now ACTIVE.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      } else if (locationProvider.locationError != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(locationProvider.locationError!),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showFriendDetailsSheet(ConnectionUser friend, LocationModel location, double? distanceMeters) {
    final formattedDistance = distanceMeters != null
        ? LocationProvider.formatDistance(distanceMeters)
        : 'Distance unknown';

    final updatedTime = DateTime.fromMillisecondsSinceEpoch(location.timestamp);
    final diffSec = DateTime.now().difference(updatedTime).inSeconds;
    String timeAgo;
    if (diffSec < 60) {
      timeAgo = 'Just now';
    } else if (diffSec < 3600) {
      timeAgo = '${(diffSec / 60).floor()}m ago';
    } else {
      timeAgo = '${(diffSec / 3600).floor()}h ago';
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.purple.shade600,
                      child: Text(
                        friend.name.isNotEmpty ? friend.name[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            friend.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '@${friend.username}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.navigation, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            formattedDistance,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Last updated: $timeAgo',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                      if (location.speed != null && location.speed! > 0.5)
                        Row(
                          children: [
                            const Icon(Icons.speed, size: 16, color: AppColors.accent),
                            const SizedBox(width: 4),
                            Text(
                              '${(location.speed! * 3.6).toStringAsFixed(0)} km/h',
                              style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Open Chat'),
                  onPressed: () {
                    Navigator.of(ctx).pop();
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPrivacyManagementSheet() {
    final authProvider = context.read<AuthProvider>();
    final currentUid = authProvider.user?.uid;

    if (currentUid == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Consumer2<ConnectionProvider, LocationProvider>(
          builder: (context, connProv, locProv, _) {
            final friends = connProv.connections;

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Row(
                      children: [
                        Icon(Icons.security, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Location Privacy & Sharing',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Choose which friends can view your live location when sharing is active. Revoking permission takes effect immediately.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const Divider(height: 24),
                    if (friends.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32.0),
                        child: Center(
                          child: Text(
                            'No connected friends yet.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: friends.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final friend = friends[index];
                            final isAllowed = locProv.outboundPermissions[friend.uid] ?? false;

                            return SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              secondary: CircleAvatar(
                                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                child: Text(
                                  friend.name.isNotEmpty ? friend.name[0].toUpperCase() : 'U',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(friend.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                isAllowed ? 'Allowed to view live location' : 'Sharing is blocked',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isAllowed ? AppColors.success : AppColors.textSecondary,
                                ),
                              ),
                              value: isAllowed,
                              activeThumbColor: AppColors.success,
                              onChanged: (bool enable) async {
                                await locProv.toggleFriendLocationPermission(
                                  currentUid: currentUid,
                                  friendUid: friend.uid,
                                  isAllowed: enable,
                                );
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleTriggerSos() async {
    final authProvider = context.read<AuthProvider>();
    final locationProvider = context.read<LocationProvider>();
    final sosProvider = context.read<SosProvider>();
    final currentUid = authProvider.user?.uid;
    final currentName = authProvider.userModel?.name ?? 'User';
    final currentLatLng = locationProvider.currentLatLng;

    if (currentUid != null) {
      await sosProvider.broadcastSos(
        currentUid: currentUid,
        currentName: currentName,
        currentLat: currentLatLng?.latitude,
        currentLng: currentLatLng?.longitude,
      );
    }
  }

  Future<void> _handleCancelSos() async {
    final currentUid = context.read<AuthProvider>().user?.uid;
    if (currentUid == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Emergency SOS?'),
        content: const Text(
          'Are you safe? This will immediately dismiss the active emergency beacon and notify your connections that the emergency has ended.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Active'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("I'm Safe / Cancel SOS"),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<SosProvider>().cancelSos(currentUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency SOS beacon cancelled.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final connectionProvider = context.watch<ConnectionProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final sosProvider = context.watch<SosProvider>();
    final userModel = authProvider.userModel;
    final currentUid = authProvider.user?.uid;
    final pendingRequestsCount = connectionProvider.incomingRequests.length;
    final currentLatLng = locationProvider.currentLatLng;
    final isSharing = locationProvider.isTracking;

    // Ensure connection streams are initialized for current user
    if (currentUid != null) {
      connectionProvider.initializeForUser(currentUid);
    }

    // Listen to authorized friends locations, chats, and emergency beacons
    if (currentUid != null && connectionProvider.connections.isNotEmpty) {
      locationProvider.listenToAuthorizedFriends(currentUid, connectionProvider.connections);
      context.read<ChatProvider>().listenToFriendChats(
        currentUid: currentUid,
        connections: connectionProvider.connections,
      );
      context.read<SosProvider>().listenToFriendEmergencyAlerts(
        currentUid: currentUid,
        connections: connectionProvider.connections,
      );
    }

    // Auto-center on first position if not centered yet
    if (!_hasInitialCentered && currentLatLng != null) {
      _hasInitialCentered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(currentLatLng, 15.0);
      });
    }

    // Check for incoming primary emergency alert
    final incomingAlert = sosProvider.primaryActiveIncomingAlert;
    if (incomingAlert != null && !_isEmergencyDialogOpen && _activeDialogAlertUid != incomingAlert.senderUid) {
      _activeDialogAlertUid = incomingAlert.senderUid;
      _isEmergencyDialogOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => EmergencyAlertDialog(
            alert: incomingAlert,
            onViewOnMap: (coords) {
              _mapController.move(coords, 16.0);
            },
            onDismiss: () {
              context.read<SosProvider>().dismissDialogForAlert(incomingAlert.senderUid);
            },
          ),
        ).then((_) {
          _isEmergencyDialogOpen = false;
          _activeDialogAlertUid = null;
        });
      });
    } else if (_isEmergencyDialogOpen && _activeDialogAlertUid != null && !sosProvider.activeFriendAlerts.containsKey(_activeDialogAlertUid)) {
      // Emergency resolved / cancelled by friend!
      _activeDialogAlertUid = null;
      _isEmergencyDialogOpen = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).maybePop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('The emergency alert has been resolved/cancelled by your connection.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      });
    }

    // Build markers for live friends
    final activeFriendLocations = locationProvider.activeFriendLocations;
    final friendDistances = locationProvider.friendDistances;
    final friendMarkers = <Marker>[];

    for (final friend in connectionProvider.connections) {
      final friendLoc = activeFriendLocations[friend.uid];
      if (friendLoc != null) {
        final distance = friendDistances[friend.uid];
        friendMarkers.add(
          Marker(
            point: LatLng(friendLoc.latitude, friendLoc.longitude),
            width: 70,
            height: 70,
            child: GestureDetector(
              onTap: () => _showFriendDetailsSheet(friend, friendLoc, distance),
              child: _FriendLocationMarker(
                name: friend.name,
                distanceText: distance != null ? LocationProvider.formatDistance(distance) : null,
              ),
            ),
          ),
        );
      }
    }

    // Build emergency markers for active friend distress beacons
    final emergencyMarkers = <Marker>[];
    for (final alert in sosProvider.activeFriendAlerts.values) {
      emergencyMarkers.add(
        Marker(
          point: LatLng(alert.latitude, alert.longitude),
          width: 80,
          height: 80,
          child: GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => EmergencyAlertDialog(
                  alert: alert,
                  onViewOnMap: (coords) => _mapController.move(coords, 16.0),
                ),
              );
            },
            child: _EmergencyLocationMarker(alert: alert),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trackmate'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shield_outlined),
            tooltip: 'Manage Sharing',
            onPressed: _showPrivacyManagementSheet,
          ),
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
                final uid = authProvider.user?.uid;
                if (uid != null && locationProvider.isTracking) {
                  await locationProvider.stopTracking(uid);
                }
                locationProvider.clearAllFriendSubscriptions();
                if (context.mounted) {
                  context.read<ConnectionProvider>().clear();
                  await context.read<AuthProvider>().signOut();
                }
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
              leading: const Icon(Icons.security),
              title: const Text('Privacy & Sharing'),
              subtitle: const Text('Manage friend permissions'),
              onTap: () {
                Navigator.of(context).pop();
                _showPrivacyManagementSheet();
              },
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
                final uid = authProvider.user?.uid;
                if (uid != null && locationProvider.isTracking) {
                  await locationProvider.stopTracking(uid);
                }
                locationProvider.clearAllFriendSubscriptions();
                if (context.mounted) {
                  context.read<ConnectionProvider>().clear();
                  await context.read<AuthProvider>().signOut();
                }
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: currentLatLng ?? const LatLng(0, 0),
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.trackmate.app',
              ),
              MarkerLayer(
                markers: [
                  if (currentLatLng != null)
                    Marker(
                      point: currentLatLng,
                      width: 60,
                      height: 60,
                      child: _UserLocationMarker(
                        isSharing: isSharing,
                        initials: (userModel?.name.isNotEmpty == true)
                            ? userModel!.name[0].toUpperCase()
                            : 'ME',
                      ),
                    ),
                  ...friendMarkers,
                  ...emergencyMarkers,
                ],
              ),
            ],
          ),

          // Top Emergency Banner or Normal Status Pill
          if (sosProvider.isTriggered)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'EMERGENCY SOS ACTIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'Broadcasting live GPS${sosProvider.activeAlert?.batteryLevel != null ? ' & ${sosProvider.activeAlert!.batteryLevel}% battery' : ''} to connections.',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _handleCancelSos,
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSharing
                        ? AppColors.success.withValues(alpha: 0.9)
                        : Colors.grey.shade800.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSharing ? Icons.radar : Icons.location_off_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isSharing ? 'Live Sharing ACTIVE' : 'Sharing is OFF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      if (activeFriendLocations.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${activeFriendLocations.length} friend${activeFriendLocations.length > 1 ? 's' : ''} visible',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          // Left Controls (Emergency SOS Button with 3-second hold guard)
          Positioned(
            left: 16,
            bottom: 85,
            child: SosButton(
              onTriggered: _handleTriggerSos,
            ),
          ),

          // Right Controls (Recenter Button)
          Positioned(
            right: 16,
            bottom: 90,
            child: FloatingActionButton.small(
              heroTag: 'recenter_fab',
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.textPrimary,
              onPressed: _recenterOnUser,
              tooltip: 'My Location',
              child: const Icon(Icons.my_location),
            ),
          ),

          // Bottom Sharing Toggle Action Bar
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSharing ? AppColors.error : AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              icon: Icon(isSharing ? Icons.stop_circle_outlined : Icons.play_circle_outline),
              label: Text(
                isSharing ? 'Stop Sharing Location' : 'Start Sharing Location',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: locationProvider.isLoading ? null : _handleToggleSharing,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserLocationMarker extends StatelessWidget {
  final bool isSharing;
  final String initials;

  const _UserLocationMarker({
    required this.isSharing,
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    final markerColor = isSharing ? AppColors.success : AppColors.primary;

    return Stack(
      alignment: Alignment.center,
      children: [
        if (isSharing)
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: markerColor.withValues(alpha: 0.25),
            ),
          ),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: markerColor,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FriendLocationMarker extends StatelessWidget {
  final String name;
  final String? distanceText;

  const _FriendLocationMarker({
    required this.name,
    this.distanceText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.purple.shade600,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        if (distanceText != null)
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              distanceText!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _EmergencyLocationMarker extends StatelessWidget {
  final SosAlertModel alert;

  const _EmergencyLocationMarker({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.error,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.6),
                blurRadius: 10,
                spreadRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.warning_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
              ),
            ],
          ),
          child: Text(
            'SOS: ${alert.senderName}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

