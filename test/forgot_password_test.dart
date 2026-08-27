import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trackmate/providers/auth_provider.dart';
import 'package:trackmate/providers/connection_provider.dart';
import 'package:trackmate/providers/connectivity_provider.dart';
import 'package:trackmate/providers/location_provider.dart';
import 'package:trackmate/providers/sos_provider.dart';
import 'package:trackmate/screens/auth/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createLoginTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => ConnectionProvider()),
        ChangeNotifierProvider(create: (_) => SosProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
      ],
      child: const MaterialApp(
        home: LoginScreen(),
      ),
    );
  }

  group('Self-Service Password Reset Tests', () {
    test('AuthProvider.sendPasswordReset throws for empty email', () async {
      final authProvider = AuthProvider();
      expect(
        () => authProvider.sendPasswordReset('   '),
        throwsA('Please enter your email address.'),
      );
    });

    testWidgets('LoginScreen renders Forgot Password button and opens Reset Password dialog', (tester) async {
      await tester.pumpWidget(createLoginTestWidget());

      expect(find.text('Forgot Password?'), findsOneWidget);

      // Tap Forgot Password
      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Enter your account email to receive a password reset link.'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Send Reset Link with empty input
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email.'), findsOneWidget);

      // Enter invalid format
      await tester.enterText(find.byType(TextFormField).last, 'invalidemail');
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email.'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Reset Password'), findsNothing);
    });
  });
}
