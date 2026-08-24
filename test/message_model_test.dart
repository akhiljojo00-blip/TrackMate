import 'package:flutter_test/flutter_test.dart';
import 'package:trackmate/models/message_model.dart';
import 'package:trackmate/services/database_service.dart';

void main() {
  group('MessageModel Tests', () {
    test('MessageModel serializes toMap and deserializes fromMap correctly for text', () {
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
      expect(map['type'], 'text');
      expect(map['imageUrl'], isNull);
      expect(map['latitude'], isNull);
      expect(map['longitude'], isNull);
      expect(map['timestamp'], now);

      final parsed = MessageModel.fromMap(map, 'msg_101');
      expect(parsed.id, 'msg_101');
      expect(parsed.senderId, 'user_1');
      expect(parsed.senderName, 'Alice');
      expect(parsed.text, 'Hello, how are you?');
      expect(parsed.type, 'text');
      expect(parsed.imageUrl, isNull);
      expect(parsed.latitude, isNull);
      expect(parsed.longitude, isNull);
      expect(parsed.isImage, false);
      expect(parsed.isLocation, false);
      expect(parsed.timestamp, now);
    });

    test('MessageModel serializes toMap and deserializes fromMap correctly for images', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final message = MessageModel(
        id: 'msg_102',
        senderId: 'user_1',
        senderName: 'Alice',
        text: 'Look at this photo',
        type: 'image',
        imageUrl: 'https://firebasestorage.googleapis.com/v0/b/bucket/o/photo.jpg',
        timestamp: now,
      );

      final map = message.toMap();
      expect(map['id'], 'msg_102');
      expect(map['type'], 'image');
      expect(map['imageUrl'], 'https://firebasestorage.googleapis.com/v0/b/bucket/o/photo.jpg');
      expect(map['text'], 'Look at this photo');
      expect(map['latitude'], isNull);
      expect(map['longitude'], isNull);

      final parsed = MessageModel.fromMap(map, 'msg_102');
      expect(parsed.id, 'msg_102');
      expect(parsed.type, 'image');
      expect(parsed.imageUrl, 'https://firebasestorage.googleapis.com/v0/b/bucket/o/photo.jpg');
      expect(parsed.isImage, true);
      expect(parsed.isLocation, false);
      expect(parsed.text, 'Look at this photo');
    });

    test('MessageModel serializes toMap and deserializes fromMap correctly for location snapshots', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final message = MessageModel(
        id: 'msg_103',
        senderId: 'user_1',
        senderName: 'Alice',
        text: '📍 Shared Location',
        type: 'location',
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: now,
      );

      final map = message.toMap();
      expect(map['id'], 'msg_103');
      expect(map['type'], 'location');
      expect(map['latitude'], 37.7749);
      expect(map['longitude'], -122.4194);
      expect(map['text'], '📍 Shared Location');
      expect(map['imageUrl'], isNull);

      final parsed = MessageModel.fromMap(map, 'msg_103');
      expect(parsed.id, 'msg_103');
      expect(parsed.type, 'location');
      expect(parsed.latitude, 37.7749);
      expect(parsed.longitude, -122.4194);
      expect(parsed.isLocation, true);
      expect(parsed.isImage, false);
      expect(parsed.text, '📍 Shared Location');
    });

    test('MessageModel backwards compatibility: old messages without type default to text', () {
      final oldMap = {
        'senderId': 'user_2',
        'senderName': 'Bob',
        'text': 'Legacy message format',
        'timestamp': 1700000000000,
      };

      final parsed = MessageModel.fromMap(oldMap, 'legacy_1');
      expect(parsed.id, 'legacy_1');
      expect(parsed.senderId, 'user_2');
      expect(parsed.senderName, 'Bob');
      expect(parsed.text, 'Legacy message format');
      expect(parsed.type, 'text');
      expect(parsed.imageUrl, isNull);
      expect(parsed.latitude, isNull);
      expect(parsed.longitude, isNull);
      expect(parsed.isImage, false);
      expect(parsed.isLocation, false);
    });

    test('MessageModel copyWith works as expected', () {
      final message = MessageModel(
        id: 'msg_1',
        senderId: 'user_1',
        senderName: 'Alice',
        text: 'Original',
        timestamp: 1000,
      );

      final updated = message.copyWith(
        text: 'Updated Text',
        id: 'msg_2',
        type: 'location',
        latitude: 12.9716,
        longitude: 77.5946,
      );
      expect(updated.id, 'msg_2');
      expect(updated.senderId, 'user_1');
      expect(updated.senderName, 'Alice');
      expect(updated.text, 'Updated Text');
      expect(updated.type, 'location');
      expect(updated.latitude, 12.9716);
      expect(updated.longitude, 77.5946);
      expect(updated.isLocation, true);
      expect(updated.isImage, false);
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
