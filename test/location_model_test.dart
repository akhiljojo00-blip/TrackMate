import 'package:flutter_test/flutter_test.dart';
import 'package:trackmate/models/location_model.dart';

void main() {
  group('LocationModel Tests', () {
    test('LocationModel serializes toMap and deserializes fromMap correctly', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final location = LocationModel(
        userId: 'user_123',
        latitude: 37.7749,
        longitude: -122.4194,
        heading: 90.0,
        speed: 5.5,
        accuracy: 10.0,
        timestamp: now,
      );

      final map = location.toMap();
      expect(map['userId'], 'user_123');
      expect(map['latitude'], 37.7749);
      expect(map['longitude'], -122.4194);
      expect(map['heading'], 90.0);
      expect(map['speed'], 5.5);
      expect(map['accuracy'], 10.0);
      expect(map['timestamp'], now);

      final parsed = LocationModel.fromMap(map, 'user_123');
      expect(parsed.userId, 'user_123');
      expect(parsed.latitude, 37.7749);
      expect(parsed.longitude, -122.4194);
      expect(parsed.heading, 90.0);
      expect(parsed.speed, 5.5);
      expect(parsed.accuracy, 10.0);
      expect(parsed.timestamp, now);
    });

    test('LocationModel handles ISO8601 string timestamps gracefully', () {
      final isoString = '2026-08-23T12:00:00.000Z';
      final expectedEpoch = DateTime.parse(isoString).millisecondsSinceEpoch;

      final map = {
        'latitude': 40.7128,
        'longitude': -74.0060,
        'timestamp': isoString,
      };

      final parsed = LocationModel.fromMap(map, 'user_nyc');
      expect(parsed.userId, 'user_nyc');
      expect(parsed.latitude, 40.7128);
      expect(parsed.longitude, -74.0060);
      expect(parsed.timestamp, expectedEpoch);
    });

    test('LocationModel copyWith updates fields properly', () {
      final location = LocationModel(
        userId: 'user_1',
        latitude: 10.0,
        longitude: 20.0,
        timestamp: 1000,
      );

      final updated = location.copyWith(
        latitude: 12.0,
        speed: 15.0,
      );

      expect(updated.userId, 'user_1');
      expect(updated.latitude, 12.0);
      expect(updated.longitude, 20.0);
      expect(updated.speed, 15.0);
      expect(updated.timestamp, 1000);
    });
  });
}
