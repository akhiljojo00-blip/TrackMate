import 'package:flutter/foundation.dart';
import '../models/sos_alert_model.dart';

class SosProvider extends ChangeNotifier {
  double _holdProgress = 0.0;
  bool _isTriggered = false;
  SosAlertModel? _activeAlert;

  double get holdProgress => _holdProgress;
  bool get isTriggered => _isTriggered;
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

  void reset() {
    _isTriggered = false;
    _holdProgress = 0.0;
    _activeAlert = null;
    notifyListeners();
  }
}
