import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/connection_model.dart';
import '../models/location_model.dart';
import '../services/location_service.dart';
import '../services/database_service.dart';
import '../services/geofence_service.dart';

class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final DatabaseService _databaseService = DatabaseService();
  final GeofenceService _geofenceService = GeofenceService();

  Position? _currentPosition;
  LocationModel? _currentLocationModel;
  bool _hasPermission = false;
  bool _isTracking = false;
  bool _isLoading = false;
  String? _locationError;
  DateTime? _lastSyncTime;

  // In-Memory Diagnostics & Telemetry
  int _rawFixCount = 0;
  int _syncDispatchCount = 0;
  DateTime? _trackingStartTime;

  StreamSubscription<Position>? _positionSubscription;

  // Multi-friend location & permission tracking
  final Map<String, LocationModel> _activeFriendLocations = {};
  final Map<String, double> _friendDistances = {};
  final Map<String, bool> _outboundPermissions = {};

  final Map<String, StreamSubscription<bool>> _inboundPermissionSubs = {};
  final Map<String, StreamSubscription<LocationModel?>> _friendLocationSubs = {};
  final Map<String, StreamSubscription<bool>> _outboundPermissionSubs = {};

  String _selectedTravelMode = LocationModel.modeWalking;

  Position? get currentPosition => _currentPosition;
  LocationModel? get currentLocationModel => _currentLocationModel;
  bool get hasPermission => _hasPermission;
  bool get isTracking => _isTracking;
  bool get isLoading => _isLoading;
  String? get locationError => _locationError;
  String get selectedTravelMode => _selectedTravelMode;

  Future<void> setTravelMode(String mode, {String? uid}) async {
    if (!LocationModel.supportedTravelModes.contains(mode)) return;
    _selectedTravelMode = mode;
    if (_currentLocationModel != null) {
      _currentLocationModel = _currentLocationModel!.copyWith(travelMode: mode);
    }
    if (_isTracking && uid != null && _currentLocationModel != null) {
      try {
        await _databaseService.updateUserLocation(uid, _currentLocationModel!);
      } catch (e) {
        debugPrint('Error syncing travel mode to database: $e');
      }
    }
    notifyListeners();
  }

  // Diagnostics Getters
  int get rawFixCount => _rawFixCount;
  int get syncDispatchCount => _syncDispatchCount;
  DateTime? get trackingStartTime => _trackingStartTime;
  Duration? get trackingDuration => _trackingStartTime != null
      ? DateTime.now().difference(_trackingStartTime!)
      : null;
  double get throttlingSavingsPercent => _rawFixCount > 0
      ? ((_rawFixCount - _syncDispatchCount) / _rawFixCount * 100).clamp(0.0, 100.0)
      : 0.0;

  Map<String, LocationModel> get activeFriendLocations => Map.unmodifiable(_activeFriendLocations);
  Map<String, double> get friendDistances => Map.unmodifiable(_friendDistances);
  Map<String, bool> get outboundPermissions => Map.unmodifiable(_outboundPermissions);

  LatLng? get currentLatLng {
    if (_currentPosition == null) return null;
    return LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  static const double maxAccuracyMeters = 15.0;

  static String formatDistance(double meters) {
    if (meters < 0) return '0 m';
    if (meters < 1000) {
      final rounded5 = (meters / 5.0).round() * 5;
      if (rounded5 >= 1000) {
        return '1.0 km';
      }
      return '$rounded5 m';
    } else {
      final km = meters / 1000.0;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  /// Determines whether a new GPS fix should be accepted.
  /// Discards fixes with accuracy > 15m if an accurate fix (<= 15m) is already acquired.
  /// If no fix <= 15m is available yet, accepts the best available reading until an accurate fix is obtained.
  static bool shouldAcceptPosition(
    Position candidate,
    Position? currentBest, {
    double maxAccuracy = maxAccuracyMeters,
  }) {
    if (candidate.accuracy <= maxAccuracy) {
      return true;
    }
    if (currentBest == null || candidate.accuracy < currentBest.accuracy) {
      return true;
    }
    return currentBest.accuracy > maxAccuracy;
  }

  Future<bool> checkAndRequestPermission() async {
    _hasPermission = await _locationService.checkAndRequestPermission();
    notifyListeners();
    return _hasPermission;
  }

  Future<Position?> fetchCurrentPosition() async {
    _setLoading(true);
    _locationError = null;
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        if (shouldAcceptPosition(position, _currentPosition)) {
          _currentPosition = position;
          _hasPermission = true;
          _recalculateAllDistances();
          notifyListeners();
        }
      }
      return position;
    } catch (e) {
      _locationError = 'Failed to fetch current position: $e';
      debugPrint(_locationError);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> requestIgnoreBatteryOptimizations() async {
    return await _locationService.requestIgnoreBatteryOptimizations();
  }

  Future<bool> startTracking(String uid) async {
    _setLoading(true);
    _locationError = null;

    final granted = await checkAndRequestPermission();
    if (!granted) {
      _locationError = 'Location permission is required to share your live location.';
      _setLoading(false);
      return false;
    }

    try {
      _trackingStartTime = DateTime.now();
      _rawFixCount = 0;
      _syncDispatchCount = 0;

      _geofenceService.initializeForUser(uid);
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        _currentPosition = position;
        _currentLocationModel = LocationModel(
          userId: uid,
          latitude: position.latitude,
          longitude: position.longitude,
          heading: position.heading,
          speed: position.speed,
          accuracy: position.accuracy,
          timestamp: position.timestamp.millisecondsSinceEpoch,
          travelMode: _selectedTravelMode,
        );

        // Update database with explicit consent
        _rawFixCount++;
        _syncDispatchCount++;
        await _databaseService.updateLocationSharingConsent(uid, true);
        await _databaseService.updateUserLocation(uid, _currentLocationModel!);
        _lastSyncTime = DateTime.now();
        _recalculateAllDistances();

        unawaited(
          _geofenceService.evaluateCurrentPosition(
            uid: uid,
            latitude: position.latitude,
            longitude: position.longitude,
          ),
        );
      }

      _isTracking = true;
      notifyListeners();

      _positionSubscription?.cancel();
      _positionSubscription = _locationService
          .getPositionStream(
            distanceFilter: 5,
            enableForegroundService: true,
            notificationTitle: 'TrackMate Live Sharing',
            notificationText: 'Sharing your live location with friends',
          )
          .listen(
        (position) async {
          _rawFixCount++;
          if (!shouldAcceptPosition(position, _currentPosition)) {
            // Discard inaccurate jitter fix (accuracy > 15m when better fix exists)
            return;
          }

          _currentPosition = position;
          _currentLocationModel = LocationModel(
            userId: uid,
            latitude: position.latitude,
            longitude: position.longitude,
            heading: position.heading,
            speed: position.speed,
            accuracy: position.accuracy,
            timestamp: position.timestamp.millisecondsSinceEpoch,
            travelMode: _selectedTravelMode,
          );
          _recalculateAllDistances();
          notifyListeners();

          unawaited(
            _geofenceService.evaluateCurrentPosition(
              uid: uid,
              latitude: position.latitude,
              longitude: position.longitude,
            ),
          );

          // Throttled sync to Realtime Database: at least 3 seconds or 5m
          final now = DateTime.now();
          if (_lastSyncTime == null || now.difference(_lastSyncTime!).inSeconds >= 3) {
            _lastSyncTime = now;
            _syncDispatchCount++;
            await _databaseService.updateUserLocation(uid, _currentLocationModel!);
          }
        },
        onError: (e) {
          _locationError = 'GPS stream error: $e';
          debugPrint(_locationError);
          notifyListeners();
        },
      );

      _setLoading(false);
      return true;
    } catch (e) {
      _locationError = 'Error starting location tracking: $e';
      debugPrint(_locationError);
      _setLoading(false);
      return false;
    }
  }

  Future<void> stopTracking(String uid) async {
    _setLoading(true);
    try {
      _positionSubscription?.cancel();
      _positionSubscription = null;
      _isTracking = false;
      _lastSyncTime = null;
      _trackingStartTime = null;

      // Update database to reflect consent revoked and remove active coordinates
      await _databaseService.updateLocationSharingConsent(uid, false);
      await _databaseService.clearUserLocation(uid);
      notifyListeners();
    } catch (e) {
      _locationError = 'Error stopping location tracking: $e';
      debugPrint(_locationError);
    } finally {
      _setLoading(false);
    }
  }

  // Multi-friend streaming with directional permission validation & instant revocation
  void listenToAuthorizedFriends(String currentUid, List<ConnectionUser> connections) {
    final currentFriendUids = connections.map((c) => c.uid).toSet();

    // Clean up removed friends
    final toRemove = _inboundPermissionSubs.keys.where((uid) => !currentFriendUids.contains(uid)).toList();
    for (final uid in toRemove) {
      _inboundPermissionSubs[uid]?.cancel();
      _inboundPermissionSubs.remove(uid);
      _friendLocationSubs[uid]?.cancel();
      _friendLocationSubs.remove(uid);
      _activeFriendLocations.remove(uid);
      _friendDistances.remove(uid);
    }

    for (final friend in connections) {
      final friendUid = friend.uid;

      // Inbound permission: did friend grant permission to currentUid?
      if (!_inboundPermissionSubs.containsKey(friendUid)) {
        _inboundPermissionSubs[friendUid] = _databaseService
            .getLocationPermissionStream(friendUid, currentUid)
            .listen((isPermitted) {
          if (isPermitted) {
            // Subscribe to friend's live coordinates
            if (!_friendLocationSubs.containsKey(friendUid)) {
              _friendLocationSubs[friendUid] = _databaseService
                  .getUserLocationStream(friendUid)
                  .listen((location) {
                if (location != null) {
                  _activeFriendLocations[friendUid] = location;
                  _calculateDistanceForFriend(friendUid, location);
                } else {
                  // Friend stopped sharing
                  _activeFriendLocations.remove(friendUid);
                  _friendDistances.remove(friendUid);
                }
                notifyListeners();
              });
            }
          } else {
            // Instant Revocation: Permission turned off by friend
            _friendLocationSubs[friendUid]?.cancel();
            _friendLocationSubs.remove(friendUid);
            _activeFriendLocations.remove(friendUid);
            _friendDistances.remove(friendUid);
            notifyListeners();
          }
        });
      }

      // Outbound permission: did currentUid grant permission to friendUid?
      if (!_outboundPermissionSubs.containsKey(friendUid)) {
        _outboundPermissionSubs[friendUid] = _databaseService
            .getLocationPermissionStream(currentUid, friendUid)
            .listen((isAllowed) {
          _outboundPermissions[friendUid] = isAllowed;
          notifyListeners();
        });
      }
    }
  }

  void _calculateDistanceForFriend(String friendUid, LocationModel friendLoc) {
    if (_currentPosition != null) {
      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        friendLoc.latitude,
        friendLoc.longitude,
      );
      _friendDistances[friendUid] = distance;
    }
  }

  void _recalculateAllDistances() {
    if (_currentPosition == null) return;
    _activeFriendLocations.forEach((friendUid, location) {
      _calculateDistanceForFriend(friendUid, location);
    });
  }

  Future<bool> toggleFriendLocationPermission({
    required String currentUid,
    required String friendUid,
    required bool isAllowed,
  }) async {
    try {
      _outboundPermissions[friendUid] = isAllowed;
      notifyListeners();

      await _databaseService.setLocationSharingPermission(
        ownerUid: currentUid,
        friendUid: friendUid,
        isAllowed: isAllowed,
      );
      return true;
    } catch (e) {
      debugPrint('Error toggling friend location permission: $e');
      return false;
    }
  }

  void clearAllFriendSubscriptions() {
    for (final sub in _inboundPermissionSubs.values) {
      sub.cancel();
    }
    _inboundPermissionSubs.clear();

    for (final sub in _friendLocationSubs.values) {
      sub.cancel();
    }
    _friendLocationSubs.clear();

    for (final sub in _outboundPermissionSubs.values) {
      sub.cancel();
    }
    _outboundPermissionSubs.clear();

    _activeFriendLocations.clear();
    _friendDistances.clear();
    _outboundPermissions.clear();
    notifyListeners();
  }

  @visibleForTesting
  void setDiagnosticsForTesting({
    int rawFixCount = 0,
    int syncDispatchCount = 0,
    DateTime? trackingStartTime,
  }) {
    _rawFixCount = rawFixCount;
    _syncDispatchCount = syncDispatchCount;
    _trackingStartTime = trackingStartTime;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    clearAllFriendSubscriptions();
    super.dispose();
  }
}
