class ConnectionRequestModel {
  final String senderUid;
  final String senderName;
  final String senderUsername;
  final String receiverUid;
  final int timestamp;
  final String status; // "pending" | "accepted" | "declined"

  const ConnectionRequestModel({
    required this.senderUid,
    required this.senderName,
    required this.senderUsername,
    required this.receiverUid,
    required this.timestamp,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'senderUid': senderUid,
      'senderName': senderName,
      'senderUsername': senderUsername.trim().toLowerCase(),
      'receiverUid': receiverUid,
      'timestamp': timestamp,
      'status': status,
    };
  }

  factory ConnectionRequestModel.fromMap(Map<dynamic, dynamic> map, {String? senderUid, String? receiverUid}) {
    return ConnectionRequestModel(
      senderUid: map['senderUid']?.toString() ?? senderUid ?? '',
      senderName: map['senderName']?.toString() ?? '',
      senderUsername: map['senderUsername']?.toString().toLowerCase().trim() ?? '',
      receiverUid: map['receiverUid']?.toString() ?? receiverUid ?? '',
      timestamp: (map['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      status: map['status']?.toString() ?? 'pending',
    );
  }
}

class ConnectionUser {
  final String uid;
  final String name;
  final String username;
  final int connectedAt;

  const ConnectionUser({
    required this.uid,
    required this.name,
    required this.username,
    required this.connectedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'username': username.trim().toLowerCase(),
      'connectedAt': connectedAt,
    };
  }

  factory ConnectionUser.fromMap(Map<dynamic, dynamic> map, String uid) {
    return ConnectionUser(
      uid: map['uid']?.toString() ?? uid,
      name: map['name']?.toString() ?? '',
      username: map['username']?.toString().toLowerCase().trim() ?? '',
      connectedAt: (map['connectedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}
