import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'constants/app_constants.dart';
import 'providers/auth_provider.dart';
import 'providers/location_provider.dart';
import 'providers/connection_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/sos_provider.dart';
import 'providers/connectivity_provider.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/splash/splash_screen.dart';
import 'services/notification_service.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('Flutter Error: ${details.exceptionAsString()}');
    };

    try {
      await Firebase.initializeApp();
      await NotificationService().initialize();
    } catch (e, stackTrace) {
      debugPrint('Firebase initialization notice: $e');
      debugPrint('Stack trace: $stackTrace');
    }

    runApp(const TrackmateApp());
  }, (error, stackTrace) {
    debugPrint('Uncaught asynchronous error: $error');
    debugPrint('Stack trace: $stackTrace');
  });
}

class TrackmateApp extends StatelessWidget {
  const TrackmateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => ConnectionProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => SosProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const SplashScreen(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthGate();
  }
}
