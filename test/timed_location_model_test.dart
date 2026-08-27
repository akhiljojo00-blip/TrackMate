import 'package:flutter_test/flutter_test.dart';
import 'package:trackmate/models/location_model.dart';

void main() {
  group('Timed Location Model & Serialization Tests', () {
    const testUid = 'user_timed_123';
    final now = DateTime.now().millisecondsSinceEpoch;

    test('LocationModel serializes and deserializes expiresAt and sharingType accurately', () {
      final expiresAt = now + 3600000; // 1 hour in the future
      final location = LocationModel(
        userId: testUid,
        latitude: 37.7749,
        longitude: -122.4194,
        heading: 90.0,
        speed: 1.5,
        accuracy: 5.0,
        timestamp: now,
        travelMode: LocationModel.modeBiking,
        expiresAt: expiresAt,
        sharingType: LocationModel.sharingTypeLive,
      );

      final map = location.toMap();
      expect(map['expiresAt'], equals(expiresAt));
      expect(map['sharingType'], equals('live'));

      final parsed = LocationModel.fromMap(map, testUid);
      expect(parsed.userId, equals(testUid));
      expect(parsed.latitude, equals(37.7749));
      expect(parsed.longitude, equals(-122.4194));
      expect(parsed.travelMode, equals(LocationModel.modeBiking));
      expect(parsed.expiresAt, equals(expiresAt));
      expect(parsed.sharingType, equals(LocationModel.sharingTypeLive));
    });

    test('Backward Compatibility: Missing expiresAt and sharingType defaults gracefully', () {
      final legacyMap = {
        'latitude': 40.7128,
        'longitude': -74.0060,
        'heading': 180.0,
        'speed': 0.0,
        'accuracy': 10.0,
        'timestamp': now,
        'travelMode': 'walking',
      };

      final parsed = LocationModel.fromMap(legacyMap, testUid);
      expect(parsed.expiresAt, isNull);
      expect(parsed.sharingType, equals(LocationModel.sharingTypeLive));
      expect(parsed.isIndefinite, isTrue);
      expect(parsed.isExpired, isFalse);
      expect(parsed.remainingDuration, isNull);
    });

    test('Active Session: expiresAt in the future is not expired and has remaining duration', () {
      final futureExpiry = DateTime.now().millisecondsSinceEpoch + 60000; // +1 minute
      final location = LocationModel(
        userId: testUid,
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: now,
        expiresAt: futureExpiry,
      );

      expect(location.isExpired, isFalse);
      expect(location.isIndefinite, isFalse);
      expect(location.remainingDuration, isNotNull);
      expect(location.remainingDuration!.inMilliseconds, greaterThan(0));
    });

    test('Expired Session: expiresAt in the past evaluates as expired and zero remaining duration', () {
      final pastExpiry = DateTime.now().millisecondsSinceEpoch - 5000; // 5 seconds ago
      final location = LocationModel(
        userId: testUid,
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: now - 10000,
        expiresAt: pastExpiry,
      );

      expect(location.isExpired, isTrue);
      expect(location.isIndefinite, isFalse);
      expect(location.remainingDuration, equals(Duration.zero));
    });

    test('Indefinite Session: null expiresAt has null remaining duration and isIndefinite == true', () {
      final location = LocationModel(
        userId: testUid,
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: now,
        expiresAt: null,
      );

      expect(location.isIndefinite, isTrue);
      expect(location.isExpired, isFalse);
      expect(location.remainingDuration, isNull);
    });

    test('copyWith properly updates expiresAt or clears it with clearExpiresAt flag', () {
      final initial = LocationModel(
        userId: testUid,
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: now,
        expiresAt: now + 1800000,
        sharingType: LocationModel.sharingTypeLive,
      );

      // Extend duration
      final newExpiry = now + 3600000;
      final extended = initial.copyWith(expiresAt: newExpiry);
      expect(extended.expiresAt, equals(newExpiry));
      expect(extended.sharingType, equals(LocationModel.sharingTypeLive));

      // Reset to indefinite sharing
      final indefinite = extended.copyWith(clearExpiresAt: true);
      expect(indefinite.expiresAt, isNull);
      expect(indefinite.isIndefinite, isTrue);

      // Update sharingType
      final staticLocation = initial.copyWith(sharingType: LocationModel.sharingTypeStatic);
      expect(staticLocation.sharingType, equals(LocationModel.sharingTypeStatic));
    });
  });
}
