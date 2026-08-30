import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/avatar_presets.dart';
import '../../models/group_location_session_model.dart';
import '../../models/group_model.dart';
import '../../models/group_session_participant_model.dart';
import '../../models/location_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../widgets/app_map_tile_layer.dart';
import '../../widgets/golden_pin_marker.dart';

class GroupMapScreen extends StatefulWidget {
  final GroupModel group;
  final GroupLocationSessionModel? initialSession;

  const GroupMapScreen({
    super.key,
    required this.group,
    this.initialSession,
  });

  @override
  State<GroupMapScreen> createState() => _GroupMapScreenState();
}

class _GroupMapScreenState extends State<GroupMapScreen> {
  final MapController _mapController = MapController();
  final DatabaseService _databaseService = DatabaseService();
  final LocationService _locationService = LocationService();

  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<GroupLocationSessionModel?>? _sessionSubscription;
  StreamSubscription<List<GroupSessionParticipantModel>>? _participantsSubscription;

  bool _hasInitialCentered = false;
  bool _isBroadcasting = false;
  int _lastBroadcastTimestamp = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initInitialCamera();
      _initSessionListeners();
    });
  }

  void _initInitialCamera() async {
    final locationProvider = context.read<LocationProvider>();
    final currentPos = locationProvider.currentPosition;
    if (currentPos != null) {
      _mapController.move(LatLng(currentPos.latitude, currentPos.longitude), 15.0);
      _hasInitialCentered = true;
    } else {
      final pos = await _locationService.getCurrentPosition();
      if (pos != null && mounted) {
        _mapController.move(LatLng(pos.latitude, pos.longitude), 15.0);
        _hasInitialCentered = true;
      }
    }
  }

  void _initSessionListeners() {
    final currentUid = context.read<AuthProvider>().user?.uid;
    if (currentUid == null) return;

    // Listen to active session status
    _sessionSubscription = _databaseService.listenToActiveGroupSession(widget.group.id).listen((session) {
      if (!mounted) return;
      if (session == null || !session.isActive) {
        _stopBroadcasting(currentUid);
      }
    });

    // Listen to participants list to determine if user should broadcast
    _participantsSubscription = _databaseService.listenToGroupSessionParticipants(widget.group.id).listen((participants) {
      if (!mounted) return;
      final isUserSharing = participants.any((p) => p.uid == currentUid && p.isSharing);
      if (isUserSharing) {
        _startBroadcasting(currentUid);
      } else {
        _stopBroadcasting(currentUid);
      }
    });
  }

  void _startBroadcasting(String currentUid) {
    if (_isBroadcasting) return;
    _isBroadcasting = true;

    _locationSubscription?.cancel();
    _locationSubscription = _locationService.getGroupPositionStream(distanceFilter: 15).listen((Position pos) {
      if (!mounted || !_isBroadcasting) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      // Enforce at least 10s between telemetry uploads to conserve battery & quota
      if (now - _lastBroadcastTimestamp < 10000) return;
      _lastBroadcastTimestamp = now;

      _databaseService.updateGroupLiveLocation(
        groupId: widget.group.id,
        uid: currentUid,
        latitude: pos.latitude,
        longitude: pos.longitude,
        heading: pos.heading,
        speed: pos.speed,
        accuracy: pos.accuracy,
      );

      if (!_hasInitialCentered) {
        _mapController.move(LatLng(pos.latitude, pos.longitude), 15.0);
        _hasInitialCentered = true;
      }
    });
  }

  void _stopBroadcasting(String currentUid) {
    if (!_isBroadcasting && _locationSubscription == null) return;
    _isBroadcasting = false;
    _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _sessionSubscription?.cancel();
    _participantsSubscription?.cancel();
    super.dispose();
  }

  void _recenterOnUser() {
    final locationProvider = context.read<LocationProvider>();
    final latLng = locationProvider.currentLatLng;
    if (latLng != null) {
      _mapController.move(latLng, 16.0);
    }
  }

  void _fitAllParticipants(List<LatLng> points) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 16.0);
      return;
    }
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(60.0),
      ),
    );
  }

  String _formatLastUpdated(int timestamp) {
    final diffMs = DateTime.now().millisecondsSinceEpoch - timestamp;
    if (diffMs < 30000) return 'Just now';
    if (diffMs < 60000) return '${(diffMs / 1000).round()}s ago';
    final mins = (diffMs / 60000).round();
    if (mins < 60) return '${mins}m ago';
    return '${(mins / 60).round()}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final currentUid = authProvider.user?.uid ?? '';
    final currentLatLng = locationProvider.currentLatLng;
    final now = DateTime.now().millisecondsSinceEpoch;

    return StreamBuilder<GroupLocationSessionModel?>(
      stream: _databaseService.listenToActiveGroupSession(widget.group.id),
      initialData: widget.initialSession,
      builder: (context, sessionSnapshot) {
        final activeSession = sessionSnapshot.data;
        final bool isSessionActive = activeSession != null && activeSession.isActive;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activeSession?.title ?? widget.group.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isSessionActive ? 'Live Location Session' : 'Session Ended',
                  style: TextStyle(
                    fontSize: 11,
                    color: isSessionActive ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          body: Stack(
            children: [
              StreamBuilder<List<GroupSessionParticipantModel>>(
                stream: _databaseService.listenToGroupSessionParticipants(widget.group.id),
                builder: (context, participantsSnapshot) {
                  final participants = participantsSnapshot.data ?? [];
                  final participantMap = {for (var p in participants) p.uid: p};

                  return StreamBuilder<Map<String, LocationModel>>(
                    stream: _databaseService.listenToGroupLiveLocations(widget.group.id),
                    builder: (context, locationsSnapshot) {
                      final locations = locationsSnapshot.data ?? {};

                      final List<Marker> markers = [];
                      final List<LatLng> activePoints = [];

                      // Add participant markers
                      locations.forEach((uid, loc) {
                        final participant = participantMap[uid];
                        final isMe = uid == currentUid;
                        final displayName = isMe
                            ? '${authProvider.userModel?.name ?? 'You'} (You)'
                            : (participant?.displayName ?? 'Member');

                        final isStale = (now - loc.timestamp) > 120000;
                        final point = LatLng(loc.latitude, loc.longitude);
                        activePoints.add(point);

                        markers.add(
                          Marker(
                            point: point,
                            width: 120,
                            height: 84,
                            child: Opacity(
                              opacity: isStale ? 0.55 : 1.0,
                              child: GoldenPinMarker(
                                isGlowing: !isStale,
                                label: isStale ? '$displayName • Signal Lost' : displayName,
                                travelMode: isMe ? LocationModel.modeWalking : null,
                              ),
                            ),
                          ),
                        );
                      });

                      return FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: currentLatLng ?? const LatLng(0, 0),
                          initialZoom: 15.0,
                        ),
                        children: [
                          const AppMapTileLayer(),
                          MarkerLayer(markers: markers),
                        ],
                      );
                    },
                  );
                },
              ),

              // Side Floating Controls (Auto-Fit & Recenter)
              Positioned(
                bottom: 175,
                right: 16,
                child: StreamBuilder<Map<String, LocationModel>>(
                  stream: _databaseService.listenToGroupLiveLocations(widget.group.id),
                  builder: (context, snapshot) {
                    final locations = snapshot.data ?? {};
                    final points = locations.values
                        .map((l) => LatLng(l.latitude, l.longitude))
                        .toList();

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (points.isNotEmpty) ...[
                          FloatingActionButton.small(
                            heroTag: 'group_autofit_fab',
                            backgroundColor: AppColors.cardColor(context),
                            foregroundColor: AppColors.primary,
                            tooltip: 'Fit all members on map',
                            onPressed: () => _fitAllParticipants(points),
                            child: const Icon(Icons.filter_center_focus_rounded),
                          ),
                          const SizedBox(height: 10),
                        ],
                        FloatingActionButton.small(
                          heroTag: 'group_recenter_fab',
                          backgroundColor: AppColors.cardColor(context),
                          foregroundColor: AppColors.primary,
                          tooltip: 'Recenter on my location',
                          onPressed: _recenterOnUser,
                          child: const Icon(Icons.my_location),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Horizontal Member Tray & Session Control Panel
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: StreamBuilder<List<GroupSessionParticipantModel>>(
                  stream: _databaseService.listenToGroupSessionParticipants(widget.group.id),
                  builder: (context, participantsSnapshot) {
                    final participants = participantsSnapshot.data ?? [];
                    final bool isCurrentUserSharing = participants.any((p) => p.uid == currentUid);

                    return StreamBuilder<Map<String, LocationModel>>(
                      stream: _databaseService.listenToGroupLiveLocations(widget.group.id),
                      builder: (context, locSnapshot) {
                        final locations = locSnapshot.data ?? {};

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Horizontal Participant Quick-Focus Tray
                            if (isSessionActive && participants.isNotEmpty) ...[
                              Container(
                                height: 58,
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: participants.length,
                                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final p = participants[index];
                                    final loc = locations[p.uid];
                                    final isMe = p.uid == currentUid;
                                    final preset = AvatarPresets.getPreset(p.avatarPresetIndex);
                                    final isStale = loc != null && (now - loc.timestamp) > 120000;
                                    final timeStr = loc != null ? _formatLastUpdated(loc.timestamp) : 'Joining...';

                                    return GestureDetector(
                                      onTap: () {
                                        if (loc != null) {
                                          _mapController.move(
                                            LatLng(loc.latitude, loc.longitude),
                                            16.5,
                                          );
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.cardColor(context),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: isMe
                                                ? AppColors.primary
                                                : (isStale ? Colors.amber : AppColors.cardBorderColor(context)),
                                            width: isMe ? 1.5 : 1.0,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.08),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 30,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: LinearGradient(
                                                  colors: preset.gradientColors,
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                              ),
                                              child: Center(
                                                child: Icon(preset.icon, size: 14, color: Colors.white),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  isMe ? 'You' : p.displayName,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: AppColors.textPrimaryColor(context),
                                                  ),
                                                ),
                                                Text(
                                                  timeStr,
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: isStale ? Colors.amber.shade900 : AppColors.textSecondaryColor(context),
                                                    fontWeight: isStale ? FontWeight.bold : FontWeight.normal,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],

                            // Bottom Session Status Pill
                            if (!isSessionActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.white70, size: 18),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'This location session has ended.',
                                        style: TextStyle(color: Colors.white, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.cardColor(context),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.cardBorderColor(context)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: isCurrentUserSharing ? AppColors.success : Colors.orange,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            isCurrentUserSharing ? 'You are sharing live GPS' : 'Sharing is paused for you',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          Text(
                                            '${participants.length} member(s) sharing',
                                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isCurrentUserSharing ? AppColors.error : AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () async {
                                        if (isCurrentUserSharing) {
                                          _stopBroadcasting(currentUid);
                                          await _databaseService.leaveGroupLocationSession(
                                            groupId: widget.group.id,
                                            uid: currentUid,
                                          );
                                        } else {
                                          await _databaseService.joinGroupLocationSession(
                                            groupId: widget.group.id,
                                            uid: currentUid,
                                            displayName: authProvider.userModel?.name ?? 'User',
                                            avatarPresetIndex: authProvider.userModel?.avatarPresetIndex ?? 0,
                                          );
                                          _startBroadcasting(currentUid);
                                        }
                                      },
                                      child: Text(
                                        isCurrentUserSharing ? 'Stop' : 'Share',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


