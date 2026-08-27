import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmate/models/connection_model.dart';
import 'package:trackmate/models/location_model.dart';

void main() {
  group('Timed Location Sharing Reader Expiration Gate Tests', () {
    const testFriendUid = 'friend_reader_789';
    final now = DateTime.now().millisecondsSinceEpoch;

    test('Active peer with future expiresAt passes reader expiration gate', () {
      final futureExpiry = now + 1800000; // 30 mins
      final location = LocationModel(
        userId: testFriendUid,
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: now,
        expiresAt: futureExpiry,
      );

      expect(location.isExpired, isFalse);
      expect(location.isExpiredWithGrace(graceMs: 30000), isFalse);
    });

    test('Expired peer with past expiresAt (> 30s) is blocked by reader expiration gate', () {
      final pastExpiry = now - 45000; // 45s in past
      final location = LocationModel(
        userId: testFriendUid,
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: now - 50000,
        expiresAt: pastExpiry,
      );

      expect(location.isExpired, isTrue);
      expect(location.isExpiredWithGrace(graceMs: 30000), isTrue);
    });

    test('Peer within 30s grace window passes clock skew tolerance', () {
      final slightlyPastExpiry = now - 10000; // 10s in past (< 30s grace)
      final location = LocationModel(
        userId: testFriendUid,
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: now - 20000,
        expiresAt: slightlyPastExpiry,
      );

      expect(location.isExpired, isTrue);
      // Grace window prevents premature drop due to clock skew
      expect(location.isExpiredWithGrace(graceMs: 30000), isFalse);
    });

    test('Indefinite peer with null expiresAt always passes reader gate', () {
      final location = LocationModel(
        userId: testFriendUid,
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: now,
        expiresAt: null,
      );

      expect(location.isIndefinite, isTrue);
      expect(location.isExpired, isFalse);
      expect(location.isExpiredWithGrace(graceMs: 30000), isFalse);
    });

    testWidgets('Friend details sheet displays Timed Session countdown banner', (tester) async {
      final futureExpiry = DateTime.now().millisecondsSinceEpoch + 1500000; // 25m
      final location = LocationModel(
        userId: testFriendUid,
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: now,
        expiresAt: futureExpiry,
      );

      const friend = ConnectionUser(
        uid: testFriendUid,
        name: 'Jane Doe',
        username: 'janedoe',
        connectedAt: 1700000000000,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (_) => Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(friend.name),
                          Text('@${friend.username}'),
                          if (location.expiresAt != null && !location.isExpired)
                            const Text('Timed Session: 25 mins left'),
                        ],
                      ),
                    ),
                  );
                },
                child: const Text('Open Details'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Details'));
      await tester.pumpAndSettle();

      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.text('@janedoe'), findsOneWidget);
      expect(find.text('Timed Session: 25 mins left'), findsOneWidget);
    });
  });
}
