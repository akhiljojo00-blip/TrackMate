import 'package:flutter_test/flutter_test.dart';
import 'package:trackmate/providers/location_provider.dart';

void main() {
  group('Diagnostics & Throttling Savings Tests', () {
    test('throttlingSavingsPercent returns 0.0 when rawFixCount is zero', () {
      final provider = LocationProvider();
      provider.setDiagnosticsForTesting(rawFixCount: 0, syncDispatchCount: 0);

      expect(provider.throttlingSavingsPercent, 0.0);
      expect(provider.rawFixCount, 0);
      expect(provider.syncDispatchCount, 0);

      provider.dispose();
    });

    test('throttlingSavingsPercent calculates correct percentage with throttled writes', () {
      final provider = LocationProvider();

      // 100 raw fixes captured, 20 writes dispatched -> 80% network transmissions saved
      provider.setDiagnosticsForTesting(rawFixCount: 100, syncDispatchCount: 20);
      expect(provider.throttlingSavingsPercent, 80.0);

      // 50 raw fixes, 10 writes dispatched -> 80% savings
      provider.setDiagnosticsForTesting(rawFixCount: 50, syncDispatchCount: 10);
      expect(provider.throttlingSavingsPercent, 80.0);

      // 200 raw fixes, 50 writes dispatched -> 75% savings
      provider.setDiagnosticsForTesting(rawFixCount: 200, syncDispatchCount: 50);
      expect(provider.throttlingSavingsPercent, 75.0);

      // 10 raw fixes, 10 writes dispatched (no savings) -> 0% savings
      provider.setDiagnosticsForTesting(rawFixCount: 10, syncDispatchCount: 10);
      expect(provider.throttlingSavingsPercent, 0.0);

      provider.dispose();
    });

    test('throttlingSavingsPercent clamps values safely to 0.0 - 100.0', () {
      final provider = LocationProvider();

      // Edge case where sync writes exceed raw fixes (e.g., initial upload before stream)
      provider.setDiagnosticsForTesting(rawFixCount: 5, syncDispatchCount: 10);
      expect(provider.throttlingSavingsPercent, 0.0);

      provider.dispose();
    });

    test('trackingDuration returns null when not tracking and Duration when active', () {
      final provider = LocationProvider();

      expect(provider.trackingDuration, isNull);

      final startTime = DateTime.now().subtract(const Duration(seconds: 45));
      provider.setDiagnosticsForTesting(trackingStartTime: startTime);

      expect(provider.trackingDuration, isNotNull);
      expect(provider.trackingDuration!.inSeconds >= 45, isTrue);

      provider.dispose();
    });
  });
}
