import 'package:flutter_test/flutter_test.dart';
import 'package:trackmate/constants/app_constants.dart';
import 'package:trackmate/models/connection_model.dart';
import 'package:trackmate/models/user_model.dart';
import 'package:trackmate/providers/connection_provider.dart';

void main() {
  group('Connection Request Flow & Payload Tests', () {
    test('Connection request creates symmetric RTDB paths and valid payload', () {
      final sender = UserModel(
        uid: 'user_alice_123',
        name: 'Alice Smith',
        username: 'alice',
        email: 'alice@example.com',
        isLocationSharing: false,
        createdAt: 1700000000000,
      );
      const targetUid = 'user_bob_456';

      final request = ConnectionRequestModel(
        senderUid: sender.uid,
        senderName: sender.name,
        senderUsername: sender.username,
        receiverUid: targetUid,
        timestamp: 1700000000000,
        status: 'pending',
      );

      final incomingPath = '${AppConstants.connectionRequestsPath}/$targetUid/${sender.uid}';
      final sentPath = '${AppConstants.sentRequestsPath}/${sender.uid}/$targetUid';

      expect(incomingPath, 'connection_requests/user_bob_456/user_alice_123');
      expect(sentPath, 'sent_requests/user_alice_123/user_bob_456');

      final payload = request.toMap();
      expect(payload['senderUid'], 'user_alice_123');
      expect(payload['receiverUid'], 'user_bob_456');
      expect(payload['senderName'], 'Alice Smith');
      expect(payload['senderUsername'], 'alice');
      expect(payload['status'], 'pending');
    });

    test('ConnectionProvider guards against sending request to self', () async {
      final provider = ConnectionProvider();
      final user = UserModel(
        uid: 'user_self',
        name: 'Self',
        username: 'myself',
        email: 'self@example.com',
        isLocationSharing: false,
        createdAt: 1700000000000,
      );

      final result = await provider.sendRequest(sender: user, targetUid: 'user_self');
      expect(result, isFalse);
      expect(provider.actionError, contains('yourself'));
    });

    test('ConnectionProvider guards against empty sender or target UID', () async {
      final provider = ConnectionProvider();
      final user = UserModel(
        uid: '',
        name: 'Empty',
        username: 'empty',
        email: '',
        isLocationSharing: false,
        createdAt: 1700000000000,
      );

      final result = await provider.sendRequest(sender: user, targetUid: 'valid_uid');
      expect(result, isFalse);
      expect(provider.actionError, contains('Invalid sender or target'));

      final validUser = UserModel(
        uid: 'valid_sender',
        name: 'Valid',
        username: 'valid',
        email: '',
        isLocationSharing: false,
        createdAt: 1700000000000,
      );

      final result2 = await provider.sendRequest(sender: validUser, targetUid: '   ');
      expect(result2, isFalse);
      expect(provider.actionError, contains('Invalid sender or target'));
    });

    test('ConnectionProvider isConnectedWith and isRequestPending checks', () {
      final provider = ConnectionProvider();
      expect(provider.isConnectedWith('target_1'), isFalse);
      expect(provider.isRequestPending('target_1'), isFalse);
    });
  });
}
