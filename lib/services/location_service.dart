import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static const double maxAccuracyMeters = 15.0;

  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled.');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions are denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permissions are permanently denied.');
      return false;
    }

    final phStatus = await Permission.location.status;
    if (!phStatus.isGranted) {
      final requested = await Permission.location.request();
      if (!requested.isGranted) return false;
    }

    // Android 13+ (API 33+) Notification Permission check for persistent Foreground Service
    try {
      final notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted) {
        await Permission.notification.request();
      }
    } catch (e) {
      debugPrint('Notice: notification permission check exception: $e');
    }

    return true;
  }

  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkAndRequestPermission();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('Error fetching current position: $e');
      return null;
    }
  }

  static LocationSettings getForegroundLocationSettings({
    int distanceFilter = 5,
    LocationAccuracy accuracy = LocationAccuracy.high,
    String notificationTitle = 'TrackMate Live Sharing',
    String notificationText = 'Sharing your live location in the background',
    bool enableWakeLock = true,
  }) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 3),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: notificationTitle,
          notificationText: notificationText,
          notificationIcon: const AndroidResource(name: 'ic_launcher'),
          enableWakeLock: enableWakeLock,
          setOngoing: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      return LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      );
    }
  }

  Stream<Position> getPositionStream({
    int distanceFilter = 5,
    bool enableForegroundService = true,
    String notificationTitle = 'TrackMate Live Sharing',
    String notificationText = 'Sharing your live location in the background',
  }) {
    final settings = enableForegroundService
        ? getForegroundLocationSettings(
            distanceFilter: distanceFilter,
            notificationTitle: notificationTitle,
            notificationText: notificationText,
          )
        : LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: distanceFilter,
          );

    return Geolocator.getPositionStream(
      locationSettings: settings,
    );
  }

  Stream<Position> getFilteredPositionStream({
    int distanceFilter = 5,
    double maxAccuracyThreshold = maxAccuracyMeters,
    bool enableForegroundService = true,
  }) {
    Position? bestFix;
    return getPositionStream(
      distanceFilter: distanceFilter,
      enableForegroundService: enableForegroundService,
    ).where((position) {
      if (position.accuracy <= maxAccuracyThreshold) {
        bestFix = position;
        return true;
      }
      // If no fix has <= 15m accuracy yet, use best available fix until an accurate fix is obtained
      if (bestFix == null || position.accuracy < bestFix!.accuracy) {
        bestFix = position;
        return true;
      }
      return false;
    });
  }

  Stream<Position> getGroupPositionStream({
    int distanceFilter = 15,
    String? groupTitle,
  }) {
    final text = groupTitle != null && groupTitle.isNotEmpty
        ? 'Sharing live session in $groupTitle'
        : 'Sharing live group tracking session';

    return getPositionStream(
      distanceFilter: distanceFilter,
      enableForegroundService: true,
      notificationTitle: 'TrackMate Group Tracking',
      notificationText: text,
    );
  }

  Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (!status.isGranted) {
        final result = await Permission.ignoreBatteryOptimizations.request();
        return result.isGranted;
      }
      return true;
    } catch (e) {
      debugPrint('Notice: unable to request battery optimization exemption: $e');
      return false;
    }
  }
}
