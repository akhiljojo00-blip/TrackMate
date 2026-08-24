import 'package:flutter_test/flutter_test.dart';
import 'package:trackmate/models/geofence_model.dart';
import 'package:trackmate/models/geofence_state_model.dart';
import 'package:trackmate/utils/geofence_calculator.dart';

void main() {
  group('GeofenceModel Tests', () {
    test('GeofenceModel serializes toMap and deserializes fromMap correctly', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final geofence = GeofenceModel(
        id: 'geo_123',
        name: 'Home Sanctuary',
        latitude: 37.7749,
        longitude: -122.4194,
        radiusMeters: 200.0,
        iconPreset: 1,
        notifyOnEntry: true,
        notifyOnExit: true,
        targetRecipientUids: ['user_bob', 'user_charlie'],
        targetGroupIds: ['group_family'],
        createdAt: now,
        isEnabled: true,
      );

      final map = geofence.toMap();
      expect(map['id'], 'geo_123');
      expect(map['name'], 'Home Sanctuary');
      expect(map['latitude'], 37.7749);
      expect(map['longitude'], -122.4194);
      expect(map['radiusMeters'], 200.0);
      expect(map['iconPreset'], 1);
      expect(map['notifyOnEntry'], true);
      expect(map['notifyOnExit'], true);
      expect(map['targetRecipientUids'], ['user_bob', 'user_charlie']);
      expect(map['targetGroupIds'], ['group_family']);
      expect(map['createdAt'], now);
      expect(map['isEnabled'], true);

      final parsed = GeofenceModel.fromMap(map, 'geo_123');
      expect(parsed.id, 'geo_123');
      expect(parsed.name, 'Home Sanctuary');
      expect(parsed.latitude, 37.7749);
      expect(parsed.longitude, -122.4194);
      expect(parsed.radiusMeters, 200.0);
      expect(parsed.iconPreset, 1);
      expect(parsed.notifyOnEntry, true);
      expect(parsed.notifyOnExit, true);
      expect(parsed.targetRecipientUids, ['user_bob', 'user_charlie']);
      expect(parsed.targetGroupIds, ['group_family']);
      expect(parsed.createdAt, now);
      expect(parsed.isEnabled, true);
    });

    test('GeofenceModel copyWith updates fields properly', () {
      final geofence = GeofenceModel(
        id: 'geo_1',
        name: 'Work',
        latitude: 10.0,
        longitude: 20.0,
        createdAt: 1000,
      );

      final updated = geofence.copyWith(
        name: 'Office HQ',
        radiusMeters: 350.0,
        isEnabled: false,
      );

      expect(updated.id, 'geo_1');
      expect(updated.name, 'Office HQ');
      expect(updated.latitude, 10.0);
      expect(updated.longitude, 20.0);
      expect(updated.radiusMeters, 350.0);
      expect(updated.isEnabled, false);
      expect(updated.createdAt, 1000);
    });
  });

  group('GeofenceStateModel Tests', () {
    test('GeofenceStateModel serializes toMap and deserializes fromMap correctly', () {
      final state = const GeofenceStateModel(
        geofenceId: 'geo_123',
        isInside: true,
        lastEvaluatedAt: 5000,
        lastTriggeredState: 'entered',
        lastTriggeredAt: 4800,
      );

      final map = state.toMap();
      expect(map['geofenceId'], 'geo_123');
      expect(map['isInside'], true);
      expect(map['lastEvaluatedAt'], 5000);
      expect(map['lastTriggeredState'], 'entered');
      expect(map['lastTriggeredAt'], 4800);

      final parsed = GeofenceStateModel.fromMap(map, 'geo_123');
      expect(parsed.geofenceId, 'geo_123');
      expect(parsed.isInside, true);
      expect(parsed.lastEvaluatedAt, 5000);
      expect(parsed.lastTriggeredState, 'entered');
      expect(parsed.lastTriggeredAt, 4800);
    });

    test('GeofenceStateModel copyWith updates fields properly', () {
      final state = const GeofenceStateModel(
        geofenceId: 'geo_1',
        isInside: false,
        lastEvaluatedAt: 1000,
      );

      final updated = state.copyWith(
        isInside: true,
        lastTriggeredState: 'entered',
        lastTriggeredAt: 1200,
      );

      expect(updated.geofenceId, 'geo_1');
      expect(updated.isInside, true);
      expect(updated.lastTriggeredState, 'entered');
      expect(updated.lastTriggeredAt, 1200);
    });
  });

  group('GeofenceCalculator Tests', () {
    test('calculateDistanceMeters returns 0 for identical points', () {
      final dist = GeofenceCalculator.calculateDistanceMeters(
        lat1: 37.7749,
        lon1: -122.4194,
        lat2: 37.7749,
        lon2: -122.4194,
      );
      expect(dist, 0.0);
    });

    test('calculateDistanceMeters calculates accurate distance for known coordinates', () {
      // Bangalore (12.9716, 77.5946) to Mysore (12.2958, 76.6394) ~ 128 km
      final dist = GeofenceCalculator.calculateDistanceMeters(
        lat1: 12.9716,
        lon1: 77.5946,
        lat2: 12.2958,
        lon2: 76.6394,
      );
      expect(dist, greaterThan(125000));
      expect(dist, lessThan(132000));

      // Small offset: 0.001 degrees latitude difference ~ 111.19 meters
      final smallDist = GeofenceCalculator.calculateDistanceMeters(
        lat1: 0.0,
        lon1: 0.0,
        lat2: 0.001,
        lon2: 0.0,
      );
      expect(smallDist, closeTo(111.19, 1.0));
    });

    test('isCoordinateInsideGeofence correctly identifies inside and outside states', () {
      final geofence = GeofenceModel(
        id: 'fence_1',
        name: 'Safe Zone',
        latitude: 0.0,
        longitude: 0.0,
        radiusMeters: 100.0,
        createdAt: 0,
      );

      // Point at center (0m away)
      expect(
        GeofenceCalculator.isCoordinateInsideGeofence(
          currentLat: 0.0,
          currentLon: 0.0,
          geofence: geofence,
        ),
        isTrue,
      );

      // Point ~55m away (0.0005 deg lat) -> Inside 100m radius
      expect(
        GeofenceCalculator.isCoordinateInsideGeofence(
          currentLat: 0.0005,
          currentLon: 0.0,
          geofence: geofence,
        ),
        isTrue,
      );

      // Point ~222m away (0.002 deg lat) -> Outside 100m radius
      expect(
        GeofenceCalculator.isCoordinateInsideGeofence(
          currentLat: 0.002,
          currentLon: 0.0,
          geofence: geofence,
        ),
        isFalse,
      );

      // Point ~111m away (0.001 deg lat) -> Outside 100m radius without buffer, Inside with 20m buffer (100+20=120m)
      expect(
        GeofenceCalculator.isCoordinateInsideGeofence(
          currentLat: 0.001,
          currentLon: 0.0,
          geofence: geofence,
          bufferMeters: 0.0,
        ),
        isFalse,
      );
      expect(
        GeofenceCalculator.isCoordinateInsideGeofence(
          currentLat: 0.001,
          currentLon: 0.0,
          geofence: geofence,
          bufferMeters: 20.0,
        ),
        isTrue,
      );
    });
  });
}
