import 'package:flutter_test/flutter_test.dart';
import 'package:trackmate/models/message_model.dart';
import 'package:trackmate/services/database_service.dart';

void main() {
  group('MessageModel Tests', () {
    test('MessageModel serializes toMap and deserializes fromMap correctly', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final message = MessageModel(
        id: 'msg_101',
        senderId: 'user_1',
        senderName: 'Alice',
        text: 'Hello, how are you?',
        timestamp: now,
      );

      final map = message.toMap();
      expect(map['id'], 'msg_101');
      expect(map['senderId'], 'user_1');
      expect(map['senderName'], 'Alice');
      expect(map['text'], 'Hello, how are you?');
      expect(map['timestamp'], now);

      final parsed = MessageModel.fromMap(map, 'msg_101');
      expect(parsed.id, 'msg_101');
      expect(parsed.senderId, 'user_1');
      expect(parsed.senderName, 'Alice');
      expect(parsed.text, 'Hello, how are you?');
      expect(parsed.timestamp, now);
    });

    test('MessageModel copyWith works as expected', () {
      final message = MessageModel(
        id: 'msg_1',
        senderId: 'user_1',
        senderName: 'Alice',
        text: 'Original',
        timestamp: 1000,
      );

      final updated = message.copyWith(text: 'Updated Text', id: 'msg_2');
      expect(updated.id, 'msg_2');
      expect(updated.senderId, 'user_1');
      expect(updated.senderName, 'Alice');
      expect(updated.text, 'Updated Text');
      expect(updated.timestamp, 1000);
    });
  });

  group('DatabaseService getChatId Tests', () {
    final dbService = DatabaseService();

    test('getChatId returns deterministically sorted room id', () {
      final id1 = dbService.getChatId('user_alpha', 'user_beta');
      final id2 = dbService.getChatId('user_beta', 'user_alpha');

      expect(id1, 'user_alpha_user_beta');
      expect(id2, 'user_alpha_user_beta');
      expect(id1, equals(id2));
    });

    test('getChatId handles arbitrary string UIDs deterministically', () {
      final id1 = dbService.getChatId('Z99', 'A01');
      expect(id1, 'A01_Z99');
    });
  });
}
