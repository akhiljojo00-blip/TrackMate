import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trackmate/providers/location_provider.dart';

void main() {
  group('GPS Accuracy Filter & Distance Precision Tests', () {
    test('formatDistance formats distances < 1000m rounded to nearest 5 meters', () {
      expect(LocationProvider.formatDistance(-10), '0 m');
      expect(LocationProvider.formatDistance(0), '0 m');
      expect(LocationProvider.formatDistance(2), '0 m');
      expect(LocationProvider.formatDistance(4), '5 m');
      expect(LocationProvider.formatDistance(23), '25 m');
      expect(LocationProvider.formatDistance(248), '250 m');
      expect(LocationProvider.formatDistance(250), '250 m');
      expect(LocationProvider.formatDistance(252), '250 m');
      expect(LocationProvider.formatDistance(783), '785 m');
      expect(LocationProvider.formatDistance(994), '995 m');
      // Edge case: 998 rounds to 1000m -> clean km format
      expect(LocationProvider.formatDistance(998), '1.0 km');
    });

    test('formatDistance formats distances >= 1000m as X.X km', () {
      expect(LocationProvider.formatDistance(1000), '1.0 km');
      expect(LocationProvider.formatDistance(1500), '1.5 km');
      expect(LocationProvider.formatDistance(2400), '2.4 km');
      expect(LocationProvider.formatDistance(10500), '10.5 km');
      expect(LocationProvider.formatDistance(25750), '25.8 km');
    });

    test('shouldAcceptPosition accepts fixes <= 15.0m accuracy', () {
      final accurateCandidate = Position(
        longitude: 77.5946,
        latitude: 12.9716,
        timestamp: DateTime.now(),
        accuracy: 8.5,
        altitude: 900.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 1.0,
      );

      final currentAccurate = Position(
        longitude: 77.5946,
        latitude: 12.9716,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 900.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 1.0,
      );

      // Candidate with 8.5m <= 15m is accepted
      expect(LocationProvider.shouldAcceptPosition(accurateCandidate, currentAccurate), isTrue);
      expect(LocationProvider.shouldAcceptPosition(accurateCandidate, null), isTrue);
    });

    test('shouldAcceptPosition accepts best available fix when no fix <= 15m exists yet', () {
      final initialCoarse = Position(
        longitude: 77.5946,
        latitude: 12.9716,
        timestamp: DateTime.now(),
        accuracy: 45.0,
        altitude: 900.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 1.0,
      );

      // When no fix is available yet, coarse candidate is accepted as fallback
      expect(LocationProvider.shouldAcceptPosition(initialCoarse, null), isTrue);

      final betterCoarse = Position(
        longitude: 77.5946,
        latitude: 12.9716,
        timestamp: DateTime.now(),
        accuracy: 25.0,
        altitude: 900.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 1.0,
      );

      // 25m is better than 45m -> accepted
      expect(LocationProvider.shouldAcceptPosition(betterCoarse, initialCoarse), isTrue);
    });

    test('shouldAcceptPosition discards inaccurate fixes (> 15m) when an accurate fix is already acquired', () {
      final accurateFix = Position(
        longitude: 77.5946,
        latitude: 12.9716,
        timestamp: DateTime.now(),
        accuracy: 6.0,
        altitude: 900.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 1.0,
      );

      final noisyDrift = Position(
        longitude: 77.5946,
        latitude: 12.9716,
        timestamp: DateTime.now(),
        accuracy: 28.0,
        altitude: 900.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 1.0,
      );

      // 28.0m drift discarded because current fix is accurate (6.0m <= 15m)
      expect(LocationProvider.shouldAcceptPosition(noisyDrift, accurateFix), isFalse);
    });
  });
}
