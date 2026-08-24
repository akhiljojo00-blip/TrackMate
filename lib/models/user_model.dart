class UserModel {
  final String uid;
  final String name;
  final String username;
  final String email;
  final bool isLocationSharing;
  final int createdAt;
  final String? bio;
  final String? emergencyContact;
  final int? avatarPresetIndex;

  const UserModel({
    required this.uid,
    required this.name,
    required this.username,
    required this.email,
    this.isLocationSharing = false,
    required this.createdAt,
    this.bio,
    this.emergencyContact,
    this.avatarPresetIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'username': username.trim().toLowerCase(),
      'email': email.trim(),
      'isLocationSharing': isLocationSharing,
      'createdAt': createdAt,
      'bio': bio,
      'emergencyContact': emergencyContact,
      'avatarPresetIndex': avatarPresetIndex,
    };
  }

  factory UserModel.fromMap(Map<dynamic, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      name: map['name']?.toString() ?? '',
      username: map['username']?.toString().toLowerCase().trim() ?? '',
      email: map['email']?.toString().trim() ?? '',
      isLocationSharing: map['isLocationSharing'] as bool? ?? false,
      createdAt: (map['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      bio: map['bio']?.toString(),
      emergencyContact: map['emergencyContact']?.toString(),
      avatarPresetIndex: (map['avatarPresetIndex'] as num?)?.toInt(),
    );
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? username,
    String? email,
    bool? isLocationSharing,
    int? createdAt,
    String? bio,
    String? emergencyContact,
    int? avatarPresetIndex,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      isLocationSharing: isLocationSharing ?? this.isLocationSharing,
      createdAt: createdAt ?? this.createdAt,
      bio: bio ?? this.bio,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      avatarPresetIndex: avatarPresetIndex ?? this.avatarPresetIndex,
    );
  }
}
