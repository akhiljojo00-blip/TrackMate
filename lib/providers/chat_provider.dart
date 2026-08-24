import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class ChatProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final NotificationService _notificationService = NotificationService();

  List<MessageModel> _messages = [];
  bool _isSending = false;
  String? _chatError;
  String? _activeChatId;
  StreamSubscription<List<MessageModel>>? _messagesSub;

  List<MessageModel> get messages => _messages;
  bool get isSending => _isSending;
  String? get chatError => _chatError;
  String? get activeChatId => _activeChatId;

  void openChat({
    required String currentUid,
    required String peerUid,
  }) {
    final chatId = _databaseService.getChatId(currentUid, peerUid);
    if (_activeChatId == chatId) return;

    _activeChatId = chatId;
    _messages = [];
    _chatError = null;
    _messagesSub?.cancel();

    _messagesSub = _databaseService.getMessagesStream(chatId).listen(
      (messages) {
        _messages = messages;
        notifyListeners();
      },
      onError: (e) {
        _chatError = 'Error loading messages: $e';
        debugPrint('Error listening to chat messages: $e');
        notifyListeners();
      },
    );
  }

  void closeChat() {
    _messagesSub?.cancel();
    _messagesSub = null;
    _activeChatId = null;
    _messages = [];
    _chatError = null;
    _isSending = false;
    notifyListeners();
  }

  void handleIncomingMessageNotification({
    required MessageModel message,
    required String chatId,
    required String currentUid,
  }) {
    // Only notify if message is from a peer and user is not inside that active chat
    if (message.senderId != currentUid && _activeChatId != chatId) {
      _notificationService.showChatMessageNotification(
        senderName: message.senderName,
        messageText: message.text,
        chatId: chatId,
      );
    }
  }

  Future<bool> sendTextMessage({
    required String currentUid,
    required String currentName,
    required String text,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty || _activeChatId == null) return false;

    _isSending = true;
    _chatError = null;
    notifyListeners();

    try {
      final message = MessageModel(
        id: '',
        senderId: currentUid,
        senderName: currentName,
        text: trimmedText,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      await _databaseService.sendMessage(
        chatId: _activeChatId!,
        message: message,
      );
      return true;
    } catch (e) {
      _chatError = 'Failed to send message: $e';
      debugPrint('Error sending message: $e');
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    super.dispose();
  }
}
