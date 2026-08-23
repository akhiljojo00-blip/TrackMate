import 'package:flutter_test/flutter_test.dart';
import 'package:trackmate/models/user_model.dart';

void main() {
  group('UserModel Tests', () {
    test('UserModel serializes toMap and deserializes fromMap correctly', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final user = UserModel(
        uid: 'user_123',
        name: 'John Doe',
        username: 'johndoe',
        email: 'john@example.com',
        isLocationSharing: false,
        createdAt: now,
      );

      final map = user.toMap();
      expect(map['uid'], 'user_123');
      expect(map['name'], 'John Doe');
      expect(map['username'], 'johndoe');
      expect(map['email'], 'john@example.com');
      expect(map['isLocationSharing'], false);
      expect(map['createdAt'], now);

      final parsed = UserModel.fromMap(map, 'user_123');
      expect(parsed.uid, user.uid);
      expect(parsed.name, user.name);
      expect(parsed.username, user.username);
      expect(parsed.email, user.email);
      expect(parsed.isLocationSharing, false);
      expect(parsed.createdAt, now);
    });

    test('UserModel default isLocationSharing is false', () {
      final user = UserModel(
        uid: 'user_456',
        name: 'Jane Doe',
        username: 'janedoe',
        email: 'jane@example.com',
        createdAt: 123456789,
      );

      expect(user.isLocationSharing, false);
    });
  });
}
