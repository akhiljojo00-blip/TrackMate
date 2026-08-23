import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../services/permission_service.dart';

class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final PermissionService _permissionService = PermissionService();

  Position? _currentPosition;
  bool _hasPermission = false;
  bool _isTracking = false;
  StreamSubscription<Position>? _positionSubscription;

  Position? get currentPosition => _currentPosition;
  bool get hasPermission => _hasPermission;
  bool get isTracking => _isTracking;

  LatLng? get currentLatLng {
    if (_currentPosition == null) return null;
    return LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
  }

  Future<void> checkAndRequestPermission() async {
    _hasPermission = await _permissionService.checkLocationPermission();
    if (!_hasPermission) {
      _hasPermission = await _permissionService.requestLocationPermission();
    }
    notifyListeners();
  }

  Future<void> startTracking() async {
    if (!_hasPermission) {
      await checkAndRequestPermission();
      if (!_hasPermission) return;
    }

    try {
      _currentPosition = await _locationService.getCurrentPosition();
      _isTracking = true;
      notifyListeners();

      _positionSubscription?.cancel();
      _positionSubscription = _locationService.getPositionStream().listen((position) {
        _currentPosition = position;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Error starting location tracking: $e');
    }
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }
}
