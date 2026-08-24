class GroupSessionParticipantModel {
  final String uid;
  final String displayName;
  final int avatarPresetIndex;
  final bool isSharing;
  final int joinedAt;

  const GroupSessionParticipantModel({
    required this.uid,
    required this.displayName,
    this.avatarPresetIndex = 0,
    this.isSharing = true,
    required this.joinedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName.trim(),
      'avatarPresetIndex': avatarPresetIndex,
      'isSharing': isSharing,
      'joinedAt': joinedAt,
    };
  }

  factory GroupSessionParticipantModel.fromMap(Map<dynamic, dynamic> map, String uid) {
    return GroupSessionParticipantModel(
      uid: uid,
      displayName: map['displayName']?.toString() ?? 'Member',
      avatarPresetIndex: (map['avatarPresetIndex'] as num?)?.toInt() ?? 0,
      isSharing: map['isSharing'] == true,
      joinedAt: (map['joinedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  GroupSessionParticipantModel copyWith({
    String? uid,
    String? displayName,
    int? avatarPresetIndex,
    bool? isSharing,
    int? joinedAt,
  }) {
    return GroupSessionParticipantModel(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      avatarPresetIndex: avatarPresetIndex ?? this.avatarPresetIndex,
      isSharing: isSharing ?? this.isSharing,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}
