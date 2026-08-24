import 'package:flutter_test/flutter_test.dart';
import 'package:trackmate/models/geofence_model.dart';
import 'package:trackmate/services/geofence_service.dart';

void main() {
  group('Geofence Notification & Fan-Out Tests', () {
    test('formatNotificationBody formats entry and exit message strings correctly', () {
      final entryBody = GeofenceService.formatNotificationBody(
        userName: 'Alice',
        geofenceName: 'Home',
        transitionType: 'entered',
      );
      expect(entryBody, 'Alice arrived at Home');

      final exitBody = GeofenceService.formatNotificationBody(
        userName: 'Bob',
        geofenceName: 'University Campus',
        transitionType: 'exited',
      );
      expect(exitBody, 'Bob left University Campus');

      final fallbackBody = GeofenceService.formatNotificationBody(
        userName: 'Charlie',
        geofenceName: 'Gym',
        transitionType: 'unknown',
      );
      expect(fallbackBody, 'Charlie updated safe zone status for Gym');
    });

    test('resolveTargetUids aggregates direct connections and group members while removing sender', () {
      final geofence = GeofenceModel(
        id: 'geo_test',
        name: 'Safe Haven',
        latitude: 0.0,
        longitude: 0.0,
        targetRecipientUids: ['user_bob', 'user_charlie', 'user_alice'],
        targetGroupIds: ['group_1', 'group_2'],
        createdAt: 1000,
      );

      final groupMembers = {
        'group_1': ['user_charlie', 'user_david', 'user_alice'],
        'group_2': ['user_eve', 'user_frank'],
      };

      // Alice is the sender (owner)
      final resolved = GeofenceService.resolveTargetUids(
        geofence: geofence,
        senderUid: 'user_alice',
        groupMembersMap: groupMembers,
      );

      // Should contain: user_bob, user_charlie, user_david, user_eve, user_frank
      // Should NOT contain: user_alice
      expect(resolved.contains('user_alice'), isFalse);
      expect(resolved.contains('user_bob'), isTrue);
      expect(resolved.contains('user_charlie'), isTrue);
      expect(resolved.contains('user_david'), isTrue);
      expect(resolved.contains('user_eve'), isTrue);
      expect(resolved.contains('user_frank'), isTrue);
      expect(resolved.length, 5);
    });

    test('resolveTargetUids handles empty recipients and empty groups cleanly', () {
      final geofence = GeofenceModel(
        id: 'geo_empty',
        name: 'Private Zone',
        latitude: 0.0,
        longitude: 0.0,
        targetRecipientUids: const [],
        targetGroupIds: const [],
        createdAt: 1000,
      );

      final resolved = GeofenceService.resolveTargetUids(
        geofence: geofence,
        senderUid: 'user_self',
      );

      expect(resolved.isEmpty, isTrue);
    });
  });
}
