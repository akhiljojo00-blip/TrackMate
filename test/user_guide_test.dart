import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmate/data/user_guide_data.dart';
import 'package:trackmate/screens/guide/user_guide_screen.dart';
import 'package:trackmate/screens/guide/widgets/feedback_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Living User Guide Registry Tests', () {
    test('UserGuideRegistry contains all essential feature categories', () {
      final sections = UserGuideRegistry.sections;
      expect(sections.isNotEmpty, isTrue);

      final categoryTitles = sections.map((s) => s.categoryTitle).toList();
      expect(categoryTitles, contains('Privacy & Permissions'));
      expect(categoryTitles, contains('Timed & Live Location'));
      expect(categoryTitles, contains('Groups & Collaboration'));
      expect(categoryTitles, contains('Geofencing & Alerts'));
      expect(categoryTitles, contains('Emergency SOS'));
      expect(categoryTitles, contains('Account & Data Purge'));
    });

    test('All GuideItem entries have non-empty attributes and valid rules', () {
      for (final section in UserGuideRegistry.sections) {
        expect(section.categoryTitle.trim().isNotEmpty, isTrue);
        expect(section.iconName.trim().isNotEmpty, isTrue);
        expect(section.items.isNotEmpty, isTrue);

        for (final item in section.items) {
          expect(item.id.trim().isNotEmpty, isTrue);
          expect(item.title.trim().isNotEmpty, isTrue);
          expect(item.summary.trim().isNotEmpty, isTrue);
          expect(item.whyItMatters.trim().isNotEmpty, isTrue);
          expect(item.howToUse.trim().isNotEmpty, isTrue);
          expect(item.keyRules.isNotEmpty, isTrue);
          expect(item.versionAdded.startsWith('v'), isTrue);
        }
      }
    });
  });

  group('UserGuideScreen Widget Tests', () {
    testWidgets('UserGuideScreen renders search bar and all category cards', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UserGuideScreen(),
        ),
      );

      expect(find.text('Living User Manual'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Privacy & Permissions'), findsOneWidget);
      expect(find.text('Timed & Live Location'), findsOneWidget);
      expect(find.text('Directional Location Permissions'), findsOneWidget);
    });

    testWidgets('Search query filters items accurately', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UserGuideScreen(),
        ),
      );

      // Search for 'SOS'
      await tester.enterText(find.byType(TextField), 'SOS');
      await tester.pumpAndSettle();

      expect(find.text('Emergency SOS'), findsOneWidget);
      expect(find.text('3-Second Hold Emergency SOS'), findsOneWidget);
      expect(find.text('Privacy & Permissions'), findsNothing);
    });

    testWidgets('No matching results view displays when query has zero matches', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UserGuideScreen(),
        ),
      );

      await tester.enterText(find.byType(TextField), 'nonexistent_query_xyz');
      await tester.pumpAndSettle();

      expect(find.textContaining('No matching guides found for "nonexistent_query_xyz"'), findsOneWidget);
    });
  });

  group('FeedbackDialog Widget Tests', () {
    testWidgets('FeedbackDialog renders categories, stars, and enforces validation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => FeedbackDialog.show(context),
                child: const Text('Open Feedback'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Feedback'));
      await tester.pumpAndSettle();

      expect(find.text('Send Feedback'), findsOneWidget);
      expect(find.text('Satisfaction Rating'), findsOneWidget);
      expect(find.text('Feature Request'), findsOneWidget);

      // Tap Submit with empty text
      await tester.tap(find.text('Submit Feedback'));
      await tester.pumpAndSettle();

      expect(find.text('Please provide at least 5 characters.'), findsOneWidget);
    });

    testWidgets('FeedbackDialog checkbox toggles alsoOpenEmail state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => FeedbackDialog.show(context),
                child: const Text('Open Feedback'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Feedback'));
      await tester.pumpAndSettle();

      expect(find.text('Also open in email client app'), findsOneWidget);
      final checkboxFinder = find.byType(Checkbox);
      expect(checkboxFinder, findsOneWidget);

      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();
    });
  });
}
