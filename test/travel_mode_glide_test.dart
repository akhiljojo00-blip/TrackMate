import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trackmate/models/location_model.dart';
import 'package:trackmate/screens/map/map_screen.dart';

void main() {
  group('Travel Mode & Smooth Marker Interpolation Tests', () {
    test('LocationModel defaults to walking travelMode when omitted', () {
      final location = LocationModel(
        userId: 'user_123',
        latitude: 12.9716,
        longitude: 77.5946,
        timestamp: 1700000000000,
      );

      expect(location.travelMode, LocationModel.modeWalking);
      expect(location.toMap()['travelMode'], LocationModel.modeWalking);
    });

    test('LocationModel serializes and deserializes various travel modes', () {
      for (final mode in LocationModel.supportedTravelModes) {
        final location = LocationModel(
          userId: 'user_test',
          latitude: 37.7749,
          longitude: -122.4194,
          timestamp: 1700000000000,
          travelMode: mode,
        );

        final map = location.toMap();
        expect(map['travelMode'], mode);

        final deserialized = LocationModel.fromMap(map, 'user_test');
        expect(deserialized.travelMode, mode);
      }
    });

    test('LocationModel gracefully falls back to walking for unknown travel modes', () {
      final map = {
        'latitude': 10.0,
        'longitude': 20.0,
        'timestamp': 1700000000000,
        'travelMode': 'rocket_ship', // Unsupported
      };

      final parsed = LocationModel.fromMap(map, 'user_invalid');
      expect(parsed.travelMode, LocationModel.modeWalking);
    });

    test('LocationModel copyWith updates travelMode', () {
      final location = LocationModel(
        userId: 'user_1',
        latitude: 10.0,
        longitude: 20.0,
        timestamp: 1000,
        travelMode: LocationModel.modeWalking,
      );

      final updated = location.copyWith(travelMode: LocationModel.modeBiking);
      expect(updated.travelMode, LocationModel.modeBiking);
      expect(updated.userId, 'user_1');
    });

    test('LatLngTween smoothly interpolates coordinates', () {
      final start = const LatLng(10.0, 20.0);
      final end = const LatLng(20.0, 40.0);
      final tween = LatLngTween(begin: start, end: end);

      // t = 0.0 -> Start
      final at0 = tween.lerp(0.0);
      expect(at0.latitude, closeTo(10.0, 0.0001));
      expect(at0.longitude, closeTo(20.0, 0.0001));

      // t = 0.5 -> Midpoint
      final atHalf = tween.lerp(0.5);
      expect(atHalf.latitude, closeTo(15.0, 0.0001));
      expect(atHalf.longitude, closeTo(30.0, 0.0001));

      // t = 1.0 -> End
      final at1 = tween.lerp(1.0);
      expect(at1.latitude, closeTo(20.0, 0.0001));
      expect(at1.longitude, closeTo(40.0, 0.0001));
    });
  });
}
