import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackmate/models/location_model.dart';
import 'package:trackmate/providers/connectivity_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Stationary Heartbeat & Screen-Off Telemetry Tests', () {
    const testUid = 'user_heartbeat_001';
    final now = DateTime.now().millisecondsSinceEpoch;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Fresh heartbeat timestamp (< 35s) passes telemetry freshness check', () {
      final freshHeartbeatTimestamp = now - 35000; // 35s ago

      final isStale = ConnectivityProvider.isTelemetryStale(
        freshHeartbeatTimestamp,
        now: now,
        thresholdMs: 120000, // 2 mins
      );

      expect(isStale, isFalse);
    });

    test('Telemetry older than 120s without heartbeat triggers stale warning', () {
      final staleTimestamp = now - 125000; // 125s ago (> 120s)

      final isStale = ConnectivityProvider.isTelemetryStale(
        staleTimestamp,
        now: now,
        thresholdMs: 120000,
      );

      expect(isStale, isTrue);
    });

    test('Stationary heartbeat update produces updated LocationModel with fresh timestamp', () {
      final initialLocation = LocationModel(
        userId: testUid,
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: now - 30000,
        travelMode: LocationModel.modeWalking,
        expiresAt: now + 1800000,
        sharingType: LocationModel.sharingTypeLive,
      );

      final heartbeatNow = DateTime.now().millisecondsSinceEpoch;
      final heartbeatLocation = initialLocation.copyWith(
        timestamp: heartbeatNow,
      );

      expect(heartbeatLocation.timestamp, equals(heartbeatNow));
      expect(heartbeatLocation.latitude, equals(37.7749));
      expect(heartbeatLocation.longitude, equals(-122.4194));
      expect(heartbeatLocation.expiresAt, equals(initialLocation.expiresAt));
      expect(ConnectivityProvider.isTelemetryStale(heartbeatLocation.timestamp, now: heartbeatNow), isFalse);
    });
  });
}
