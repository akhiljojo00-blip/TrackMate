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
        bio: 'Exploring the world with TrackMate',
        emergencyContact: '+15551234567',
        avatarPresetIndex: 3,
      );

      final map = user.toMap();
      expect(map['uid'], 'user_123');
      expect(map['name'], 'John Doe');
      expect(map['username'], 'johndoe');
      expect(map['email'], 'john@example.com');
      expect(map['isLocationSharing'], false);
      expect(map['createdAt'], now);
      expect(map['bio'], 'Exploring the world with TrackMate');
      expect(map['emergencyContact'], '+15551234567');
      expect(map['avatarPresetIndex'], 3);

      final parsed = UserModel.fromMap(map, 'user_123');
      expect(parsed.uid, user.uid);
      expect(parsed.name, user.name);
      expect(parsed.username, user.username);
      expect(parsed.email, user.email);
      expect(parsed.isLocationSharing, false);
      expect(parsed.createdAt, now);
      expect(parsed.bio, 'Exploring the world with TrackMate');
      expect(parsed.emergencyContact, '+15551234567');
      expect(parsed.avatarPresetIndex, 3);
    });

    test('UserModel copyWith correctly updates customizable fields', () {
      final user = UserModel(
        uid: 'user_456',
        name: 'Jane Doe',
        username: 'janedoe',
        email: 'jane@example.com',
        createdAt: 123456789,
      );

      final updated = user.copyWith(
        name: 'Jane Smith',
        bio: 'Live safely',
        emergencyContact: '+19998887777',
        avatarPresetIndex: 5,
      );

      expect(updated.uid, 'user_456');
      expect(updated.name, 'Jane Smith');
      expect(updated.bio, 'Live safely');
      expect(updated.emergencyContact, '+19998887777');
      expect(updated.avatarPresetIndex, 5);
      expect(updated.username, 'janedoe');
      expect(updated.email, 'jane@example.com');
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
      expect(user.bio, isNull);
      expect(user.emergencyContact, isNull);
      expect(user.avatarPresetIndex, isNull);
    });
  });
}
