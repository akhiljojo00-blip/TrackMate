import 'package:flutter_test/flutter_test.dart';
import 'package:trackmate/models/group_model.dart';
import 'package:trackmate/models/group_member_model.dart';

void main() {
  group('GroupModel Tests', () {
    test('GroupModel serializes toMap and deserializes fromMap correctly', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final group = GroupModel(
        id: 'group_101',
        name: 'Family & Friends',
        description: 'Our weekend trip coordinate group',
        avatarPresetIndex: 2,
        ownerId: 'user_owner',
        createdAt: now,
        updatedAt: now,
        memberCount: 5,
        lastMessageText: 'See you all at 10 AM',
        lastMessageTimestamp: now + 1000,
        lastMessageSenderId: 'user_alice',
        lastMessageSenderName: 'Alice',
      );

      final map = group.toMap();
      expect(map['id'], 'group_101');
      expect(map['name'], 'Family & Friends');
      expect(map['description'], 'Our weekend trip coordinate group');
      expect(map['avatarPresetIndex'], 2);
      expect(map['ownerId'], 'user_owner');
      expect(map['createdAt'], now);
      expect(map['updatedAt'], now);
      expect(map['memberCount'], 5);
      expect(map['lastMessageText'], 'See you all at 10 AM');
      expect(map['lastMessageTimestamp'], now + 1000);
      expect(map['lastMessageSenderId'], 'user_alice');
      expect(map['lastMessageSenderName'], 'Alice');

      final parsed = GroupModel.fromMap(map, 'group_101');
      expect(parsed.id, 'group_101');
      expect(parsed.name, 'Family & Friends');
      expect(parsed.description, 'Our weekend trip coordinate group');
      expect(parsed.avatarPresetIndex, 2);
      expect(parsed.ownerId, 'user_owner');
      expect(parsed.createdAt, now);
      expect(parsed.updatedAt, now);
      expect(parsed.memberCount, 5);
      expect(parsed.lastMessageText, 'See you all at 10 AM');
      expect(parsed.lastMessageTimestamp, now + 1000);
      expect(parsed.lastMessageSenderId, 'user_alice');
      expect(parsed.lastMessageSenderName, 'Alice');
    });

    test('GroupModel defaults and null safety in fromMap', () {
      final minimalMap = {
        'name': 'Minimal Group',
        'ownerId': 'user_1',
      };

      final parsed = GroupModel.fromMap(minimalMap, 'group_min');
      expect(parsed.id, 'group_min');
      expect(parsed.name, 'Minimal Group');
      expect(parsed.description, isNull);
      expect(parsed.avatarPresetIndex, 0);
      expect(parsed.ownerId, 'user_1');
      expect(parsed.memberCount, 1);
      expect(parsed.lastMessageText, isNull);
      expect(parsed.lastMessageTimestamp, isNull);
    });

    test('GroupModel copyWith updates fields properly', () {
      final group = GroupModel(
        id: 'group_orig',
        name: 'Original Name',
        ownerId: 'user_orig',
        createdAt: 100,
        updatedAt: 100,
      );

      final updated = group.copyWith(
        name: 'Updated Name',
        description: 'New Description',
        avatarPresetIndex: 4,
        memberCount: 3,
        lastMessageText: 'New message',
      );

      expect(updated.id, 'group_orig');
      expect(updated.name, 'Updated Name');
      expect(updated.description, 'New Description');
      expect(updated.avatarPresetIndex, 4);
      expect(updated.ownerId, 'user_orig');
      expect(updated.memberCount, 3);
      expect(updated.lastMessageText, 'New message');
      expect(updated.createdAt, 100);
    });
  });

  group('GroupMemberModel Tests', () {
    test('GroupMemberModel serializes and deserializes correctly', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final member = GroupMemberModel(
        uid: 'user_alice',
        role: 'owner',
        joinedAt: now,
        name: 'Alice Cooper',
        username: 'alice',
      );

      final map = member.toMap();
      expect(map['uid'], 'user_alice');
      expect(map['role'], 'owner');
      expect(map['joinedAt'], now);
      expect(map['name'], 'Alice Cooper');
      expect(map['username'], 'alice');

      final parsed = GroupMemberModel.fromMap(map, 'user_alice');
      expect(parsed.uid, 'user_alice');
      expect(parsed.role, 'owner');
      expect(parsed.joinedAt, now);
      expect(parsed.name, 'Alice Cooper');
      expect(parsed.username, 'alice');
    });

    test('GroupMemberModel role helper getters test', () {
      final owner = GroupMemberModel(
        uid: 'u1',
        role: 'owner',
        joinedAt: 100,
      );
      expect(owner.isOwner, isTrue);
      expect(owner.isAdmin, isTrue);
      expect(owner.isMember, isFalse);

      final admin = GroupMemberModel(
        uid: 'u2',
        role: 'admin',
        joinedAt: 100,
      );
      expect(admin.isOwner, isFalse);
      expect(admin.isAdmin, isTrue);
      expect(admin.isMember, isFalse);

      final regularMember = GroupMemberModel(
        uid: 'u3',
        role: 'member',
        joinedAt: 100,
      );
      expect(regularMember.isOwner, isFalse);
      expect(regularMember.isAdmin, isFalse);
      expect(regularMember.isMember, isTrue);
    });

    test('GroupMemberModel copyWith updates fields properly', () {
      final member = GroupMemberModel(
        uid: 'u1',
        role: 'member',
        joinedAt: 100,
      );

      final promoted = member.copyWith(role: 'admin', name: 'Bob');
      expect(promoted.uid, 'u1');
      expect(promoted.role, 'admin');
      expect(promoted.isAdmin, isTrue);
      expect(promoted.name, 'Bob');
      expect(promoted.joinedAt, 100);
    });
  });
}
