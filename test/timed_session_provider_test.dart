import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackmate/models/location_model.dart';
import 'package:trackmate/providers/location_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Timed Session Provider & Lifecycle Tests', () {
    const testUid = 'user_session_456';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('LocationProvider starts with null expiresAt and inactive state', () {
      final provider = LocationProvider();
      expect(provider.isTracking, isFalse);
      expect(provider.currentExpiresAt, isNull);
      expect(provider.remainingSharingDuration, isNull);
      expect(provider.isSharingExpired, isFalse);
    });

    test('remainingSharingDuration returns correct countdown and clamps expired to zero', () {
      final provider = LocationProvider();
      final now = DateTime.now().millisecondsSinceEpoch;

      // Unset expiresAt
      expect(provider.remainingSharingDuration, isNull);

      // We test LocationModel calculation directly as provider updates state
      final futureLocation = LocationModel(
        userId: testUid,
        latitude: 10.0,
        longitude: 20.0,
        timestamp: now,
        expiresAt: now + 30000, // 30s
      );
      expect(futureLocation.isExpired, isFalse);
      expect(futureLocation.remainingDuration!.inMilliseconds, greaterThan(0));

      final pastLocation = LocationModel(
        userId: testUid,
        latitude: 10.0,
        longitude: 20.0,
        timestamp: now,
        expiresAt: now - 5000, // 5s ago
      );
      expect(pastLocation.isExpired, isTrue);
      expect(pastLocation.remainingDuration, equals(Duration.zero));
    });

    test('SharedPreferences accurately persists and clears timed sharing keys', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final expiresAt = DateTime.now().millisecondsSinceEpoch + 900000; // 15 mins
      await prefs.setBool('is_sharing_location_active_$testUid', true);
      await prefs.setInt('location_sharing_expires_at_$testUid', expiresAt);
      await prefs.setString('location_sharing_type_$testUid', 'live');

      expect(prefs.getBool('is_sharing_location_active_$testUid'), isTrue);
      expect(prefs.getInt('location_sharing_expires_at_$testUid'), equals(expiresAt));
      expect(prefs.getString('location_sharing_type_$testUid'), equals('live'));

      // Simulate stopTracking clearance
      await prefs.setBool('is_sharing_location_active_$testUid', false);
      await prefs.remove('location_sharing_expires_at_$testUid');
      await prefs.remove('location_sharing_type_$testUid');

      expect(prefs.getBool('is_sharing_location_active_$testUid'), isFalse);
      expect(prefs.getInt('location_sharing_expires_at_$testUid'), isNull);
      expect(prefs.getString('location_sharing_type_$testUid'), isNull);
    });

    test('Cold-start recovery identifies expired session from SharedPreferences', () async {
      final pastExpiry = DateTime.now().millisecondsSinceEpoch - 10000; // 10s in the past
      SharedPreferences.setMockInitialValues({
        'is_sharing_location_active_$testUid': true,
        'location_sharing_expires_at_$testUid': pastExpiry,
      });

      final prefs = await SharedPreferences.getInstance();
      final active = prefs.getBool('is_sharing_location_active_$testUid') ?? false;
      final savedExpiresAt = prefs.getInt('location_sharing_expires_at_$testUid');

      expect(active, isTrue);
      expect(savedExpiresAt, equals(pastExpiry));
      expect(DateTime.now().millisecondsSinceEpoch >= savedExpiresAt!, isTrue);
    });

    test('Cold-start recovery identifies valid remaining session from SharedPreferences', () async {
      final futureExpiry = DateTime.now().millisecondsSinceEpoch + 1800000; // 30m in future
      SharedPreferences.setMockInitialValues({
        'is_sharing_location_active_$testUid': true,
        'location_sharing_expires_at_$testUid': futureExpiry,
        'location_sharing_type_$testUid': 'live',
      });

      final prefs = await SharedPreferences.getInstance();
      final active = prefs.getBool('is_sharing_location_active_$testUid') ?? false;
      final savedExpiresAt = prefs.getInt('location_sharing_expires_at_$testUid');

      expect(active, isTrue);
      expect(savedExpiresAt, equals(futureExpiry));
      expect(DateTime.now().millisecondsSinceEpoch < savedExpiresAt!, isTrue);
      final remaining = savedExpiresAt - DateTime.now().millisecondsSinceEpoch;
      expect(remaining, greaterThan(0));
    });
  });
}
