import 'package:flutter_test/flutter_test.dart';
import 'package:trackmate/models/geofence_model.dart';
import 'package:trackmate/services/geofence_service.dart';

void main() {
  group('GeofenceService Evaluation & Hysteresis Tests', () {
    late GeofenceService service;

    setUp(() {
      service = GeofenceService.custom();
      service.clear();
    });

    tearDown(() {
      service.clear();
    });

    test('Initial entry triggers "entered" event and subsequent inside fixes are debounced', () async {
      final geofence = GeofenceModel(
        id: 'home_zone',
        name: 'Home',
        latitude: 0.0,
        longitude: 0.0,
        radiusMeters: 100.0,
        notifyOnEntry: true,
        notifyOnExit: true,
        createdAt: 1000,
        isEnabled: true,
      );

      service.setGeofencesForTest([geofence]);

      // 1. Initial fix: ~50m away (0.00045 deg lat ~ 50m) -> inside
      final events1 = await service.evaluateCurrentPosition(
        uid: 'user_test',
        latitude: 0.00045,
        longitude: 0.0,
      );

      expect(events1.length, 1);
      expect(events1.first.transitionType, 'entered');
      expect(events1.first.geofence.id, 'home_zone');
      expect(service.getState('home_zone')?.isInside, true);

      // 2. Second fix: still inside (~30m away) -> NO new trigger event (debounced)
      final events2 = await service.evaluateCurrentPosition(
        uid: 'user_test',
        latitude: 0.00027,
        longitude: 0.0,
      );

      expect(events2.isEmpty, true);
      expect(service.getState('home_zone')?.isInside, true);
    });

    test('10% exit buffer hysteresis prevents flickering in the deadband', () async {
      final geofence = GeofenceModel(
        id: 'campus_zone',
        name: 'Campus',
        latitude: 0.0,
        longitude: 0.0,
        radiusMeters: 100.0,
        notifyOnEntry: true,
        notifyOnExit: true,
        createdAt: 1000,
        isEnabled: true,
      );

      service.setGeofencesForTest([geofence]);

      // 1. Start inside
      await service.evaluateCurrentPosition(
        uid: 'user_test',
        latitude: 0.0,
        longitude: 0.0,
      );
      expect(service.getState('campus_zone')?.isInside, true);

      // 2. Move to ~105m away (0.000944 deg lat ~ 105m)
      // Radius is 100m, but 10% exit buffer is 110m.
      // 105m is in the hysteresis deadband -> should NOT trigger 'exited'
      final eventsDeadband = await service.evaluateCurrentPosition(
        uid: 'user_test',
        latitude: 0.000944,
        longitude: 0.0,
      );

      expect(eventsDeadband.isEmpty, true);
      expect(service.getState('campus_zone')?.isInside, true);

      // 3. Move beyond 110m exit threshold (~120m away, 0.00108 deg lat)
      final eventsExited = await service.evaluateCurrentPosition(
        uid: 'user_test',
        latitude: 0.00108,
        longitude: 0.0,
      );

      expect(eventsExited.length, 1);
      expect(eventsExited.first.transitionType, 'exited');
      expect(service.getState('campus_zone')?.isInside, false);

      // 4. Move further away (~200m away) -> already exited, no new event
      final eventsFurther = await service.evaluateCurrentPosition(
        uid: 'user_test',
        latitude: 0.0018,
        longitude: 0.0,
      );

      expect(eventsFurther.isEmpty, true);
      expect(service.getState('campus_zone')?.isInside, false);
    });

    test('Disabled geofences are ignored during evaluation', () async {
      final disabledGeofence = GeofenceModel(
        id: 'gym_zone',
        name: 'Gym',
        latitude: 0.0,
        longitude: 0.0,
        radiusMeters: 100.0,
        isEnabled: false,
        createdAt: 1000,
      );

      service.setGeofencesForTest([disabledGeofence]);

      final events = await service.evaluateCurrentPosition(
        uid: 'user_test',
        latitude: 0.0,
        longitude: 0.0,
      );

      expect(events.isEmpty, true);
      expect(service.getState('gym_zone'), isNull);
    });

    test('Selective notification flags respect notifyOnEntry and notifyOnExit', () async {
      final exitOnlyGeofence = GeofenceModel(
        id: 'office_zone',
        name: 'Office',
        latitude: 0.0,
        longitude: 0.0,
        radiusMeters: 100.0,
        notifyOnEntry: false,
        notifyOnExit: true,
        createdAt: 1000,
        isEnabled: true,
      );

      service.setGeofencesForTest([exitOnlyGeofence]);

      // Entering zone: updates state isInside = true, but produces NO event because notifyOnEntry is false
      final entryEvents = await service.evaluateCurrentPosition(
        uid: 'user_test',
        latitude: 0.0,
        longitude: 0.0,
      );

      expect(entryEvents.isEmpty, true);
      expect(service.getState('office_zone')?.isInside, true);

      // Exiting zone beyond buffer: produces exit event
      final exitEvents = await service.evaluateCurrentPosition(
        uid: 'user_test',
        latitude: 0.0015,
        longitude: 0.0,
      );

      expect(exitEvents.length, 1);
      expect(exitEvents.first.transitionType, 'exited');
      expect(service.getState('office_zone')?.isInside, false);
    });
  });
}
