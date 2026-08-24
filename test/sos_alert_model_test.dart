import 'package:flutter_test/flutter_test.dart';
import 'package:trackmate/models/sos_alert_model.dart';
import 'package:trackmate/providers/sos_provider.dart';

void main() {
  group('SosAlertModel Tests', () {
    test('SosAlertModel serializes toMap and deserializes fromMap correctly', () {
      final model = SosAlertModel(
        id: 'alert_123',
        senderUid: 'user_abc',
        senderName: 'Alice',
        latitude: 12.9716,
        longitude: 77.5946,
        batteryLevel: 85,
        timestamp: 1672531200000,
        isActive: true,
      );

      final map = model.toMap();
      expect(map['senderUid'], 'user_abc');
      expect(map['senderName'], 'Alice');
      expect(map['latitude'], 12.9716);
      expect(map['longitude'], 77.5946);
      expect(map['batteryLevel'], 85);
      expect(map['timestamp'], 1672531200000);
      expect(map['isActive'], true);

      final parsed = SosAlertModel.fromMap(map, 'alert_123');
      expect(parsed.id, 'alert_123');
      expect(parsed.senderUid, 'user_abc');
      expect(parsed.senderName, 'Alice');
      expect(parsed.latitude, 12.9716);
      expect(parsed.longitude, 77.5946);
      expect(parsed.batteryLevel, 85);
      expect(parsed.timestamp, 1672531200000);
      expect(parsed.isActive, true);
    });

    test('SosAlertModel copyWith updates fields properly', () {
      final model = SosAlertModel(
        id: 'alert_123',
        senderUid: 'user_abc',
        senderName: 'Alice',
        latitude: 12.9716,
        longitude: 77.5946,
        timestamp: 1672531200000,
      );

      final updated = model.copyWith(
        isActive: false,
        batteryLevel: 42,
      );

      expect(updated.id, 'alert_123');
      expect(updated.isActive, false);
      expect(updated.batteryLevel, 42);
      expect(updated.senderName, 'Alice');
    });
  });

  group('SosProvider Tests', () {
    test('SosProvider initial state is idle and zero progress', () {
      final provider = SosProvider();
      expect(provider.holdProgress, 0.0);
      expect(provider.isTriggered, false);
      expect(provider.isLoading, false);
      expect(provider.activeAlert, isNull);
    });

    test('SosProvider updateHoldProgress clamps values correctly', () {
      final provider = SosProvider();
      provider.updateHoldProgress(0.5);
      expect(provider.holdProgress, 0.5);

      provider.updateHoldProgress(1.5);
      expect(provider.holdProgress, 1.0);

      provider.updateHoldProgress(-0.2);
      expect(provider.holdProgress, 0.0);
    });

    test('SosProvider reset lifecycle', () {
      final provider = SosProvider();
      provider.updateHoldProgress(0.7);
      expect(provider.holdProgress, 0.7);

      provider.cancelHold();
      expect(provider.holdProgress, 0.0);

      provider.reset();
      expect(provider.isTriggered, false);
      expect(provider.holdProgress, 0.0);
      expect(provider.activeAlert, isNull);
    });
  });
}
