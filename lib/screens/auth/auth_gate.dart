import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../map/map_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  final Stream<User?>? customAuthStream;
  final Widget Function(BuildContext context, User user)? authenticatedBuilder;
  final Widget Function(BuildContext context)? unauthenticatedBuilder;

  const AuthGate({
    super.key,
    this.customAuthStream,
    this.authenticatedBuilder,
    this.unauthenticatedBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final stream = customAuthStream ?? FirebaseAuth.instance.authStateChanges();

    return StreamBuilder<User?>(
      stream: stream,
      builder: (context, snapshot) {
        // While checking existing session cache on device
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF070D18),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
            ),
          );
        }

        // Active session found: bypass login screen completely
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          if (authenticatedBuilder != null) {
            return authenticatedBuilder!(context, user);
          }
          // Trigger profile & background tracking restoration asynchronously
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              if (authProvider.userModel == null) {
                authProvider.refreshProfile();
              }
              final locationProvider = Provider.of<LocationProvider>(context, listen: false);
              locationProvider.restoreTrackingStateIfActive(user.uid);
            } catch (e) {
              debugPrint('Notice: auth gate post-frame restore: $e');
            }
          });
          return const MapScreen();
        }

        // No active session: show login
        if (unauthenticatedBuilder != null) {
          return unauthenticatedBuilder!(context);
        }
        return const LoginScreen();
      },
    );
  }
}
