import 'dart:async';
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
  bool _hasInitialCentered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLiveTracking();
    });
  }

  void _initLiveTracking() async {
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

    _locationSubscription = _locationService.getPositionStream().listen((Position pos) {
      if (mounted) {
        final authProvider = context.read<AuthProvider>();
        final currentUid = authProvider.user?.uid;
        if (currentUid != null) {
          _databaseService.updateGroupLiveLocation(
            groupId: widget.group.id,
            uid: currentUid,
            latitude: pos.latitude,
            longitude: pos.longitude,
            heading: pos.heading,
            speed: pos.speed,
            accuracy: pos.accuracy,
          );
        }

        if (!_hasInitialCentered) {
          _mapController.move(LatLng(pos.latitude, pos.longitude), 15.0);
          _hasInitialCentered = true;
        }
      }
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  void _recenterOnUser() {
    final locationProvider = context.read<LocationProvider>();
    final latLng = locationProvider.currentLatLng;
    if (latLng != null) {
      _mapController.move(latLng, 16.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final currentUid = authProvider.user?.uid ?? '';
    final currentLatLng = locationProvider.currentLatLng;

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

                      // Add participant markers
                      locations.forEach((uid, loc) {
                        final participant = participantMap[uid];
                        final isMe = uid == currentUid;
                        final preset = AvatarPresets.getPreset(participant?.avatarPresetIndex);
                        final displayName = isMe
                            ? '${authProvider.userModel?.name ?? 'You'} (You)'
                            : (participant?.displayName ?? 'Member');

                        markers.add(
                          Marker(
                            point: LatLng(loc.latitude, loc.longitude),
                            width: 110,
                            height: 70,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    displayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: preset.gradientColors,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    border: Border.all(
                                      color: isMe ? AppColors.primary : Colors.white,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: preset.gradientColors.first.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(
                                      preset.icon,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
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
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.trackmate.app',
                          ),
                          MarkerLayer(markers: markers),
                        ],
                      );
                    },
                  );
                },
              ),

              // Recenter Floating Button
              Positioned(
                bottom: 90,
                right: 16,
                child: FloatingActionButton.small(
                  heroTag: 'group_recenter_fab',
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.primary,
                  onPressed: _recenterOnUser,
                  child: const Icon(Icons.my_location),
                ),
              ),

              // Bottom Session Control Pill
              Positioned(
                bottom: 20,
                left: 16,
                right: 16,
                child: StreamBuilder<List<GroupSessionParticipantModel>>(
                  stream: _databaseService.listenToGroupSessionParticipants(widget.group.id),
                  builder: (context, participantsSnapshot) {
                    final participants = participantsSnapshot.data ?? [];
                    final bool isCurrentUserSharing = participants.any((p) => p.uid == currentUid);

                    if (!isSessionActive) {
                      return Container(
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
                      );
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
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
                              }
                            },
                            child: Text(
                              isCurrentUserSharing ? 'Stop' : 'Share',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
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
