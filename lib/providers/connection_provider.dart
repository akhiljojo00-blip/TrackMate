import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/connection_model.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class ConnectionProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final NotificationService _notificationService = NotificationService();

  List<ConnectionUser> _connections = [];
  List<ConnectionRequestModel> _incomingRequests = [];
  List<ConnectionRequestModel> _sentRequests = [];
  List<UserModel> _searchResults = [];
  final Set<String> _pendingSentTargetUids = {};

  bool _isFirstRequestsLoad = true;
  bool _isFirstConnectionsLoad = true;

  bool _isLoading = false;
  bool _isSearching = false;
  String? _searchError;
  String? _actionError;
  String? _currentUid;

  StreamSubscription<List<ConnectionUser>>? _connectionsSub;
  StreamSubscription<List<ConnectionRequestModel>>? _requestsSub;
  StreamSubscription<List<ConnectionRequestModel>>? _sentRequestsSub;

  Timer? _searchDebounceTimer;
  int _activeSearchToken = 0;
  static const int minSearchQueryLength = 2;
  static const Duration defaultDebounceDuration = Duration(milliseconds: 300);

  List<ConnectionUser> get connections => _connections;
  List<ConnectionRequestModel> get incomingRequests => _incomingRequests;
  List<ConnectionRequestModel> get sentRequests => _sentRequests;
  List<UserModel> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get searchError => _searchError;
  String? get actionError => _actionError;
  String? get currentUid => _currentUid;
  int get activeSearchToken => _activeSearchToken;

  void initializeForUser(String uid) {
    if (_currentUid == uid &&
        _connectionsSub != null &&
        _requestsSub != null &&
        _sentRequestsSub != null) {
      return;
    }

    _currentUid = uid;
    _isFirstRequestsLoad = true;
    _isFirstConnectionsLoad = true;
    _cancelSubscriptions();

    _connectionsSub = _databaseService.getConnectionsStream(uid).listen(
      (connections) {
        if (!_isFirstConnectionsLoad) {
          final newConnections = connections.where(
            (c) => !_connections.any((prev) => prev.uid == c.uid),
          );
          for (final newFriend in newConnections) {
            final wasSent = _sentRequests.any((r) => r.receiverUid == newFriend.uid) ||
                _pendingSentTargetUids.contains(newFriend.uid);
            if (wasSent) {
              _notificationService.showRequestAcceptedNotification(
                friendName: newFriend.name,
              );
            }
          }
        }
        _isFirstConnectionsLoad = false;
        _connections = connections;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Error listening to connections: $e');
      },
    );

    _requestsSub = _databaseService.getIncomingRequestsStream(uid).listen(
      (requests) {
        if (!_isFirstRequestsLoad) {
          final newRequests = requests.where(
            (r) => !_incomingRequests.any((prev) => prev.senderUid == r.senderUid),
          );
          for (final newReq in newRequests) {
            _notificationService.showFriendRequestNotification(
              senderName: newReq.senderName,
            );
          }
        }
        _isFirstRequestsLoad = false;
        _incomingRequests = requests;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Error listening to incoming requests: $e');
      },
    );

    _sentRequestsSub = _databaseService.getSentRequestsStream(uid).listen(
      (sent) {
        _sentRequests = sent;
        _pendingSentTargetUids.removeWhere(
          (targetUid) => !_sentRequests.any((r) => r.receiverUid == targetUid),
        );
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Error listening to sent requests: $e');
      },
    );
  }

  void clear() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = null;
    _activeSearchToken++;
    _cancelSubscriptions();
    _currentUid = null;
    _connections = [];
    _incomingRequests = [];
    _sentRequests = [];
    _searchResults = [];
    _pendingSentTargetUids.clear();
    _isFirstRequestsLoad = true;
    _isFirstConnectionsLoad = true;
    _isSearching = false;
    _searchError = null;
    _actionError = null;
    notifyListeners();
  }

  void _cancelSubscriptions() {
    _connectionsSub?.cancel();
    _connectionsSub = null;
    _requestsSub?.cancel();
    _requestsSub = null;
    _sentRequestsSub?.cancel();
    _sentRequestsSub = null;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  bool isConnectedWith(String targetUid) {
    return _connections.any((c) => c.uid == targetUid);
  }

  bool isRequestPending(String targetUid) {
    return _pendingSentTargetUids.contains(targetUid) ||
        _sentRequests.any((r) => r.receiverUid == targetUid);
  }

  void searchUsers(
    String query,
    String currentUid, {
    Duration debounceDuration = defaultDebounceDuration,
    bool immediate = false,
  }) {
    final trimmed = query.trim().toLowerCase();

    // Cancel active debouncing timer
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = null;

    // Queries shorter than minimum length immediately clear results and cancel work
    if (trimmed.length < minSearchQueryLength) {
      _activeSearchToken++;
      _searchResults = [];
      _searchError = null;
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    _searchError = null;
    notifyListeners();

    if (immediate) {
      final token = ++_activeSearchToken;
      _executeSearch(trimmed, currentUid, token);
    } else {
      final token = ++_activeSearchToken;
      _searchDebounceTimer = Timer(debounceDuration, () {
        _executeSearch(trimmed, currentUid, token);
      });
    }
  }

  Future<void> _executeSearch(String query, String currentUid, int requestToken) async {
    try {
      final results = await _databaseService.searchUsersByUsername(
        query,
        currentUid: currentUid,
      );

      // Discard stale responses if newer search was dispatched
      if (requestToken != _activeSearchToken) {
        debugPrint('Discarding stale search response for token $requestToken (active: $_activeSearchToken)');
        return;
      }

      _searchResults = results;
      _searchError = null;
    } catch (e) {
      if (requestToken == _activeSearchToken) {
        _searchError = 'Search failed: ${e.toString()}';
        _searchResults = [];
      }
    } finally {
      if (requestToken == _activeSearchToken) {
        _isSearching = false;
        notifyListeners();
      }
    }
  }

  void clearSearch() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = null;
    _activeSearchToken++;
    _searchResults = [];
    _searchError = null;
    _isSearching = false;
    notifyListeners();
  }

  Future<bool> sendRequest({
    required UserModel sender,
    required String targetUid,
  }) async {
    _actionError = null;
    final trimmedTargetUid = targetUid.trim();
    final trimmedSenderUid = sender.uid.trim();

    if (trimmedSenderUid.isEmpty || trimmedTargetUid.isEmpty) {
      _actionError = 'Invalid sender or target user ID.';
      notifyListeners();
      return false;
    }
    if (trimmedSenderUid == trimmedTargetUid) {
      _actionError = 'You cannot send a connection request to yourself.';
      notifyListeners();
      return false;
    }
    if (isConnectedWith(trimmedTargetUid)) {
      _actionError = 'You are already connected with this user.';
      notifyListeners();
      return false;
    }
    if (isRequestPending(trimmedTargetUid)) {
      _actionError = 'A connection request is already pending.';
      notifyListeners();
      return false;
    }

    try {
      _pendingSentTargetUids.add(trimmedTargetUid);
      notifyListeners();

      await _databaseService.sendConnectionRequest(
        sender: sender,
        targetUid: trimmedTargetUid,
      );
      return true;
    } catch (e) {
      _pendingSentTargetUids.remove(trimmedTargetUid);
      _actionError = 'Failed to send request: ${e.toString()}';
      notifyListeners();
      debugPrint('Error sending connection request: $e');
      return false;
    }
  }

  Future<bool> acceptRequest({
    required UserModel currentUser,
    required ConnectionRequestModel request,
  }) async {
    _actionError = null;
    _setLoading(true);
    try {
      await _databaseService.respondToConnectionRequest(
        currentUser: currentUser,
        request: request,
        accept: true,
      );
      return true;
    } catch (e) {
      _actionError = 'Failed to accept request: ${e.toString()}';
      debugPrint('Error accepting request: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> declineRequest({
    required UserModel currentUser,
    required ConnectionRequestModel request,
  }) async {
    _actionError = null;
    _setLoading(true);
    try {
      await _databaseService.respondToConnectionRequest(
        currentUser: currentUser,
        request: request,
        accept: false,
      );
      return true;
    } catch (e) {
      _actionError = 'Failed to decline request: ${e.toString()}';
      debugPrint('Error declining request: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> cancelSentRequest({
    required String currentUid,
    required String targetUid,
  }) async {
    _actionError = null;
    _setLoading(true);
    try {
      await _databaseService.cancelSentRequest(
        currentUid: currentUid,
        targetUid: targetUid,
      );
      _pendingSentTargetUids.remove(targetUid);
      notifyListeners();
      return true;
    } catch (e) {
      _actionError = 'Failed to cancel request: ${e.toString()}';
      debugPrint('Error canceling sent request: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> removeFriend({
    required String currentUid,
    required String targetUid,
  }) async {
    _actionError = null;
    _setLoading(true);
    try {
      await _databaseService.removeConnection(currentUid, targetUid);
      return true;
    } catch (e) {
      _actionError = 'Failed to remove connection: ${e.toString()}';
      debugPrint('Error removing friend: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = null;
    _cancelSubscriptions();
    super.dispose();
  }
}
