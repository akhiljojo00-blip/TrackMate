import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackmate/providers/location_provider.dart';
import 'package:trackmate/services/location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Background Location & Foreground Service Tests', () {
    test('getForegroundLocationSettings configures notification, channel and wakeLock parameters', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final settings = LocationService.getForegroundLocationSettings(
        distanceFilter: 10,
        accuracy: LocationAccuracy.high,
        notificationTitle: 'Custom Title',
        notificationText: 'Custom Body Text',
        enableWakeLock: true,
      );

      expect(settings, isA<AndroidSettings>());
      final androidSettings = settings as AndroidSettings;
      expect(androidSettings.accuracy, LocationAccuracy.high);
      expect(androidSettings.distanceFilter, 10);
      expect(androidSettings.foregroundNotificationConfig, isNotNull);
      expect(androidSettings.foregroundNotificationConfig!.notificationTitle, 'Custom Title');
      expect(androidSettings.foregroundNotificationConfig!.notificationText, 'Custom Body Text');
      expect(androidSettings.foregroundNotificationConfig!.enableWakeLock, isTrue);
      expect(androidSettings.foregroundNotificationConfig!.setOngoing, isTrue);

      debugDefaultTargetPlatformOverride = null;
    });

    test('getForegroundLocationSettings configures AppleSettings on iOS platform', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      final settings = LocationService.getForegroundLocationSettings(
        distanceFilter: 8,
        accuracy: LocationAccuracy.best,
      );

      expect(settings, isA<AppleSettings>());
      final appleSettings = settings as AppleSettings;
      expect(appleSettings.accuracy, LocationAccuracy.best);
      expect(appleSettings.distanceFilter, 8);
      expect(appleSettings.showBackgroundLocationIndicator, isTrue);
      expect(appleSettings.pauseLocationUpdatesAutomatically, isFalse);

      debugDefaultTargetPlatformOverride = null;
    });

    test('LocationService maxAccuracyMeters is 15.0m', () {
      expect(LocationService.maxAccuracyMeters, equals(15.0));
      expect(LocationProvider.maxAccuracyMeters, equals(15.0));
    });

    test('LocationProvider initial background state is inactive', () {
      final provider = LocationProvider();
      expect(provider.isTracking, isFalse);
      expect(provider.trackingStartTime, isNull);
      expect(provider.currentPosition, isNull);
      expect(provider.currentLocationModel, isNull);
    });

    test('SharedPreferences restores inactive state correctly', () async {
      SharedPreferences.setMockInitialValues({
        'is_sharing_location_active_user_test': false,
      });

      final prefs = await SharedPreferences.getInstance();
      final isActive = prefs.getBool('is_sharing_location_active_user_test');
      expect(isActive, isFalse);
    });

    test('SharedPreferences persists active state correctly', () async {
      SharedPreferences.setMockInitialValues({});

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_sharing_location_active_user_123', true);
      expect(prefs.getBool('is_sharing_location_active_user_123'), isTrue);

      await prefs.setBool('is_sharing_location_active_user_123', false);
      expect(prefs.getBool('is_sharing_location_active_user_123'), isFalse);
    });
  });
}
