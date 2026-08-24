import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/sos_alert_model.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';

class SosProvider extends ChangeNotifier {
  final DatabaseService _databaseService;
  final LocationService _locationService;
  final Battery _battery;

  SosProvider({
    DatabaseService? databaseService,
    LocationService? locationService,
    Battery? battery,
  })  : _databaseService = databaseService ?? DatabaseService(),
        _locationService = locationService ?? LocationService(),
        _battery = battery ?? Battery();

  double _holdProgress = 0.0;
  bool _isTriggered = false;
  bool _isLoading = false;
  String? _errorMessage;
  SosAlertModel? _activeAlert;

  double get holdProgress => _holdProgress;
  bool get isTriggered => _isTriggered;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  SosAlertModel? get activeAlert => _activeAlert;

  void updateHoldProgress(double progress) {
    _holdProgress = progress.clamp(0.0, 1.0);
    notifyListeners();
  }

  void triggerSos() {
    _isTriggered = true;
    _holdProgress = 1.0;
    notifyListeners();
  }

  void cancelHold() {
    if (!_isTriggered) {
      _holdProgress = 0.0;
      notifyListeners();
    }
  }

  /// Packages real-time telemetry (GPS coordinates + battery percentage)
  /// and broadcasts the emergency beacon to Realtime Database.
  Future<bool> broadcastSos({
    required String currentUid,
    required String currentName,
    double? currentLat,
    double? currentLng,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _isTriggered = true;
    _holdProgress = 1.0;
    notifyListeners();

    try {
      double lat = currentLat ?? 0.0;
      double lng = currentLng ?? 0.0;

      // If coordinates are missing, fetch fresh position
      if (lat == 0.0 && lng == 0.0) {
        final position = await _locationService.getCurrentPosition();
        if (position != null) {
          lat = position.latitude;
          lng = position.longitude;
        }
      }

      // Query battery percentage safely
      int? batteryPercentage;
      try {
        batteryPercentage = await _battery.batteryLevel;
      } catch (e) {
        debugPrint('Notice: unable to query battery level: $e');
      }

      final alert = SosAlertModel(
        id: currentUid,
        senderUid: currentUid,
        senderName: currentName,
        latitude: lat,
        longitude: lng,
        batteryLevel: batteryPercentage,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        isActive: true,
      );

      await _databaseService.sendSosAlert(alert);
      _activeAlert = alert;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to broadcast SOS alert: $e';
      debugPrint('Error broadcasting SOS: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Cancels and removes the active emergency beacon from the database.
  Future<bool> cancelSos(String currentUid) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _databaseService.cancelSosAlert(currentUid);
      _isTriggered = false;
      _activeAlert = null;
      _holdProgress = 0.0;
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Failed to cancel SOS alert: $e';
      debugPrint('Error cancelling SOS: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    _isTriggered = false;
    _holdProgress = 0.0;
    _activeAlert = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}
