import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/database_service.dart';

class ConnectivityProvider extends ChangeNotifier {
  final DatabaseService _databaseService;
  StreamSubscription<bool>? _connectionSubscription;
  bool _isConnected = true;

  ConnectivityProvider({
    DatabaseService? databaseService,
    Stream<bool>? testStream,
  }) : _databaseService = databaseService ?? DatabaseService() {
    _initConnectionListener(testStream);
  }

  void _initConnectionListener(Stream<bool>? testStream) {
    try {
      final stream = testStream ?? _databaseService.listenToConnectionState();
      _connectionSubscription = stream.listen(
        (connected) {
          if (_isConnected != connected) {
            _isConnected = connected;
            notifyListeners();
          }
        },
        onError: (e) {
          debugPrint('ConnectivityProvider listener notice: $e');
        },
      );
    } catch (e) {
      debugPrint('Error initializing connection listener: $e');
    }
  }

  bool get isConnected => _isConnected;
  bool get isOffline => !_isConnected;

  /// Helper to evaluate whether a telemetry timestamp (milliseconds since epoch) is stale.
  /// Defaults to 120 seconds (120,000 ms).
  static bool isTelemetryStale(int timestamp, {int? now, int thresholdMs = 120000}) {
    final current = now ?? DateTime.now().millisecondsSinceEpoch;
    return (current - timestamp) > thresholdMs;
  }

  @visibleForTesting
  void setConnectedForTesting(bool connected) {
    _isConnected = connected;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    super.dispose();
  }
}
