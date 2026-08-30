import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmate/screens/map/widgets/active_sharing_hud.dart';
import 'package:trackmate/screens/map/widgets/timed_sharing_bottom_sheet.dart';

void main() {
  group('Timed Location Sharing UI & HUD Tests', () {
    testWidgets('TimedSharingBottomSheet renders consent duration picker', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    await TimedSharingBottomSheet.show(context, isSharing: false);
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Location Consent'), findsOneWidget);
      expect(find.text('15m'), findsOneWidget);
      expect(find.text('1h'), findsOneWidget);
      expect(find.text('8h'), findsOneWidget);
      expect(find.text('Until Off'), findsOneWidget);
      expect(find.text('Start Sharing Location'), findsOneWidget);
      expect(find.text('Stop Sharing Now'), findsNothing);
    });

    testWidgets('TimedSharingBottomSheet shows revoke button if currently sharing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    await TimedSharingBottomSheet.show(context, isSharing: true);
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Update Consent Settings'), findsOneWidget);
      expect(find.text('Stop Sharing Now'), findsOneWidget);
    });

    testWidgets('ActiveSharingHud renders inactive state when isTracking is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActiveSharingHud(
              isTracking: false,
              onStopPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Sharing is OFF'), findsOneWidget);
      expect(find.byIcon(Icons.location_off_outlined), findsOneWidget);
      expect(find.text('Stop'), findsNothing);
    });

    testWidgets('ActiveSharingHud renders indefinite state when expiresAt is null', (tester) async {
      bool stopped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActiveSharingHud(
              isTracking: true,
              expiresAt: null,
              onStopPressed: () {
                stopped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Sharing Live'), findsOneWidget);
      expect(find.text('• Indefinite'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);

      await tester.tap(find.text('Stop'));
      await tester.pump();
      expect(stopped, isTrue);
    });

    testWidgets('ActiveSharingHud renders countdown text for timed session', (tester) async {
      final futureExpiry = DateTime.now().millisecondsSinceEpoch + 1800000; // 30m

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActiveSharingHud(
              isTracking: true,
              expiresAt: futureExpiry,
              visibleFriendsCount: 2,
              onStopPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Sharing Live'), findsOneWidget);
      expect(find.textContaining('left'), findsOneWidget);
      expect(find.text('2 friends visible'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);
    });
  });
}
