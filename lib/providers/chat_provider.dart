import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../models/connection_model.dart';
import '../models/message_model.dart';
import '../services/database_service.dart';
import '../services/media_service.dart';
import '../services/notification_service.dart';

class ChatProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final NotificationService _notificationService = NotificationService();
  final MediaService _mediaService;

  ChatProvider({MediaService? mediaService})
      : _mediaService = mediaService ?? MediaService();

  List<MessageModel> _messages = [];
  bool _isSending = false;
  bool _isUploadingImage = false;
  bool _isAcquiringLocation = false;
  double _uploadProgress = 0.0;
  String? _chatError;
  String? _activeChatId;
  StreamSubscription<List<MessageModel>>? _messagesSub;

  // Background in-app chat listeners for all connected friends
  final Map<String, StreamSubscription<List<MessageModel>>> _backgroundChatSubs = {};
  final Map<String, Set<String>> _knownMessageIds = {};
  final Map<String, bool> _isInitialLoadDone = {};

  List<MessageModel> get messages => _messages;
  bool get isSending => _isSending;
  bool get isUploadingImage => _isUploadingImage;
  bool get isAcquiringLocation => _isAcquiringLocation;
  double get uploadProgress => _uploadProgress;
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
    _isUploadingImage = false;
    _isAcquiringLocation = false;
    _uploadProgress = 0.0;
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
    _isUploadingImage = false;
    _isAcquiringLocation = false;
    _uploadProgress = 0.0;
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
                  final displayBody = msg.isImage
                      ? (msg.text.isNotEmpty ? '📷 ${msg.text}' : '📷 Sent a photo')
                      : (msg.isLocation ? '📍 Shared a location' : msg.text);

                  _notificationService.showChatMessageNotification(
                    senderName: msg.senderName,
                    messageText: displayBody,
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
        type: 'text',
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

  /// Handles picking, compression, uploading, and dispatching an image message.
  Future<bool> sendImageMessage({
    required String currentUid,
    required String currentName,
    required ImageSource source,
    String? caption,
  }) async {
    if (_activeChatId == null) return false;

    // Pick & Compress image (safely returns null if user cancelled)
    final compressedFile = await _mediaService.pickAndCompressImage(source: source);
    if (compressedFile == null) {
      return false;
    }

    _isUploadingImage = true;
    _uploadProgress = 0.0;
    _chatError = null;
    notifyListeners();

    try {
      final downloadUrl = await _mediaService.uploadChatImage(
        chatId: _activeChatId!,
        file: compressedFile,
        onProgress: (progress) {
          _uploadProgress = progress;
          notifyListeners();
        },
      );

      if (downloadUrl == null) {
        _chatError = 'Failed to upload image. Please check your network connection.';
        return false;
      }

      final message = MessageModel(
        id: '',
        senderId: currentUid,
        senderName: currentName,
        text: caption?.trim() ?? '',
        type: 'image',
        imageUrl: downloadUrl,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      await _databaseService.sendMessage(
        chatId: _activeChatId!,
        message: message,
      );
      return true;
    } catch (e) {
      _chatError = 'Failed to send image: $e';
      debugPrint('Error in sendImageMessage: $e');
      return false;
    } finally {
      _isUploadingImage = false;
      _uploadProgress = 0.0;
      notifyListeners();
    }
  }

  /// Captures a ONE-TIME GPS coordinate snapshot and attaches it to a chat message.
  /// INVARIANT: This is strictly a one-time snapshot and does NOT enable live location tracking,
  /// modify user location permissions, or alter `/locations`.
  Future<bool> sendLocationMessage({
    required String currentUid,
    required String currentName,
  }) async {
    if (_activeChatId == null) return false;

    _isAcquiringLocation = true;
    _chatError = null;
    notifyListeners();

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _chatError = 'Location services are disabled on your device. Please enable GPS in settings.';
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _chatError = 'Location permission is required to share current location.';
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _chatError = 'Location permission is permanently denied. Please enable it in system settings.';
        return false;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final message = MessageModel(
        id: '',
        senderId: currentUid,
        senderName: currentName,
        text: '📍 Shared Location',
        type: 'location',
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      await _databaseService.sendMessage(
        chatId: _activeChatId!,
        message: message,
      );
      return true;
    } catch (e) {
      _chatError = 'Failed to acquire location: $e';
      debugPrint('Error sending location message: $e');
      return false;
    } finally {
      _isAcquiringLocation = false;
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
