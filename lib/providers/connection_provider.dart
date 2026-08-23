import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/connection_model.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';

class ConnectionProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();

  List<ConnectionUser> _connections = [];
  List<ConnectionRequestModel> _incomingRequests = [];
  List<UserModel> _searchResults = [];
  final Set<String> _pendingSentTargetUids = {};

  bool _isLoading = false;
  bool _isSearching = false;
  String? _searchError;
  String? _currentUid;

  StreamSubscription<List<ConnectionUser>>? _connectionsSub;
  StreamSubscription<List<ConnectionRequestModel>>? _requestsSub;

  List<ConnectionUser> get connections => _connections;
  List<ConnectionRequestModel> get incomingRequests => _incomingRequests;
  List<UserModel> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get searchError => _searchError;

  void initializeForUser(String uid) {
    if (_currentUid == uid) return;
    _currentUid = uid;
    _cancelSubscriptions();

    _connectionsSub = _databaseService.getConnectionsStream(uid).listen(
      (connections) {
        _connections = connections;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Error listening to connections: $e');
      },
    );

    _requestsSub = _databaseService.getIncomingRequestsStream(uid).listen(
      (requests) {
        _incomingRequests = requests;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Error listening to incoming requests: $e');
      },
    );
  }

  void clear() {
    _cancelSubscriptions();
    _currentUid = null;
    _connections = [];
    _incomingRequests = [];
    _searchResults = [];
    _pendingSentTargetUids.clear();
    _isSearching = false;
    _searchError = null;
    notifyListeners();
  }

  void _cancelSubscriptions() {
    _connectionsSub?.cancel();
    _connectionsSub = null;
    _requestsSub?.cancel();
    _requestsSub = null;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  bool isConnectedWith(String targetUid) {
    return _connections.any((c) => c.uid == targetUid);
  }

  bool isRequestPending(String targetUid) {
    return _pendingSentTargetUids.contains(targetUid);
  }

  Future<void> searchUsers(String query, String currentUid) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _searchResults = [];
      _searchError = null;
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    _searchError = null;
    notifyListeners();

    try {
      _searchResults = await _databaseService.searchUsersByUsername(
        trimmed,
        currentUid: currentUid,
      );
    } catch (e) {
      _searchError = 'Search failed: ${e.toString()}';
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchResults = [];
    _searchError = null;
    _isSearching = false;
    notifyListeners();
  }

  Future<bool> sendRequest({
    required UserModel sender,
    required String targetUid,
  }) async {
    try {
      _pendingSentTargetUids.add(targetUid);
      notifyListeners();

      await _databaseService.sendConnectionRequest(
        sender: sender,
        targetUid: targetUid,
      );
      return true;
    } catch (e) {
      _pendingSentTargetUids.remove(targetUid);
      notifyListeners();
      debugPrint('Error sending connection request: $e');
      return false;
    }
  }

  Future<bool> acceptRequest({
    required UserModel currentUser,
    required ConnectionRequestModel request,
  }) async {
    _setLoading(true);
    try {
      await _databaseService.respondToConnectionRequest(
        currentUser: currentUser,
        request: request,
        accept: true,
      );
      return true;
    } catch (e) {
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
    _setLoading(true);
    try {
      await _databaseService.respondToConnectionRequest(
        currentUser: currentUser,
        request: request,
        accept: false,
      );
      return true;
    } catch (e) {
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
    _setLoading(true);
    try {
      await _databaseService.cancelSentRequest(
        currentUid: currentUid,
        targetUid: targetUid,
      );
      _pendingSentTargetUids.remove(targetUid);
      return true;
    } catch (e) {
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
    _setLoading(true);
    try {
      await _databaseService.removeConnection(currentUid, targetUid);
      return true;
    } catch (e) {
      debugPrint('Error removing friend: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}
