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
      return requested.isGranted;
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

  Stream<Position> getPositionStream({
    int distanceFilter = 5,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    );
  }

  Stream<Position> getFilteredPositionStream({
    int distanceFilter = 5,
    double maxAccuracyThreshold = maxAccuracyMeters,
  }) {
    Position? bestFix;
    return getPositionStream(distanceFilter: distanceFilter).where((position) {
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
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    );
  }
}
