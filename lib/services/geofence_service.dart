import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/geofence_model.dart';
import '../models/geofence_state_model.dart';
import '../utils/geofence_calculator.dart';
import 'database_service.dart';

class GeofenceTriggerEvent {
  final GeofenceModel geofence;
  final String transitionType; // 'entered' | 'exited'
  final double latitude;
  final double longitude;
  final int timestamp;

  const GeofenceTriggerEvent({
    required this.geofence,
    required this.transitionType,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  @override
  String toString() =>
      'GeofenceTriggerEvent(zone: ${geofence.name}, type: $transitionType, lat: $latitude, lon: $longitude)';
}

class GeofenceService {
  static final GeofenceService _instance = GeofenceService._internal();
  factory GeofenceService() => _instance;

  final DatabaseService _databaseService;
  final Map<String, GeofenceStateModel> _states = {};
  List<GeofenceModel> _cachedGeofences = [];
  StreamSubscription<List<GeofenceModel>>? _geofencesSubscription;
  String? _currentSubscribedUid;

  final StreamController<GeofenceTriggerEvent> _triggerEventController =
      StreamController<GeofenceTriggerEvent>.broadcast();

  Stream<GeofenceTriggerEvent> get onGeofenceTrigger => _triggerEventController.stream;

  GeofenceService._internal({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService();

  @visibleForTesting
  factory GeofenceService.custom({DatabaseService? databaseService}) {
    return GeofenceService._internal(databaseService: databaseService);
  }

  /// Initializes real-time listener for the given user's geofences.
  void initializeForUser(String uid) {
    if (_currentSubscribedUid == uid && _geofencesSubscription != null) {
      return;
    }

    _geofencesSubscription?.cancel();
    _currentSubscribedUid = uid;
    _states.clear();

    _geofencesSubscription = _databaseService.listenToUserGeofences(uid).listen(
      (geofences) {
        _cachedGeofences = geofences;
      },
      onError: (e) {
        debugPrint('GeofenceService stream error: $e');
      },
    );
  }

  @visibleForTesting
  void setGeofencesForTest(List<GeofenceModel> geofences) {
    _cachedGeofences = geofences;
  }

  @visibleForTesting
  void setStateForTest(String geofenceId, GeofenceStateModel state) {
    _states[geofenceId] = state;
  }

  GeofenceStateModel? getState(String geofenceId) => _states[geofenceId];

  /// Evaluates GPS position against all active geofences on-device with hysteresis debouncing.
  Future<List<GeofenceTriggerEvent>> evaluateCurrentPosition({
    required String uid,
    required double latitude,
    required double longitude,
    int? nowMillis,
  }) async {
    final now = nowMillis ?? DateTime.now().millisecondsSinceEpoch;
    final triggeredEvents = <GeofenceTriggerEvent>[];

    final activeGeofences = _cachedGeofences.where((g) => g.isEnabled).toList();

    for (final geofence in activeGeofences) {
      final distance = GeofenceCalculator.calculateDistanceMeters(
        lat1: latitude,
        lon1: longitude,
        lat2: geofence.latitude,
        lon2: geofence.longitude,
      );

      final prevState = _states[geofence.id];
      final wasInside = prevState?.isInside ?? false;
      final isFirstEvaluation = prevState == null;

      bool? newInside;
      String? transitionType;

      // 1. Entry Condition: D <= radius
      if (distance <= geofence.radiusMeters) {
        newInside = true;
        if (!wasInside || isFirstEvaluation) {
          if (geofence.notifyOnEntry) {
            transitionType = 'entered';
          }
        }
      }
      // 2. Exit Condition: D > radius * 1.10 (10% hysteresis buffer)
      else if (distance > (geofence.radiusMeters * 1.10)) {
        newInside = false;
        if (wasInside) {
          if (geofence.notifyOnExit) {
            transitionType = 'exited';
          }
        }
      }
      // 3. Inside Hysteresis Deadband (radius < D <= radius * 1.10)
      else {
        // Retain previous state to prevent boundary jitter
        newInside = wasInside;
      }

      // If state changed or initial evaluation occurred
      if (newInside != wasInside || isFirstEvaluation || transitionType != null) {
        final newState = GeofenceStateModel(
          geofenceId: geofence.id,
          isInside: newInside,
          lastEvaluatedAt: now,
          lastTriggeredState: transitionType ?? prevState?.lastTriggeredState,
          lastTriggeredAt: transitionType != null ? now : prevState?.lastTriggeredAt,
        );

        _states[geofence.id] = newState;

        try {
          await _databaseService.updateGeofenceState(uid, newState);
        } catch (e) {
          debugPrint('Error updating geofence state in RTDB: $e');
        }

        if (transitionType != null) {
          final event = GeofenceTriggerEvent(
            geofence: geofence,
            transitionType: transitionType,
            latitude: latitude,
            longitude: longitude,
            timestamp: now,
          );
          triggeredEvents.add(event);
          _triggerEventController.add(event);
        }
      }
    }

    return triggeredEvents;
  }

  void clear() {
    _geofencesSubscription?.cancel();
    _geofencesSubscription = null;
    _currentSubscribedUid = null;
    _states.clear();
    _cachedGeofences.clear();
  }
}
