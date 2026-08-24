import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/geofence_presets.dart';
import '../../models/geofence_model.dart';
import '../../models/group_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/database_service.dart';

class CreateEditGeofenceScreen extends StatefulWidget {
  final GeofenceModel? existingGeofence;

  const CreateEditGeofenceScreen({
    super.key,
    this.existingGeofence,
  });

  @override
  State<CreateEditGeofenceScreen> createState() => _CreateEditGeofenceScreenState();
}

class _CreateEditGeofenceScreenState extends State<CreateEditGeofenceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final MapController _mapController = MapController();
  final DatabaseService _databaseService = DatabaseService();

  late LatLng _selectedLocation;
  late double _radiusMeters;
  late int _selectedIconPreset;
  late bool _notifyOnEntry;
  late bool _notifyOnExit;
  late List<String> _targetRecipientUids;
  late List<String> _targetGroupIds;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingGeofence;
    if (existing != null) {
      _nameController.text = existing.name;
      _selectedLocation = LatLng(existing.latitude, existing.longitude);
      _radiusMeters = existing.radiusMeters;
      _selectedIconPreset = existing.iconPreset;
      _notifyOnEntry = existing.notifyOnEntry;
      _notifyOnExit = existing.notifyOnExit;
      _targetRecipientUids = List.from(existing.targetRecipientUids);
      _targetGroupIds = List.from(existing.targetGroupIds);
    } else {
      final locationProvider = context.read<LocationProvider>();
      final currentLatLng = locationProvider.currentLatLng ?? const LatLng(37.7749, -122.4194);
      _selectedLocation = currentLatLng;
      _radiusMeters = 150.0;
      _selectedIconPreset = 0;
      _notifyOnEntry = true;
      _notifyOnExit = true;
      _targetRecipientUids = [];
      _targetGroupIds = [];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _recenterOnUser() {
    final locationProvider = context.read<LocationProvider>();
    final currentLatLng = locationProvider.currentLatLng;
    if (currentLatLng != null) {
      setState(() => _selectedLocation = currentLatLng);
      _mapController.move(currentLatLng, 16.0);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    final authProvider = context.read<AuthProvider>();
    final currentUid = authProvider.user?.uid;
    if (currentUid == null) return;

    setState(() => _isSaving = true);

    try {
      final id = widget.existingGeofence?.id ??
          _databaseService.userGeofencesRef.child(currentUid).push().key!;

      final geofence = GeofenceModel(
        id: id,
        name: _nameController.text.trim(),
        latitude: _selectedLocation.latitude,
        longitude: _selectedLocation.longitude,
        radiusMeters: _radiusMeters,
        iconPreset: _selectedIconPreset,
        notifyOnEntry: _notifyOnEntry,
        notifyOnExit: _notifyOnExit,
        targetRecipientUids: _targetRecipientUids,
        targetGroupIds: _targetGroupIds,
        createdAt: widget.existingGeofence?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
        isEnabled: widget.existingGeofence?.isEnabled ?? true,
      );

      await _databaseService.saveGeofence(currentUid, geofence);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingGeofence != null
                  ? 'Safe Zone updated successfully!'
                  : 'Safe Zone created successfully!',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save safe zone: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionProvider = context.watch<ConnectionProvider>();
    final connections = connectionProvider.connections;
    final authProvider = context.watch<AuthProvider>();
    final currentUid = authProvider.user?.uid ?? '';
    final preset = GeofencePresets.getPreset(_selectedIconPreset);

    final isEditing = widget.existingGeofence != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Safe Zone' : 'Create Safe Zone'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded),
            tooltip: 'Save Safe Zone',
            onPressed: _isSaving ? null : _handleSave,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Interactive Map Preview Card
            Container(
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _selectedLocation,
                      initialZoom: 15.5,
                      onTap: (tapPosition, point) {
                        setState(() {
                          _selectedLocation = point;
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.trackmate.app',
                      ),
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _selectedLocation,
                            radius: _radiusMeters,
                            useRadiusInMeter: true,
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderColor: AppColors.primary,
                            borderStrokeWidth: 2.5,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLocation,
                            width: 44,
                            height: 44,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: preset.gradientColors,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Icon(preset.icon, color: Colors.white, size: 22),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: FloatingActionButton.small(
                      heroTag: 'geofence_map_recenter',
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.primary,
                      tooltip: 'Center on My GPS',
                      onPressed: _recenterOnUser,
                      child: const Icon(Icons.my_location),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Tap map to position center',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Radius Slider
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Safe Zone Radius',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_radiusMeters.round()} meters',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _radiusMeters,
                    min: 50.0,
                    max: 1000.0,
                    divisions: 38,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() => _radiusMeters = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Safe Zone Details Form
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Safe Zone Name',
                      hintText: 'e.g. Home, Campus, Office',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: AppColors.background,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter a name for this safe zone';
                      }
                      if (val.trim().length < 3) {
                        return 'Name must be at least 3 characters long';
                      }
                      if (val.trim().length > 32) {
                        return 'Name cannot exceed 32 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Preset Icon Selector
                  const Text(
                    'Choose Icon & Category',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 52,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: GeofencePresets.presets.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final p = GeofencePresets.presets[index];
                        final isSelected = index == _selectedIconPreset;

                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedIconPreset = index);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: p.gradientColors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: p.gradientColors.first.withValues(alpha: 0.6),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                              ],
                            ),
                            child: Icon(p.icon, color: Colors.white, size: 22),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Trigger Controls
                  const Text(
                    'Alert Triggers',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Notify on Entry', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('Alert when entering this safe zone', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    value: _notifyOnEntry,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => _notifyOnEntry = val),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Notify on Exit', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('Alert when leaving this safe zone', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    value: _notifyOnExit,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => _notifyOnExit = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Recipient Selector (1-to-1 Connections & Groups)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Alert Recipients',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select friends and groups who should be notified when you enter or leave this zone.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),

                  // Connections Multi-Select
                  const Text(
                    'Friends',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                  ),
                  const SizedBox(height: 8),
                  if (connections.isEmpty)
                    const Text('No connections added yet.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: connections.map((friend) {
                        final isSelected = _targetRecipientUids.contains(friend.uid);
                        return FilterChip(
                          label: Text(friend.name),
                          selected: isSelected,
                          selectedColor: AppColors.primary.withValues(alpha: 0.15),
                          checkmarkColor: AppColors.primary,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          ),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _targetRecipientUids.add(friend.uid);
                              } else {
                                _targetRecipientUids.remove(friend.uid);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 14),

                  // Groups Multi-Select
                  const Text(
                    'Groups',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<List<GroupModel>>(
                    stream: _databaseService.listenToUserGroups(currentUid),
                    builder: (context, snapshot) {
                      final groups = snapshot.data ?? [];
                      if (groups.isEmpty) {
                        return const Text('No groups joined yet.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary));
                      }

                      return Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: groups.map((group) {
                          final isSelected = _targetGroupIds.contains(group.id);
                          return FilterChip(
                            label: Text(group.name),
                            selected: isSelected,
                            selectedColor: AppColors.primary.withValues(alpha: 0.15),
                            checkmarkColor: AppColors.primary,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            ),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _targetGroupIds.add(group.id);
                                } else {
                                  _targetGroupIds.remove(group.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isSaving ? null : _handleSave,
              child: Text(
                isEditing ? 'Update Safe Zone' : 'Create Safe Zone',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
