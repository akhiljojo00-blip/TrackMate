import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/connection_model.dart';
import '../models/sos_alert_model.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';

class SosProvider extends ChangeNotifier {
  final DatabaseService? _customDatabaseService;
  final LocationService? _customLocationService;
  final NotificationService? _customNotificationService;
  final Battery? _customBattery;

  SosProvider({
    DatabaseService? databaseService,
    LocationService? locationService,
    NotificationService? notificationService,
    Battery? battery,
  })  : _customDatabaseService = databaseService,
        _customLocationService = locationService,
        _customNotificationService = notificationService,
        _customBattery = battery;

  DatabaseService get _databaseService => _customDatabaseService ?? DatabaseService();
  LocationService get _locationService => _customLocationService ?? LocationService();
  NotificationService get _notificationService => _customNotificationService ?? NotificationService();
  Battery get _battery => _customBattery ?? Battery();

  double _holdProgress = 0.0;
  bool _isTriggered = false;
  bool _isLoading = false;
  String? _errorMessage;
  SosAlertModel? _activeAlert;

  // Active incoming alerts from connected friends
  final Map<String, StreamSubscription<SosAlertModel?>> _friendAlertSubs = {};
  final Map<String, SosAlertModel> _activeFriendAlerts = {};
  final Set<String> _dismissedAlertUids = {};

  double get holdProgress => _holdProgress;
  bool get isTriggered => _isTriggered;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  SosAlertModel? get activeAlert => _activeAlert;

  Map<String, SosAlertModel> get activeFriendAlerts => _activeFriendAlerts;

  SosAlertModel? get primaryActiveIncomingAlert {
    final unDismissed = _activeFriendAlerts.values
        .where((a) => !_dismissedAlertUids.contains(a.senderUid))
        .toList();
    return unDismissed.isNotEmpty ? unDismissed.first : null;
  }

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

  void dismissDialogForAlert(String senderUid) {
    _dismissedAlertUids.add(senderUid);
    notifyListeners();
  }

  /// Listens to emergency alert nodes for all connected friends.
  void listenToFriendEmergencyAlerts({
    required String currentUid,
    required List<ConnectionUser> connections,
  }) {
    final currentFriendUids = <String>{};

    for (final friend in connections) {
      final friendUid = friend.uid;
      currentFriendUids.add(friendUid);

      if (!_friendAlertSubs.containsKey(friendUid)) {
        _friendAlertSubs[friendUid] = _databaseService.getEmergencyAlertStream(friendUid).listen(
          (alert) {
            if (alert != null && alert.isActive) {
              final isNewAlert = !_activeFriendAlerts.containsKey(friendUid);
              _activeFriendAlerts[friendUid] = alert;

              if (isNewAlert) {
                // Remove from dismissed if a fresh alert is triggered
                _dismissedAlertUids.remove(friendUid);
                _notificationService.showEmergencySosNotification(
                  senderName: alert.senderName.isNotEmpty ? alert.senderName : friend.name,
                );
              }
              notifyListeners();
            } else {
              if (_activeFriendAlerts.containsKey(friendUid)) {
                _activeFriendAlerts.remove(friendUid);
                _dismissedAlertUids.remove(friendUid);
                notifyListeners();
              }
            }
          },
          onError: (e) {
            debugPrint('Error listening to emergency alert for friend $friendUid: $e');
          },
        );
      }
    }

    // Clean up removed friends
    final toRemove = _friendAlertSubs.keys.where((uid) => !currentFriendUids.contains(uid)).toList();
    for (final uid in toRemove) {
      _friendAlertSubs[uid]?.cancel();
      _friendAlertSubs.remove(uid);
      _activeFriendAlerts.remove(uid);
      _dismissedAlertUids.remove(uid);
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

  void clearAllFriendAlertListeners() {
    for (final sub in _friendAlertSubs.values) {
      sub.cancel();
    }
    _friendAlertSubs.clear();
    _activeFriendAlerts.clear();
    _dismissedAlertUids.clear();
    notifyListeners();
  }

  void reset() {
    _isTriggered = false;
    _holdProgress = 0.0;
    _activeAlert = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    clearAllFriendAlertListeners();
    super.dispose();
  }
}
