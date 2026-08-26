import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import '../models/group_member_model.dart';
import '../models/user_model.dart';

class AccountDeletionService {
  final FirebaseDatabase? _customDb;

  AccountDeletionService({
    FirebaseDatabase? database,
  }) : _customDb = database;

  FirebaseDatabase get _db => _customDb ?? FirebaseDatabase.instance;

  /// Re-authenticates the current user using their password before proceeding.
  Future<void> reauthenticate({
    required User user,
    required String password,
  }) async {
    if (user.email == null || user.email!.isEmpty) {
      throw FirebaseAuthException(
        code: 'no-email',
        message: 'No email found for the current user account.',
      );
    }
    final credential = EmailAuthProvider.credential(
      email: user.email!.trim(),
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  /// Builds the atomic multi-path deletion dictionary for Realtime Database.
  static Map<String, dynamic> buildAtomicDeletionMap({
    required String uid,
    String? username,
    List<String> connectedFriendUids = const [],
    List<String> pendingSentTargetUids = const [],
    List<String> pendingIncomingSenderUids = const [],
    Map<String, dynamic> groupUpdates = const {},
  }) {
    final Map<String, dynamic> updates = {};

    // Core User Data
    updates['${AppConstants.usersPath}/$uid'] = null;
    if (username != null && username.trim().isNotEmpty) {
      updates['${AppConstants.usernamesPath}/${username.trim().toLowerCase()}'] = null;
    }
    updates['${AppConstants.userTokensPath}/$uid'] = null;
    updates['${AppConstants.locationsPath}/$uid'] = null;
    updates['${AppConstants.locationPermissionsPath}/$uid'] = null;
    updates['${AppConstants.emergencyAlertsPath}/$uid'] = null;
    updates['${AppConstants.userGeofencesPath}/$uid'] = null;
    updates['${AppConstants.geofenceStatePath}/$uid'] = null;

    // Connection Rosters & Requests
    updates['${AppConstants.connectionsPath}/$uid'] = null;
    updates['${AppConstants.sentRequestsPath}/$uid'] = null;
    updates['${AppConstants.connectionRequestsPath}/$uid'] = null;

    // Symmetrical Reverse Connection Unlinks
    for (final friendUid in connectedFriendUids) {
      final trimmed = friendUid.trim();
      if (trimmed.isNotEmpty && trimmed != uid) {
        updates['${AppConstants.connectionsPath}/$trimmed/$uid'] = null;
      }
    }

    // Symmetrical Reverse Pending Request Unlinks
    for (final targetUid in pendingSentTargetUids) {
      final trimmed = targetUid.trim();
      if (trimmed.isNotEmpty && trimmed != uid) {
        updates['${AppConstants.connectionRequestsPath}/$trimmed/$uid'] = null;
      }
    }
    for (final senderUid in pendingIncomingSenderUids) {
      final trimmed = senderUid.trim();
      if (trimmed.isNotEmpty && trimmed != uid) {
        updates['${AppConstants.sentRequestsPath}/$trimmed/$uid'] = null;
      }
    }

    // User Groups Index
    updates['${AppConstants.userGroupsPath}/$uid'] = null;

    // Merge Group Updates & Dissolutions
    updates.addAll(groupUpdates);

    return updates;
  }

  /// Pure function to resolve group updates when a user leaves/dissolves groups upon deletion.
  static Map<String, dynamic> resolveGroupResolution({
    required String uid,
    required String groupId,
    required String groupCreatedBy,
    required List<GroupMemberModel> members,
  }) {
    final Map<String, dynamic> updates = {};
    final otherMembers = members.where((m) => m.uid != uid).toList();

    if (otherMembers.isEmpty) {
      // Sole member / creator -> Dissolve entire group
      updates['${AppConstants.groupsPath}/$groupId'] = null;
      updates['${AppConstants.groupMembersPath}/$groupId'] = null;
      updates['${AppConstants.groupMessagesPath}/$groupId'] = null;
      updates['${AppConstants.groupLocationSessionsPath}/$groupId'] = null;
      updates['${AppConstants.groupSessionParticipantsPath}/$groupId'] = null;
      updates['${AppConstants.groupLiveLocationsPath}/$groupId'] = null;
      updates['${AppConstants.groupReadStatePath}/$groupId'] = null;
    } else {
      // Multi-member group
      if (groupCreatedBy == uid) {
        // Current user is owner -> Elect successor
        // 1. Look for other co-admins, sorted by joinedAt
        final otherAdmins = otherMembers.where((m) => m.isAdmin).toList()
          ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));

        final successor = otherAdmins.isNotEmpty
            ? otherAdmins.first
            : (otherMembers..sort((a, b) => a.joinedAt.compareTo(b.joinedAt))).first;

        // Transfer ownership
        updates['${AppConstants.groupsPath}/$groupId/createdBy'] = successor.uid;
        updates['${AppConstants.groupMembersPath}/$groupId/${successor.uid}/role'] = 'admin';
      }

      // Unlink deleting user from group
      updates['${AppConstants.groupMembersPath}/$groupId/$uid'] = null;
      updates['${AppConstants.groupReadStatePath}/$groupId/$uid'] = null;
      updates['${AppConstants.groupSessionParticipantsPath}/$groupId/$uid'] = null;
      updates['${AppConstants.groupLiveLocationsPath}/$groupId/$uid'] = null;
    }

    return updates;
  }

  /// Orchestrates full account deletion: Re-Auth -> RTDB Multi-path Batch -> Auth Delete.
  Future<void> purgeAndCloseAccount({
    required User authUser,
    required String password,
    required UserModel userModel,
  }) async {
    final uid = authUser.uid;

    // 1. Pre-flight re-authentication
    await reauthenticate(user: authUser, password: password);

    // 2. Fetch dependencies from RTDB
    final friendUids = await _fetchConnectedFriendUids(uid);
    final pendingSentUids = await _fetchPendingSentUids(uid);
    final pendingIncomingUids = await _fetchPendingIncomingUids(uid);
    final groupUpdates = await _fetchAndResolveGroups(uid);

    // 3. Assemble atomic multi-path deletion map
    final atomicMap = buildAtomicDeletionMap(
      uid: uid,
      username: userModel.username,
      connectedFriendUids: friendUids,
      pendingSentTargetUids: pendingSentUids,
      pendingIncomingSenderUids: pendingIncomingUids,
      groupUpdates: groupUpdates,
    );

    // 4. Execute atomic database purge
    await _db.ref().update(atomicMap);

    // 5. Delete Firebase Auth User record
    await authUser.delete();
  }

  Future<List<String>> _fetchConnectedFriendUids(String uid) async {
    try {
      final snapshot = await _db.ref('${AppConstants.connectionsPath}/$uid').get();
      if (snapshot.exists && snapshot.value is Map) {
        return (snapshot.value as Map).keys.map((k) => k.toString()).toList();
      }
    } catch (e) {
      debugPrint('Error fetching friends for deletion: $e');
    }
    return [];
  }

  Future<List<String>> _fetchPendingSentUids(String uid) async {
    try {
      final snapshot = await _db.ref('${AppConstants.sentRequestsPath}/$uid').get();
      if (snapshot.exists && snapshot.value is Map) {
        return (snapshot.value as Map).keys.map((k) => k.toString()).toList();
      }
    } catch (e) {
      debugPrint('Error fetching sent requests for deletion: $e');
    }
    return [];
  }

  Future<List<String>> _fetchPendingIncomingUids(String uid) async {
    try {
      final snapshot = await _db.ref('${AppConstants.connectionRequestsPath}/$uid').get();
      if (snapshot.exists && snapshot.value is Map) {
        return (snapshot.value as Map).keys.map((k) => k.toString()).toList();
      }
    } catch (e) {
      debugPrint('Error fetching incoming requests for deletion: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> _fetchAndResolveGroups(String uid) async {
    final Map<String, dynamic> groupUpdates = {};
    try {
      final userGroupsSnap = await _db.ref('${AppConstants.userGroupsPath}/$uid').get();
      if (userGroupsSnap.exists && userGroupsSnap.value is Map) {
        final groupIds = (userGroupsSnap.value as Map).keys.map((k) => k.toString()).toList();

        for (final groupId in groupIds) {
          final groupSnap = await _db.ref('${AppConstants.groupsPath}/$groupId').get();
          final membersSnap = await _db.ref('${AppConstants.groupMembersPath}/$groupId').get();

          final createdBy = groupSnap.exists && groupSnap.value is Map
              ? (groupSnap.value as Map)['createdBy']?.toString() ?? ''
              : '';

          final List<GroupMemberModel> members = [];
          if (membersSnap.exists && membersSnap.value is Map) {
            (membersSnap.value as Map).forEach((memberUid, val) {
              if (val is Map) {
                members.add(GroupMemberModel.fromMap(val, memberUid.toString()));
              }
            });
          }

          final res = resolveGroupResolution(
            uid: uid,
            groupId: groupId,
            groupCreatedBy: createdBy,
            members: members,
          );
          groupUpdates.addAll(res);
        }
      }
    } catch (e) {
      debugPrint('Error resolving groups for deletion: $e');
    }
    return groupUpdates;
  }
}
