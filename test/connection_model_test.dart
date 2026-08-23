import 'package:flutter_test/flutter_test.dart';
import 'package:trackmate/models/connection_model.dart';

void main() {
  group('ConnectionModel Tests', () {
    test('ConnectionRequestModel serializes and deserializes correctly', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final request = ConnectionRequestModel(
        senderUid: 'user_1',
        senderName: 'Alice',
        senderUsername: 'alice',
        receiverUid: 'user_2',
        timestamp: now,
        status: 'pending',
      );

      final map = request.toMap();
      expect(map['senderUid'], 'user_1');
      expect(map['senderName'], 'Alice');
      expect(map['senderUsername'], 'alice');
      expect(map['receiverUid'], 'user_2');
      expect(map['timestamp'], now);
      expect(map['status'], 'pending');

      final parsed = ConnectionRequestModel.fromMap(map, senderUid: 'user_1', receiverUid: 'user_2');
      expect(parsed.senderUid, 'user_1');
      expect(parsed.senderName, 'Alice');
      expect(parsed.senderUsername, 'alice');
      expect(parsed.receiverUid, 'user_2');
      expect(parsed.status, 'pending');
    });

    test('ConnectionUser serializes and deserializes correctly', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final connection = ConnectionUser(
        uid: 'user_2',
        name: 'Bob',
        username: 'bob',
        connectedAt: now,
      );

      final map = connection.toMap();
      expect(map['uid'], 'user_2');
      expect(map['name'], 'Bob');
      expect(map['username'], 'bob');
      expect(map['connectedAt'], now);

      final parsed = ConnectionUser.fromMap(map, 'user_2');
      expect(parsed.uid, 'user_2');
      expect(parsed.name, 'Bob');
      expect(parsed.username, 'bob');
      expect(parsed.connectedAt, now);
    });
  });
}
