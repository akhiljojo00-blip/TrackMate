import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmate/screens/auth/auth_gate.dart';

class MockUser extends Fake implements User {
  @override
  String get uid => 'test_user_uid_123';

  @override
  String? get email => 'testuser@example.com';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Reactive AuthGate Routing Tests', () {
    testWidgets('AuthGate displays CircularProgressIndicator when connection is waiting', (tester) async {
      final controller = StreamController<User?>();

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            customAuthStream: controller.stream,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await controller.close();
    });

    testWidgets('AuthGate routes to unauthenticated destination when stream emits null', (tester) async {
      final controller = StreamController<User?>();

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            customAuthStream: controller.stream,
            unauthenticatedBuilder: (_) => const Scaffold(body: Text('LOGIN_SCREEN_DESTINATION')),
            authenticatedBuilder: (_, __) => const Scaffold(body: Text('MAP_SCREEN_DESTINATION')),
          ),
        ),
      );

      controller.add(null);
      await tester.pump();

      expect(find.text('LOGIN_SCREEN_DESTINATION'), findsOneWidget);
      expect(find.text('MAP_SCREEN_DESTINATION'), findsNothing);

      await controller.close();
    });

    testWidgets('AuthGate routes to authenticated destination when stream emits active User', (tester) async {
      final controller = StreamController<User?>();
      final mockUser = MockUser();

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            customAuthStream: controller.stream,
            unauthenticatedBuilder: (_) => const Scaffold(body: Text('LOGIN_SCREEN_DESTINATION')),
            authenticatedBuilder: (_, user) => Scaffold(body: Text('MAP_SCREEN_DESTINATION_${user.uid}')),
          ),
        ),
      );

      controller.add(mockUser);
      await tester.pump();

      expect(find.text('MAP_SCREEN_DESTINATION_test_user_uid_123'), findsOneWidget);
      expect(find.text('LOGIN_SCREEN_DESTINATION'), findsNothing);

      await controller.close();
    });
  });
}
