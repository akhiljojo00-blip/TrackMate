import 'package:flutter_test/flutter_test.dart';
import 'package:trackmate/models/group_location_session_model.dart';
import 'package:trackmate/models/group_session_participant_model.dart';

void main() {
  group('GroupLocationSessionModel Tests', () {
    test('GroupLocationSessionModel serializes toMap and deserializes fromMap correctly', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final session = GroupLocationSessionModel(
        sessionId: 'session_123',
        groupId: 'group_456',
        createdBy: 'user_alice',
        createdAt: now,
        title: 'Road Trip to Lake Tahoe',
        isActive: true,
      );

      final map = session.toMap();
      expect(map['sessionId'], 'session_123');
      expect(map['groupId'], 'group_456');
      expect(map['createdBy'], 'user_alice');
      expect(map['createdAt'], now);
      expect(map['title'], 'Road Trip to Lake Tahoe');
      expect(map['isActive'], true);

      final parsed = GroupLocationSessionModel.fromMap(map, 'group_456');
      expect(parsed.sessionId, 'session_123');
      expect(parsed.groupId, 'group_456');
      expect(parsed.createdBy, 'user_alice');
      expect(parsed.createdAt, now);
      expect(parsed.title, 'Road Trip to Lake Tahoe');
      expect(parsed.isActive, true);
    });

    test('GroupLocationSessionModel copyWith updates fields properly', () {
      final session = GroupLocationSessionModel(
        sessionId: 'session_1',
        groupId: 'group_1',
        createdBy: 'user_1',
        createdAt: 1000,
        title: 'Original Title',
        isActive: true,
      );

      final updated = session.copyWith(
        title: 'Updated Title',
        isActive: false,
      );

      expect(updated.sessionId, 'session_1');
      expect(updated.groupId, 'group_1');
      expect(updated.createdBy, 'user_1');
      expect(updated.createdAt, 1000);
      expect(updated.title, 'Updated Title');
      expect(updated.isActive, false);
    });

    test('GroupLocationSessionModel fallback defaults', () {
      final minimalMap = {
        'sessionId': 'session_min',
        'createdBy': 'user_min',
      };

      final parsed = GroupLocationSessionModel.fromMap(minimalMap, 'group_fallback');
      expect(parsed.sessionId, 'session_min');
      expect(parsed.groupId, 'group_fallback');
      expect(parsed.createdBy, 'user_min');
      expect(parsed.title, 'Live Location Session');
      expect(parsed.isActive, false);
    });
  });

  group('GroupSessionParticipantModel Tests', () {
    test('GroupSessionParticipantModel serializes toMap and deserializes fromMap correctly', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final participant = GroupSessionParticipantModel(
        uid: 'user_bob',
        displayName: 'Bob Builder',
        avatarPresetIndex: 3,
        isSharing: true,
        joinedAt: now,
      );

      final map = participant.toMap();
      expect(map['uid'], 'user_bob');
      expect(map['displayName'], 'Bob Builder');
      expect(map['avatarPresetIndex'], 3);
      expect(map['isSharing'], true);
      expect(map['joinedAt'], now);

      final parsed = GroupSessionParticipantModel.fromMap(map, 'user_bob');
      expect(parsed.uid, 'user_bob');
      expect(parsed.displayName, 'Bob Builder');
      expect(parsed.avatarPresetIndex, 3);
      expect(parsed.isSharing, true);
      expect(parsed.joinedAt, now);
    });

    test('GroupSessionParticipantModel copyWith updates fields properly', () {
      final participant = GroupSessionParticipantModel(
        uid: 'user_bob',
        displayName: 'Bob',
        avatarPresetIndex: 0,
        isSharing: true,
        joinedAt: 100,
      );

      final updated = participant.copyWith(
        displayName: 'Bob Vance',
        avatarPresetIndex: 4,
        isSharing: false,
      );

      expect(updated.uid, 'user_bob');
      expect(updated.displayName, 'Bob Vance');
      expect(updated.avatarPresetIndex, 4);
      expect(updated.isSharing, false);
      expect(updated.joinedAt, 100);
    });
  });
}
