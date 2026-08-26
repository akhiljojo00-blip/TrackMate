import 'package:flutter_test/flutter_test.dart';
import 'package:trackmate/constants/app_constants.dart';
import 'package:trackmate/models/group_member_model.dart';
import 'package:trackmate/models/user_model.dart';
import 'package:trackmate/services/account_deletion_service.dart';

void main() {
  group('Account Deletion & Atomic Purge Engine Tests', () {
    test('buildAtomicDeletionMap constructs all owned paths and symmetric reverse unlinks', () {
      const uid = 'user_123';
      const username = 'alice_prime';
      final friends = ['friend_bob', 'friend_charlie'];
      final sentTargets = ['target_david'];
      final incomingSenders = ['sender_eve'];

      final map = AccountDeletionService.buildAtomicDeletionMap(
        uid: uid,
        username: username,
        connectedFriendUids: friends,
        pendingSentTargetUids: sentTargets,
        pendingIncomingSenderUids: incomingSenders,
      );

      // Core Owned Paths
      expect(map['${AppConstants.usersPath}/$uid'], isNull);
      expect(map['${AppConstants.usernamesPath}/$username'], isNull);
      expect(map['${AppConstants.userTokensPath}/$uid'], isNull);
      expect(map['${AppConstants.locationsPath}/$uid'], isNull);
      expect(map['${AppConstants.locationPermissionsPath}/$uid'], isNull);
      expect(map['${AppConstants.emergencyAlertsPath}/$uid'], isNull);
      expect(map['${AppConstants.userGeofencesPath}/$uid'], isNull);
      expect(map['${AppConstants.geofenceStatePath}/$uid'], isNull);
      expect(map['${AppConstants.connectionsPath}/$uid'], isNull);
      expect(map['${AppConstants.sentRequestsPath}/$uid'], isNull);
      expect(map['${AppConstants.connectionRequestsPath}/$uid'], isNull);
      expect(map['${AppConstants.userGroupsPath}/$uid'], isNull);

      // Symmetrical Reverse Connection Unlinks
      expect(map['${AppConstants.connectionsPath}/friend_bob/$uid'], isNull);
      expect(map['${AppConstants.connectionsPath}/friend_charlie/$uid'], isNull);

      // Symmetrical Reverse Request Unlinks
      expect(map['${AppConstants.connectionRequestsPath}/target_david/$uid'], isNull);
      expect(map['${AppConstants.sentRequestsPath}/sender_eve/$uid'], isNull);
    });

    test('resolveGroupResolution dissolves group when user is sole member', () {
      const uid = 'user_owner';
      const groupId = 'group_solo';
      final members = [
        GroupMemberModel(
          uid: uid,
          name: 'Owner',
          username: 'owner',
          role: 'admin',
          joinedAt: 1000,
        ),
      ];

      final updates = AccountDeletionService.resolveGroupResolution(
        uid: uid,
        groupId: groupId,
        groupCreatedBy: uid,
        members: members,
      );

      expect(updates['${AppConstants.groupsPath}/$groupId'], isNull);
      expect(updates['${AppConstants.groupMembersPath}/$groupId'], isNull);
      expect(updates['${AppConstants.groupMessagesPath}/$groupId'], isNull);
      expect(updates['${AppConstants.groupLocationSessionsPath}/$groupId'], isNull);
      expect(updates['${AppConstants.groupSessionParticipantsPath}/$groupId'], isNull);
      expect(updates['${AppConstants.groupLiveLocationsPath}/$groupId'], isNull);
      expect(updates['${AppConstants.groupReadStatePath}/$groupId'], isNull);
    });

    test('resolveGroupResolution transfers ownership to oldest co-admin in multi-member group', () {
      const uid = 'user_owner';
      const groupId = 'group_active';
      final members = [
        GroupMemberModel(
          uid: uid,
          name: 'Owner',
          username: 'owner',
          role: 'admin',
          joinedAt: 1000,
        ),
        GroupMemberModel(
          uid: 'user_admin_2',
          name: 'CoAdmin Older',
          username: 'admin2',
          role: 'admin',
          joinedAt: 2000,
        ),
        GroupMemberModel(
          uid: 'user_admin_3',
          name: 'CoAdmin Newer',
          username: 'admin3',
          role: 'admin',
          joinedAt: 3000,
        ),
        GroupMemberModel(
          uid: 'user_member_1',
          name: 'Member',
          username: 'member1',
          role: 'member',
          joinedAt: 1500,
        ),
      ];

      final updates = AccountDeletionService.resolveGroupResolution(
        uid: uid,
        groupId: groupId,
        groupCreatedBy: uid,
        members: members,
      );

      // Ownership transferred to user_admin_2 (oldest co-admin)
      expect(updates['${AppConstants.groupsPath}/$groupId/createdBy'], 'user_admin_2');
      expect(updates['${AppConstants.groupMembersPath}/$groupId/user_admin_2/role'], 'admin');

      // Deleting user unlinked
      expect(updates['${AppConstants.groupMembersPath}/$groupId/$uid'], isNull);
      expect(updates['${AppConstants.groupReadStatePath}/$groupId/$uid'], isNull);
      expect(updates['${AppConstants.groupSessionParticipantsPath}/$groupId/$uid'], isNull);
      expect(updates['${AppConstants.groupLiveLocationsPath}/$groupId/$uid'], isNull);
    });

    test('resolveGroupResolution transfers ownership to oldest member when no other co-admin exists', () {
      const uid = 'user_owner';
      const groupId = 'group_members_only';
      final members = [
        GroupMemberModel(
          uid: uid,
          name: 'Owner',
          username: 'owner',
          role: 'admin',
          joinedAt: 1000,
        ),
        GroupMemberModel(
          uid: 'user_member_newer',
          name: 'Newer Member',
          username: 'newer',
          role: 'member',
          joinedAt: 4000,
        ),
        GroupMemberModel(
          uid: 'user_member_older',
          name: 'Older Member',
          username: 'older',
          role: 'member',
          joinedAt: 2000,
        ),
      ];

      final updates = AccountDeletionService.resolveGroupResolution(
        uid: uid,
        groupId: groupId,
        groupCreatedBy: uid,
        members: members,
      );

      // Ownership transferred to oldest member (user_member_older) and promoted to admin
      expect(updates['${AppConstants.groupsPath}/$groupId/createdBy'], 'user_member_older');
      expect(updates['${AppConstants.groupMembersPath}/$groupId/user_member_older/role'], 'admin');
      expect(updates['${AppConstants.groupMembersPath}/$groupId/$uid'], isNull);
    });

    test('resolveGroupResolution unlinks standard member without changing group ownership', () {
      const uid = 'user_regular_member';
      const groupId = 'group_existing';
      const ownerUid = 'original_creator_uid';
      final members = [
        GroupMemberModel(
          uid: ownerUid,
          name: 'Creator',
          username: 'creator',
          role: 'admin',
          joinedAt: 1000,
        ),
        GroupMemberModel(
          uid: uid,
          name: 'Regular Member',
          username: 'regular',
          role: 'member',
          joinedAt: 2000,
        ),
      ];

      final updates = AccountDeletionService.resolveGroupResolution(
        uid: uid,
        groupId: groupId,
        groupCreatedBy: ownerUid,
        members: members,
      );

      // Group creator untouched
      expect(updates.containsKey('${AppConstants.groupsPath}/$groupId/createdBy'), isFalse);

      // User unlinked
      expect(updates['${AppConstants.groupMembersPath}/$groupId/$uid'], isNull);
      expect(updates['${AppConstants.groupReadStatePath}/$groupId/$uid'], isNull);
      expect(updates['${AppConstants.groupSessionParticipantsPath}/$groupId/$uid'], isNull);
      expect(updates['${AppConstants.groupLiveLocationsPath}/$groupId/$uid'], isNull);
    });

    test('UserModel.deletedUser returns safe fallback representation', () {
      final deleted = UserModel.deletedUser('user_purged_999');
      expect(deleted.uid, 'user_purged_999');
      expect(deleted.name, 'Deleted User');
      expect(deleted.username, 'deleted');
      expect(deleted.isLocationSharing, isFalse);
    });
  });
}
