class GroupModel {
  final String id;
  final String name;
  final String? description;
  final int avatarPresetIndex;
  final String ownerId;
  final int createdAt;
  final int updatedAt;
  final int memberCount;
  final String? lastMessageText;
  final int? lastMessageTimestamp;
  final String? lastMessageSenderId;
  final String? lastMessageSenderName;

  const GroupModel({
    required this.id,
    required this.name,
    this.description,
    this.avatarPresetIndex = 0,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
    this.memberCount = 1,
    this.lastMessageText,
    this.lastMessageTimestamp,
    this.lastMessageSenderId,
    this.lastMessageSenderName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name.trim(),
      'description': description?.trim(),
      'avatarPresetIndex': avatarPresetIndex,
      'ownerId': ownerId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'memberCount': memberCount,
      'lastMessageText': lastMessageText?.trim(),
      'lastMessageTimestamp': lastMessageTimestamp,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageSenderName': lastMessageSenderName,
    };
  }

  factory GroupModel.fromMap(Map<dynamic, dynamic> map, String id) {
    return GroupModel(
      id: id,
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString(),
      avatarPresetIndex: (map['avatarPresetIndex'] as num?)?.toInt() ?? 0,
      ownerId: map['ownerId']?.toString() ?? '',
      createdAt: (map['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: (map['updatedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      memberCount: (map['memberCount'] as num?)?.toInt() ?? 1,
      lastMessageText: map['lastMessageText']?.toString(),
      lastMessageTimestamp: (map['lastMessageTimestamp'] as num?)?.toInt(),
      lastMessageSenderId: map['lastMessageSenderId']?.toString(),
      lastMessageSenderName: map['lastMessageSenderName']?.toString(),
    );
  }

  GroupModel copyWith({
    String? id,
    String? name,
    String? description,
    int? avatarPresetIndex,
    String? ownerId,
    int? createdAt,
    int? updatedAt,
    int? memberCount,
    String? lastMessageText,
    int? lastMessageTimestamp,
    String? lastMessageSenderId,
    String? lastMessageSenderName,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      avatarPresetIndex: avatarPresetIndex ?? this.avatarPresetIndex,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      memberCount: memberCount ?? this.memberCount,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageSenderName: lastMessageSenderName ?? this.lastMessageSenderName,
    );
  }
}
