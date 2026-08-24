class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final int timestamp;
  final String type;
  final String? imageUrl;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.type = 'text',
    this.imageUrl,
  });

  bool get isImage => type == 'image' && imageUrl != null && imageUrl!.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'text': text.trim(),
      'timestamp': timestamp,
      'type': type,
      'imageUrl': imageUrl,
    };
  }

  factory MessageModel.fromMap(Map<dynamic, dynamic> map, String id) {
    return MessageModel(
      id: id,
      senderId: map['senderId']?.toString() ?? '',
      senderName: map['senderName']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      timestamp: (map['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      type: map['type']?.toString() ?? 'text',
      imageUrl: map['imageUrl']?.toString(),
    );
  }

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? text,
    int? timestamp,
    String? type,
    String? imageUrl,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
