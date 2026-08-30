import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmate/screens/map/widgets/about_developer_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AboutDeveloperDialog Tests', () {
    test('Static URLs and Email invariants', () {
      expect(
        AboutDeveloperDialog.developerPortfolioLiveUrl,
        'https://akhiljojo00-blip.github.io/akhil-jojo-portfolio/',
      );
      expect(
        AboutDeveloperDialog.developerPortfolioRepoUrl,
        'https://github.com/akhiljojo00-blip/akhil-jojo-portfolio',
      );
      expect(
        AboutDeveloperDialog.developerEmail,
        'akhiljojo00@gmail.com',
      );
    });

    testWidgets('AboutDeveloperDialog renders developer information and action buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AboutDeveloperDialog(),
          ),
        ),
      );

      expect(find.text('About Developer'), findsOneWidget);
      expect(find.text('Akhil Jojo'), findsOneWidget);
      expect(find.text('Lead Architect & Flutter Developer'), findsOneWidget);
      expect(find.text('Live Portfolio'), findsOneWidget);
      expect(find.text('Portfolio Repository'), findsOneWidget);
      expect(find.text('Contact Developer'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });
  });
}
