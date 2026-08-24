import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/avatar_presets.dart';
import '../../models/connection_model.dart';
import '../../models/group_member_model.dart';
import '../../models/group_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connection_provider.dart';
import '../../services/database_service.dart';

class GroupInfoScreen extends StatefulWidget {
  final GroupModel group;

  const GroupInfoScreen({
    super.key,
    required this.group,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final DatabaseService _databaseService = DatabaseService();
  late GroupModel _currentGroup;

  @override
  void initState() {
    super.initState();
    _currentGroup = widget.group;
  }

  void _showAddMembersSheet(BuildContext context, List<GroupMemberModel> currentMembers) {
    final connectionProvider = context.read<ConnectionProvider>();
    final allConnections = connectionProvider.connections;
    final memberUids = currentMembers.map((m) => m.uid).toSet();

    final nonMemberConnections = allConnections.where((c) => !memberUids.contains(c.uid)).toList();

    if (nonMemberConnections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All your connected friends are already in this group.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final Set<String> toAddUids = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Add Friends to Group',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: nonMemberConnections.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final ConnectionUser friend = nonMemberConnections[index];
                        final isSelected = toAddUids.contains(friend.uid);

                        return CheckboxListTile(
                          value: isSelected,
                          activeColor: AppColors.primary,
                          title: Text(friend.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text('@${friend.username}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          onChanged: (bool? checked) {
                            setModalState(() {
                              if (checked == true) {
                                toAddUids.add(friend.uid);
                              } else {
                                toAddUids.remove(friend.uid);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: toAddUids.isEmpty
                        ? null
                        : () async {
                            Navigator.of(ctx).pop();
                            for (final uid in toAddUids) {
                              await _databaseService.addMemberToGroup(
                                groupId: _currentGroup.id,
                                targetUid: uid,
                              );
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added ${toAddUids.length} member(s) to group.'),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                    child: Text('Add Selected (${toAddUids.length})'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showMemberOptions(BuildContext context, GroupMemberModel targetMember, bool isCurrentUserOwner, bool isCurrentUserAdmin, String currentUid) {
    if (targetMember.uid == currentUid) return;

    // Only owner can manage admins/members; admins can remove regular members
    final bool canManage = isCurrentUserOwner || (isCurrentUserAdmin && !targetMember.isAdmin);
    if (!canManage) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  targetMember.name ?? 'Member',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Text('Role: ${targetMember.role.toUpperCase()}'),
              ),
              const Divider(),
              if (isCurrentUserOwner && !targetMember.isOwner) ...[
                ListTile(
                  leading: const Icon(Icons.swap_horiz_rounded, color: Colors.orange),
                  title: const Text('Transfer Ownership'),
                  subtitle: const Text('Make this member the new group owner'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        title: const Text('Transfer Group Ownership'),
                        content: Text('Are you sure you want to transfer ownership of "${_currentGroup.name}" to ${targetMember.name ?? 'this member'}? You will become an admin.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                            onPressed: () => Navigator.of(dialogCtx).pop(true),
                            child: const Text('Transfer'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && context.mounted) {
                      await _databaseService.transferGroupOwnership(
                        groupId: _currentGroup.id,
                        currentOwnerUid: currentUid,
                        newOwnerUid: targetMember.uid,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Group ownership transferred successfully.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    }
                  },
                ),
                if (targetMember.role == 'member')
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined, color: AppColors.primary),
                    title: const Text('Make Group Admin'),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await _databaseService.addMemberToGroup(
                        groupId: _currentGroup.id,
                        targetUid: targetMember.uid,
                        role: 'admin',
                      );
                    },
                  ),
                if (targetMember.role == 'admin')
                  ListTile(
                    leading: const Icon(Icons.person_outline, color: AppColors.textSecondary),
                    title: const Text('Dismiss as Admin'),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await _databaseService.addMemberToGroup(
                        groupId: _currentGroup.id,
                        targetUid: targetMember.uid,
                        role: 'member',
                      );
                    },
                  ),
              ],
              ListTile(
                leading: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                title: const Text('Remove from Group', style: TextStyle(color: AppColors.error)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _databaseService.removeMemberFromGroup(
                    groupId: _currentGroup.id,
                    targetUid: targetMember.uid,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLeaveGroup(BuildContext context, String currentUid, List<GroupMemberModel> members, bool isOwner) async {
    if (isOwner && members.length > 1) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Transfer Ownership Required'),
          content: const Text(
            'You are the owner of this group. Please transfer group ownership to another member before leaving.',
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final bool isSoleMember = members.length <= 1;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isSoleMember ? 'Delete & Leave Group' : 'Leave Group'),
        content: Text(
          isSoleMember
              ? 'You are the only member in "${_currentGroup.name}". Leaving will permanently delete this group. Continue?'
              : 'Are you sure you want to leave "${_currentGroup.name}"?',
        ),
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
            child: Text(isSoleMember ? 'Delete Group' : 'Leave'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await _databaseService.leaveGroup(
        groupId: _currentGroup.id,
        uid: currentUid,
      );
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final connectionProvider = context.watch<ConnectionProvider>();
    final currentUid = authProvider.user?.uid ?? '';
    final preset = AvatarPresets.getPreset(_currentGroup.avatarPresetIndex);

    final createdDate = DateFormat('MMMM d, yyyy').format(
      DateTime.fromMillisecondsSinceEpoch(_currentGroup.createdAt),
    );

    // Map connections for instant name lookup
    final connectionMap = {for (var c in connectionProvider.connections) c.uid: c};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Info'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: preset.gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: preset.gradientColors.first.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          preset.icon,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _currentGroup.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_currentGroup.description != null && _currentGroup.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _currentGroup.description!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      'Created on $createdDate',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Members Stream Section
              StreamBuilder<List<GroupMemberModel>>(
                stream: _databaseService.listenToGroupMembers(_currentGroup.id),
                builder: (context, snapshot) {
                  final members = snapshot.data ?? [];
                  final currentMember = members.firstWhere(
                    (m) => m.uid == currentUid,
                    orElse: () => GroupMemberModel(uid: currentUid, role: 'member', joinedAt: 0),
                  );

                  final bool isOwner = currentMember.isOwner;
                  final bool isAdmin = currentMember.isAdmin;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Participants (${members.length})',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (isAdmin)
                            TextButton.icon(
                              icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                              label: const Text('Add', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              onPressed: () => _showAddMembersSheet(context, members),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: members.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final member = members[index];
                            final isMe = member.uid == currentUid;
                            final friend = connectionMap[member.uid];
                            final displayName = isMe
                                ? '${authProvider.userModel?.name ?? 'You'} (You)'
                                : (friend?.name ?? member.name ?? 'Member');
                            final displayUsername = isMe
                                ? authProvider.userModel?.username ?? ''
                                : (friend?.username ?? member.username ?? '');

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                child: Text(
                                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'M',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                displayName,
                                style: TextStyle(
                                  fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: displayUsername.isNotEmpty
                                  ? Text('@$displayUsername', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
                                  : null,
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: member.isOwner
                                      ? Colors.orange.withValues(alpha: 0.15)
                                      : (member.role == 'admin'
                                          ? AppColors.primary.withValues(alpha: 0.15)
                                          : Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  member.role.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: member.isOwner
                                        ? Colors.orange.shade800
                                        : (member.role == 'admin'
                                            ? AppColors.primary
                                            : Colors.grey.shade700),
                                  ),
                                ),
                              ),
                              onTap: () => _showMemberOptions(
                                context,
                                member,
                                isOwner,
                                isAdmin,
                                currentUid,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Leave Group Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.exit_to_app_rounded, size: 18),
                        label: const Text('Leave Group', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        onPressed: () => _handleLeaveGroup(context, currentUid, members, isOwner),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
