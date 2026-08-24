import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/connection_model.dart';
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

  // Background in-app chat listeners for all connected friends
  final Map<String, StreamSubscription<List<MessageModel>>> _backgroundChatSubs = {};
  final Map<String, Set<String>> _knownMessageIds = {};
  final Map<String, bool> _isInitialLoadDone = {};

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
        // Keep known message IDs synchronized
        _knownMessageIds.putIfAbsent(chatId, () => {}).addAll(messages.map((m) => m.id));
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

  /// Listens to message streams across all active connections to display
  /// in-app heads-up notifications when receiving messages outside the active chat screen.
  void listenToFriendChats({
    required String currentUid,
    required List<ConnectionUser> connections,
  }) {
    final currentChatIds = <String>{};

    for (final friend in connections) {
      final chatId = _databaseService.getChatId(currentUid, friend.uid);
      currentChatIds.add(chatId);

      if (!_backgroundChatSubs.containsKey(chatId)) {
        _isInitialLoadDone[chatId] = false;
        _knownMessageIds[chatId] = {};

        _backgroundChatSubs[chatId] = _databaseService.getMessagesStream(chatId).listen(
          (messages) {
            final isInitial = _isInitialLoadDone[chatId] == false;
            final known = _knownMessageIds[chatId] ?? {};

            if (!isInitial) {
              final newMessages = messages.where((m) => !known.contains(m.id)).toList();
              for (final msg in newMessages) {
                // Suppress if message was sent by self or if user is currently inside this chat room
                if (msg.senderId != currentUid && _activeChatId != chatId) {
                  _notificationService.showChatMessageNotification(
                    senderName: msg.senderName,
                    messageText: msg.text,
                    chatId: chatId,
                  );
                }
              }
            }

            _knownMessageIds[chatId] = messages.map((m) => m.id).toSet();
            _isInitialLoadDone[chatId] = true;
          },
          onError: (e) {
            debugPrint('Error in background message listener for $chatId: $e');
          },
        );
      }
    }

    // Clean up removed friends
    final toRemove = _backgroundChatSubs.keys.where((id) => !currentChatIds.contains(id)).toList();
    for (final id in toRemove) {
      _backgroundChatSubs[id]?.cancel();
      _backgroundChatSubs.remove(id);
      _knownMessageIds.remove(id);
      _isInitialLoadDone.remove(id);
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

  void clear() {
    closeChat();
    for (final sub in _backgroundChatSubs.values) {
      sub.cancel();
    }
    _backgroundChatSubs.clear();
    _knownMessageIds.clear();
    _isInitialLoadDone.clear();
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
}
