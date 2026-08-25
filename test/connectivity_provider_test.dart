import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmate/providers/connectivity_provider.dart';

void main() {
  group('ConnectivityProvider Tests', () {
    test('initial state defaults to connected (true) to prevent flash on startup', () {
      final controller = StreamController<bool>();
      final provider = ConnectivityProvider(testStream: controller.stream);

      expect(provider.isConnected, isTrue);
      expect(provider.isOffline, isFalse);

      provider.dispose();
      controller.close();
    });

    test('state transitions accurately when connection stream emits updates', () async {
      final controller = StreamController<bool>();
      final provider = ConnectivityProvider(testStream: controller.stream);

      int notifyCount = 0;
      provider.addListener(() {
        notifyCount++;
      });

      // 1. Connection lost
      controller.add(false);
      await Future.delayed(Duration.zero);

      expect(provider.isConnected, isFalse);
      expect(provider.isOffline, isTrue);
      expect(notifyCount, 1);

      // 2. Redundant emission does not trigger duplicate notifications
      controller.add(false);
      await Future.delayed(Duration.zero);
      expect(notifyCount, 1);

      // 3. Connection restored
      controller.add(true);
      await Future.delayed(Duration.zero);

      expect(provider.isConnected, isTrue);
      expect(provider.isOffline, isFalse);
      expect(notifyCount, 2);

      provider.dispose();
      await controller.close();
    });

    test('setConnectedForTesting directly updates state and notifies listeners', () {
      final provider = ConnectivityProvider(testStream: const Stream.empty());

      bool notified = false;
      provider.addListener(() {
        notified = true;
      });

      provider.setConnectedForTesting(false);
      expect(provider.isConnected, isFalse);
      expect(provider.isOffline, isTrue);
      expect(notified, isTrue);

      provider.dispose();
    });

    test('isTelemetryStale evaluates 120-second threshold correctly', () {
      final now = 1000000;

      // 30 seconds ago (<120s) -> fresh (not stale)
      final freshTimestamp = now - 30000;
      expect(ConnectivityProvider.isTelemetryStale(freshTimestamp, now: now), isFalse);

      // Exactly 120 seconds ago -> threshold boundary (not stale)
      final boundaryTimestamp = now - 120000;
      expect(ConnectivityProvider.isTelemetryStale(boundaryTimestamp, now: now), isFalse);

      // 121 seconds ago (>120s) -> stale
      final staleTimestamp = now - 121000;
      expect(ConnectivityProvider.isTelemetryStale(staleTimestamp, now: now), isTrue);

      // 10 minutes ago -> stale
      final veryOldTimestamp = now - 600000;
      expect(ConnectivityProvider.isTelemetryStale(veryOldTimestamp, now: now), isTrue);
    });
  });
}
