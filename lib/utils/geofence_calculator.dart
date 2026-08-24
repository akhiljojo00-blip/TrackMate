import 'dart:math' as math;
import '../models/geofence_model.dart';

class GeofenceCalculator {
  static const double earthRadiusMeters = 6371000.0;

  /// Calculates distance in meters between two coordinates using the Haversine formula.
  static double calculateDistanceMeters({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    if (lat1 == lat2 && lon1 == lon2) {
      return 0.0;
    }

    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLon = (lon2 - lon1) * (math.pi / 180.0);

    final rLat1 = lat1 * (math.pi / 180.0);
    final rLat2 = lat2 * (math.pi / 180.0);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rLat1) * math.cos(rLat2) * math.sin(dLon / 2) * math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  /// Evaluates whether a coordinate point falls inside a geofence radius (with optional buffer).
  static bool isCoordinateInsideGeofence({
    required double currentLat,
    required double currentLon,
    required GeofenceModel geofence,
    double bufferMeters = 0.0,
  }) {
    final distance = calculateDistanceMeters(
      lat1: currentLat,
      lon1: currentLon,
      lat2: geofence.latitude,
      lon2: geofence.longitude,
    );
    return distance <= (geofence.radiusMeters + bufferMeters);
  }
}
