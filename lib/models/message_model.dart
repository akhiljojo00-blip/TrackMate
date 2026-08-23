class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final int timestamp;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'text': text.trim(),
      'timestamp': timestamp,
    };
  }

  factory MessageModel.fromMap(Map<dynamic, dynamic> map, String id) {
    return MessageModel(
      id: id,
      senderId: map['senderId']?.toString() ?? '',
      senderName: map['senderName']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      timestamp: (map['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? text,
    int? timestamp,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
