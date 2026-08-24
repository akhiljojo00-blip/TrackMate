import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trackmate/providers/auth_provider.dart';
import 'package:trackmate/providers/location_provider.dart';
import 'package:trackmate/providers/connection_provider.dart';
import 'package:trackmate/providers/chat_provider.dart';
import 'package:trackmate/providers/sos_provider.dart';
import 'package:trackmate/screens/splash/splash_screen.dart';

void main() {
  group('SplashScreen Widget Tests', () {
    testWidgets('SplashScreen renders app title, subtitle, and creator credit', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => LocationProvider()),
            ChangeNotifierProvider(create: (_) => ConnectionProvider()),
            ChangeNotifierProvider(create: (_) => ChatProvider()),
            ChangeNotifierProvider(create: (_) => SosProvider()),
          ],
          child: const MaterialApp(
            home: SplashScreen(),
          ),
        ),
      );

      // Verify title and subtitle are present
      expect(find.text('TrackMate'), findsOneWidget);
      expect(find.text('Connect  •  Share  •  Secure'), findsOneWidget);

      // Verify creator credit is present
      expect(find.textContaining('AKHIL JOJO'), findsOneWidget);

      // Verify radar icon is present
      expect(find.byIcon(Icons.radar_rounded), findsOneWidget);
    });
  });
}
