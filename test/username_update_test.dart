import 'package:flutter_test/flutter_test.dart';
import 'package:trackmate/models/user_model.dart';

void main() {
  group('Username Validation & Model Tests', () {
    test('Username sanitization and format rules', () {
      final validRegex = RegExp(r'^[a-z0-9_]{3,30}$');

      // Valid handles
      expect(validRegex.hasMatch('alex_99'), isTrue);
      expect(validRegex.hasMatch('john_doe'), isTrue);
      expect(validRegex.hasMatch('user123'), isTrue);
      expect(validRegex.hasMatch('a_b_c'), isTrue);

      // Invalid handles
      expect(validRegex.hasMatch('al'), isFalse); // < 3 chars
      expect(validRegex.hasMatch('alex.doe'), isFalse); // dot not allowed
      expect(validRegex.hasMatch('alex-doe'), isFalse); // hyphen not allowed
      expect(validRegex.hasMatch('alex doe'), isFalse); // space not allowed
      expect(validRegex.hasMatch('alex@doe'), isFalse); // @ not allowed
      expect(validRegex.hasMatch('A' * 31), isFalse); // > 30 chars
    });

    test('UserModel copyWith updates username cleanly', () {
      final user = UserModel(
        uid: 'user_123',
        name: 'Alex Hunter',
        username: 'alex_old',
        email: 'alex@example.com',
        isLocationSharing: false,
        createdAt: 1700000000000,
      );

      final updated = user.copyWith(username: 'alex_new');
      expect(updated.username, 'alex_new');
      expect(updated.name, 'Alex Hunter');
      expect(updated.uid, 'user_123');
      expect(updated.email, 'alex@example.com');
    });

    test('UserModel toMap serializes updated username', () {
      final user = UserModel(
        uid: 'user_123',
        name: 'Alex Hunter',
        username: 'alex_v2',
        email: 'alex@example.com',
        isLocationSharing: false,
        createdAt: 1700000000000,
      );

      final map = user.toMap();
      expect(map['username'], 'alex_v2');
      expect(map['name'], 'Alex Hunter');
    });
  });
}
