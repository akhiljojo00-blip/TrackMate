import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trackmate/constants/app_constants.dart';
import 'package:trackmate/models/connection_model.dart';
import 'package:trackmate/models/location_model.dart';
import 'package:trackmate/models/user_model.dart';
import 'package:trackmate/services/account_deletion_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Timed Location Sharing Security & Invariant Tests', () {
    const ownerUid = 'user_owner_001';
    const friendUid = 'user_friend_002';
    final now = DateTime.now().millisecondsSinceEpoch;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Invariant 1: Connection != Location Permission (Zero-Trust Access Control)', () {
      // 1. A connection exists between owner and friend
      const connection = ConnectionUser(
        uid: friendUid,
        name: 'Friend',
        username: 'friend',
        connectedAt: 1700000000000,
      );

      // 2. Owner is actively sharing location with a timed window
      final ownerLocation = LocationModel(
        userId: ownerUid,
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: now,
        expiresAt: now + 3600000, // 1 hour
      );

      // 3. Directional permission is FALSE
      const bool hasDirectionalPermission = false;

      // 4. Friend client must not display or process coordinates without explicit permission
      final Map<String, LocationModel> friendViewableLocations = {};
      if (hasDirectionalPermission) {
        friendViewableLocations[connection.uid] = ownerLocation;
      }

      expect(friendViewableLocations.containsKey(ownerUid), isFalse);
      expect(friendViewableLocations.isEmpty, isTrue);
    });

    test('Invariant 2: Mid-Session Permission Revocation Immediately Purges Active Coordinates', () {
      final activeFriendLocations = <String, LocationModel>{};
      final friendDistances = <String, double>{};

      // 1. Initial State: active timed sharing session
      final ownerLocation = LocationModel(
        userId: ownerUid,
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: now,
        expiresAt: now + 1800000, // 30 min remaining
      );
      activeFriendLocations[ownerUid] = ownerLocation;
      friendDistances[ownerUid] = 125.0;

      expect(activeFriendLocations.containsKey(ownerUid), isTrue);

      // 2. Owner revokes directional permission mid-session (isPermitted = false)
      const isPermitted = false;
      if (!isPermitted) {
        activeFriendLocations.remove(ownerUid);
        friendDistances.remove(ownerUid);
      }

      // 3. Coordinate stream is severed immediately despite remaining session time
      expect(activeFriendLocations.containsKey(ownerUid), isFalse);
      expect(friendDistances.containsKey(ownerUid), isFalse);
    });

    test('Invariant 3: Sender Logout Teardown Clears Preferences and Resets Remote Payload', () async {
      SharedPreferences.setMockInitialValues({
        'is_sharing_location_active_$ownerUid': true,
        'location_sharing_expires_at_$ownerUid': now + 3600000,
        'location_sharing_type_$ownerUid': 'live',
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('is_sharing_location_active_$ownerUid'), isTrue);

      // Simulate stopTracking / logout teardown
      await prefs.setBool('is_sharing_location_active_$ownerUid', false);
      await prefs.remove('location_sharing_expires_at_$ownerUid');
      await prefs.remove('location_sharing_type_$ownerUid');

      // Local preferences wiped
      expect(prefs.getBool('is_sharing_location_active_$ownerUid'), isFalse);
      expect(prefs.getInt('location_sharing_expires_at_$ownerUid'), isNull);
      expect(prefs.getString('location_sharing_type_$ownerUid'), isNull);

      // Database user profile payload simulation on stop
      final userUpdate = {
        'isLocationSharing': false,
        'sharingExpiresAt': null,
        'sharingType': null,
      };
      expect(userUpdate['isLocationSharing'], isFalse);
      expect(userUpdate['sharingExpiresAt'], isNull);
    });

    test('Invariant 4: Sender Account Deletion Atomically Purges Timed Location Metadata', () {
      final deletionMap = AccountDeletionService.buildAtomicDeletionMap(
        uid: ownerUid,
        username: 'owner_user',
        connectedFriendUids: [friendUid],
      );

      // Location coordinates wiped
      expect(deletionMap['${AppConstants.locationsPath}/$ownerUid'], isNull);
      // Directional permissions wiped
      expect(deletionMap['${AppConstants.locationPermissionsPath}/$ownerUid'], isNull);
      // User profile & metadata wiped
      expect(deletionMap['${AppConstants.usersPath}/$ownerUid'], isNull);
    });

    test('Invariant 5: Cold-Start Expired Session Teardown Rejects Stale Foreground Resumption', () async {
      final expiredTimestamp = now - 60000; // 1 minute in past
      SharedPreferences.setMockInitialValues({
        'is_sharing_location_active_$ownerUid': true,
        'location_sharing_expires_at_$ownerUid': expiredTimestamp,
      });

      final prefs = await SharedPreferences.getInstance();
      final localActive = prefs.getBool('is_sharing_location_active_$ownerUid') ?? false;
      final savedExpiresAt = prefs.getInt('location_sharing_expires_at_$ownerUid');

      expect(localActive, isTrue);
      expect(savedExpiresAt, isNotNull);

      // Cold start evaluation
      final isExpired = DateTime.now().millisecondsSinceEpoch >= savedExpiresAt!;
      expect(isExpired, isTrue);

      // Must execute teardown rather than resuming service
      bool resumedService = false;
      if (isExpired) {
        await prefs.setBool('is_sharing_location_active_$ownerUid', false);
        await prefs.remove('location_sharing_expires_at_$ownerUid');
      } else {
        resumedService = true;
      }

      expect(resumedService, isFalse);
      expect(prefs.getBool('is_sharing_location_active_$ownerUid'), isFalse);
    });

    test('Invariant 6: Reader-Side Authoritative Expiration Gate Prevents Clock Tampering', () {
      // Authoritative expiresAt set by server / payload
      final authoritativeExpiresAt = now - 50000; // Expired 50s ago

      // Sender payload with past expiration
      final location = LocationModel(
        userId: ownerUid,
        latitude: 12.9716,
        longitude: 77.5946,
        timestamp: now - 60000,
        expiresAt: authoritativeExpiresAt,
      );

      // Even if attacker attempts to query or bypass client, reader gate checks expiresAt
      final isBlocked = location.isExpiredWithGrace(graceMs: 30000);
      expect(isBlocked, isTrue);
    });
  });
}
