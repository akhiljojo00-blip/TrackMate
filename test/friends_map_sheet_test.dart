import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trackmate/models/connection_model.dart';
import 'package:trackmate/models/location_model.dart';
import 'package:trackmate/widgets/friends_map_sheet.dart';

void main() {
  group('FriendsMapSheet Widget Tests', () {
    testWidgets('FriendsMapSheet displays empty state when no connections exist', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendsMapSheet(
              connections: const [],
              activeFriendLocations: const {},
              friendDistances: const {},
              onSelectFriend: (_, _) {},
              onOpenChat: (_) {},
              onLocationUnavailable: (_) {},
            ),
          ),
        ),
      );

      expect(find.textContaining('No connections yet'), findsOneWidget);
    });

    testWidgets('FriendsMapSheet renders friends cards with live and offline states', (tester) async {
      final connections = [
        ConnectionUser(uid: 'user1', name: 'Alice', username: 'alice', connectedAt: 123456),
        ConnectionUser(uid: 'user2', name: 'Bob', username: 'bob', connectedAt: 123456),
      ];

      final now = DateTime.now().millisecondsSinceEpoch;
      final Map<String, LocationModel> activeLocations = {
        'user1': LocationModel(
          userId: 'user1',
          latitude: 12.9716,
          longitude: 77.5946,
          timestamp: now,
        ),
      };

      final friendDistances = {
        'user1': 1500.0,
      };

      LatLng? selectedCoords;
      String? selectedName;
      ConnectionUser? chatFriend;
      String? unavailableFriendName;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FriendsMapSheet(
              connections: connections,
              activeFriendLocations: activeLocations,
              friendDistances: friendDistances,
              onSelectFriend: (coords, name) {
                selectedCoords = coords;
                selectedName = name;
              },
              onOpenChat: (friend) {
                chatFriend = friend;
              },
              onLocationUnavailable: (name) {
                unavailableFriendName = name;
              },
            ),
          ),
        ),
      );

      // Verify names rendered
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);

      // Verify status text
      expect(find.text('Live • 1.5 km'), findsOneWidget);
      expect(find.text('Location Off'), findsOneWidget);

      // Tap on live friend (Alice) -> triggers onSelectFriend
      await tester.tap(find.text('Alice'));
      await tester.pump();
      expect(selectedCoords?.latitude, 12.9716);
      expect(selectedName, 'Alice');

      // Tap on offline friend (Bob) -> triggers onLocationUnavailable
      await tester.tap(find.text('Bob'));
      await tester.pump();
      expect(unavailableFriendName, 'Bob');

      // Tap chat icon on Bob -> triggers onOpenChat
      final chatButtons = find.byIcon(Icons.chat_bubble_outline_rounded);
      expect(chatButtons, findsNWidgets(2));
      await tester.tap(chatButtons.last);
      await tester.pump();
      expect(chatFriend?.uid, 'user2');
    });
  });
}
