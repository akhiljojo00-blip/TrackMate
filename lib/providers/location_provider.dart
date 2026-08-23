import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/connection_model.dart';
import '../models/location_model.dart';
import '../services/location_service.dart';
import '../services/database_service.dart';

class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final DatabaseService _databaseService = DatabaseService();

  Position? _currentPosition;
  LocationModel? _currentLocationModel;
  bool _hasPermission = false;
  bool _isTracking = false;
  bool _isLoading = false;
  String? _locationError;
  DateTime? _lastSyncTime;

  StreamSubscription<Position>? _positionSubscription;

  // Multi-friend location & permission tracking
  final Map<String, LocationModel> _activeFriendLocations = {};
  final Map<String, double> _friendDistances = {};
  final Map<String, bool> _outboundPermissions = {};

  final Map<String, StreamSubscription<bool>> _inboundPermissionSubs = {};
  final Map<String, StreamSubscription<LocationModel?>> _friendLocationSubs = {};
  final Map<String, StreamSubscription<bool>> _outboundPermissionSubs = {};

  Position? get currentPosition => _currentPosition;
  LocationModel? get currentLocationModel => _currentLocationModel;
  bool get hasPermission => _hasPermission;
  bool get isTracking => _isTracking;
  bool get isLoading => _isLoading;
  String? get locationError => _locationError;

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

  static String formatDistance(double meters) {
    if (meters < 0) return '0 m';
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      final km = meters / 1000.0;
      if (km < 10) {
        return '${km.toStringAsFixed(1)} km';
      } else {
        return '${km.toStringAsFixed(0)} km';
      }
    }
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
        _currentPosition = position;
        _hasPermission = true;
        _recalculateAllDistances();
        notifyListeners();
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
        );

        // Update database with explicit consent
        await _databaseService.updateLocationSharingConsent(uid, true);
        await _databaseService.updateUserLocation(uid, _currentLocationModel!);
        _lastSyncTime = DateTime.now();
        _recalculateAllDistances();
      }

      _isTracking = true;
      notifyListeners();

      _positionSubscription?.cancel();
      _positionSubscription = _locationService.getPositionStream(distanceFilter: 5).listen(
        (position) async {
          _currentPosition = position;
          _currentLocationModel = LocationModel(
            userId: uid,
            latitude: position.latitude,
            longitude: position.longitude,
            heading: position.heading,
            speed: position.speed,
            accuracy: position.accuracy,
            timestamp: position.timestamp.millisecondsSinceEpoch,
          );
          _recalculateAllDistances();
          notifyListeners();

          // Throttled sync to Realtime Database: at least 3 seconds or 5m
          final now = DateTime.now();
          if (_lastSyncTime == null || now.difference(_lastSyncTime!).inSeconds >= 3) {
            _lastSyncTime = now;
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

  @override
  void dispose() {
    _positionSubscription?.cancel();
    clearAllFriendSubscriptions();
    super.dispose();
  }
}
