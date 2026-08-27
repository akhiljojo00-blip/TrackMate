import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmate/screens/map/widgets/active_sharing_hud.dart';
import 'package:trackmate/screens/map/widgets/timed_sharing_bottom_sheet.dart';

void main() {
  group('Timed Location Sharing UI & HUD Tests', () {
    testWidgets('TimedSharingBottomSheet renders duration presets', (tester) async {
      SharingDurationOption? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimedSharingBottomSheet(
              onDurationSelected: (option) {
                selected = option;
              },
            ),
          ),
        ),
      );

      expect(find.text('Share Live Location'), findsOneWidget);
      expect(find.text('30 Minutes'), findsOneWidget);
      expect(find.text('1 Hour'), findsOneWidget);
      expect(find.text('2 Hours'), findsOneWidget);
      expect(find.text('Until a Specific Time'), findsOneWidget);
      expect(find.text('Until Turned Off'), findsOneWidget);

      // Select 30 Minutes
      await tester.tap(find.text('30 Minutes'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.duration, equals(const Duration(minutes: 30)));
    });

    testWidgets('TimedSharingBottomSheet indefinite selection returns null duration', (tester) async {
      SharingDurationOption? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimedSharingBottomSheet(
              onDurationSelected: (option) {
                selected = option;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Until Turned Off'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.duration, isNull);
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
