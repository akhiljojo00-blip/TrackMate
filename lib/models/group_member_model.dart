class GroupMemberModel {
  final String uid;
  final String role; // 'owner' | 'admin' | 'member'
  final int joinedAt;
  final String? name;
  final String? username;

  const GroupMemberModel({
    required this.uid,
    required this.role,
    required this.joinedAt,
    this.name,
    this.username,
  });

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin' || role == 'owner';
  bool get isMember => role == 'member';

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'role': role,
      'joinedAt': joinedAt,
      if (name != null) 'name': name,
      if (username != null) 'username': username,
    };
  }

  factory GroupMemberModel.fromMap(Map<dynamic, dynamic> map, String uid) {
    return GroupMemberModel(
      uid: uid,
      role: map['role']?.toString() ?? 'member',
      joinedAt: (map['joinedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      name: map['name']?.toString(),
      username: map['username']?.toString(),
    );
  }

  GroupMemberModel copyWith({
    String? uid,
    String? role,
    int? joinedAt,
    String? name,
    String? username,
  }) {
    return GroupMemberModel(
      uid: uid ?? this.uid,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      name: name ?? this.name,
      username: username ?? this.username,
    );
  }
}
