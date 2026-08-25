import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/geofence_presets.dart';
import '../../models/geofence_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import 'create_edit_geofence_screen.dart';

class GeofenceListScreen extends StatefulWidget {
  const GeofenceListScreen({super.key});

  @override
  State<GeofenceListScreen> createState() => _GeofenceListScreenState();
}

class _GeofenceListScreenState extends State<GeofenceListScreen> {
  final DatabaseService _databaseService = DatabaseService();

  void _openCreateScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CreateEditGeofenceScreen(),
      ),
    );
  }

  void _openEditScreen(BuildContext context, GeofenceModel geofence) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateEditGeofenceScreen(existingGeofence: geofence),
      ),
    );
  }

  Future<void> _handleDelete(BuildContext context, String currentUid, GeofenceModel geofence) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Safe Zone?'),
        content: Text('Are you sure you want to delete "${geofence.name}"? Active alerts for this zone will stop.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _databaseService.deleteGeofence(currentUid, geofence.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Safe Zone deleted.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatRecipientSummary(GeofenceModel geofence) {
    final friendCount = geofence.targetRecipientUids.length;
    final groupCount = geofence.targetGroupIds.length;

    if (friendCount == 0 && groupCount == 0) {
      return 'Private (no recipients selected)';
    }

    final parts = <String>[];
    if (friendCount > 0) {
      parts.add('$friendCount friend${friendCount > 1 ? 's' : ''}');
    }
    if (groupCount > 0) {
      parts.add('$groupCount group${groupCount > 1 ? 's' : ''}');
    }
    return 'Notifies ${parts.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUid = authProvider.user?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Zones & Geofences'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('New Safe Zone', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _openCreateScreen(context),
      ),
      body: StreamBuilder<List<GeofenceModel>>(
        stream: _databaseService.listenToUserGeofences(currentUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final geofences = snapshot.data ?? [];

          if (geofences.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.1),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.radar_rounded,
                          size: 48,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No Safe Zones Yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryColor(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create custom geofenced areas (like Home, School, or Gym) and automatically notify loved ones when you enter or leave.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryColor(context),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add_location_alt_rounded),
                      label: const Text('Create Safe Zone', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _openCreateScreen(context),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: geofences.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final geofence = geofences[index];
              final preset = GeofencePresets.getPreset(geofence.iconPreset);

              return Container(
                decoration: BoxDecoration(
                  color: AppColors.cardColor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: geofence.isEnabled
                        ? AppColors.primary.withValues(alpha: 0.35)
                        : AppColors.cardBorderColor(context),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                              boxShadow: [
                                BoxShadow(
                                  color: preset.gradientColors.first.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(preset.icon, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  geofence.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: geofence.isEnabled ? AppColors.textPrimaryColor(context) : AppColors.textSecondaryColor(context),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${geofence.radiusMeters.round()}m radius',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondaryColor(context),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: geofence.isEnabled,
                            activeThumbColor: AppColors.primary,
                            onChanged: (val) {
                              _databaseService.saveGeofence(
                                currentUid,
                                geofence.copyWith(isEnabled: val),
                              );
                            },
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, size: 20),
                            onSelected: (val) {
                              if (val == 'edit') {
                                _openEditScreen(context, geofence);
                              } else if (val == 'delete') {
                                _handleDelete(context, currentUid, geofence);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text('Edit Zone'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                    SizedBox(width: 8),
                                    Text('Delete Zone', style: TextStyle(color: AppColors.error)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          if (geofence.notifyOnEntry)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.login_rounded, size: 12, color: AppColors.success),
                                  SizedBox(width: 4),
                                  Text(
                                    'Entry',
                                    style: TextStyle(
                                      color: AppColors.success,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (geofence.notifyOnExit)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.logout_rounded, size: 12, color: Colors.orange),
                                  SizedBox(width: 4),
                                  Text(
                                    'Exit',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: Text(
                              _formatRecipientSummary(geofence),
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
