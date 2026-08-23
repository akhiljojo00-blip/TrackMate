import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trackmate/providers/location_provider.dart';

void main() {
  group('Distance Engine & Formatting Tests', () {
    test('formatDistance formats sub-kilometer meters correctly', () {
      expect(LocationProvider.formatDistance(0), '0 m');
      expect(LocationProvider.formatDistance(45.2), '45 m');
      expect(LocationProvider.formatDistance(150), '150 m');
      expect(LocationProvider.formatDistance(999.4), '999 m');
    });

    test('formatDistance formats single-decimal kilometers (<10km)', () {
      expect(LocationProvider.formatDistance(1000), '1.0 km');
      expect(LocationProvider.formatDistance(1250), '1.3 km');
      expect(LocationProvider.formatDistance(2400), '2.4 km');
      expect(LocationProvider.formatDistance(9890), '9.9 km');
    });

    test('formatDistance formats whole kilometers (>=10km)', () {
      expect(LocationProvider.formatDistance(10000), '10 km');
      expect(LocationProvider.formatDistance(25400), '25 km');
      expect(LocationProvider.formatDistance(100000), '100 km');
    });

    test('formatDistance handles negative values defensively', () {
      expect(LocationProvider.formatDistance(-10), '0 m');
    });

    test('Geolocator distanceBetween calculates accurate distance between two coordinates', () {
      // Distance between Statue of Liberty (40.6892, -74.0445) and Empire State Building (40.7484, -73.9857)
      final distance = Geolocator.distanceBetween(
        40.6892,
        -74.0445,
        40.7484,
        -73.9857,
      );

      // Expected approx 8.3 - 8.4 km (8300 - 8400 meters)
      expect(distance, greaterThan(8000));
      expect(distance, lessThan(9000));
      expect(LocationProvider.formatDistance(distance), matches(r'^8\.[0-9] km$'));
    });
  });
}
