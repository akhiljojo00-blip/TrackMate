import 'package:firebase_database/firebase_database.dart';
import '../constants/app_constants.dart';
import '../models/user_model.dart';
import '../models/location_model.dart';
import '../models/connection_model.dart';
import '../models/message_model.dart';
import '../models/sos_alert_model.dart';

class DatabaseService {
  final FirebaseDatabase? _customDb;

  DatabaseService({FirebaseDatabase? database}) : _customDb = database;

  FirebaseDatabase get _db => _customDb ?? FirebaseDatabase.instance;

  DatabaseReference get _usersRef => _db.ref(AppConstants.usersPath);
  DatabaseReference get _userTokensRef => _db.ref(AppConstants.userTokensPath);
  DatabaseReference get _locationsRef => _db.ref(AppConstants.locationsPath);
  DatabaseReference get _locationPermissionsRef => _db.ref(AppConstants.locationPermissionsPath);
  DatabaseReference get _connectionsRef => _db.ref(AppConstants.connectionsPath);
  DatabaseReference get _connectionRequestsRef => _db.ref(AppConstants.connectionRequestsPath);
  DatabaseReference get _sentRequestsRef => _db.ref(AppConstants.sentRequestsPath);
  DatabaseReference get _chatsRef => _db.ref(AppConstants.chatsPath);
  DatabaseReference get _emergencyAlertsRef => _db.ref(AppConstants.emergencyAlertsPath);

  // User Profile Methods
  Future<void> createUserProfile(UserModel user) async {
    await _usersRef.child(user.uid).set(user.toMap());
  }

  Future<UserModel?> getUserProfile(String uid) async {
    final snapshot = await _usersRef.child(uid).get();
    if (snapshot.exists && snapshot.value != null) {
      final value = snapshot.value;
      if (value is Map) {
        return UserModel.fromMap(value, uid);
      }
    }
    return null;
  }

  Stream<DatabaseEvent> getUserStream(String uid) {
    return _usersRef.child(uid).onValue;
  }

  Future<void> updateLocationSharingConsent(String uid, bool isSharing) async {
    await _usersRef.child(uid).update({'isLocationSharing': isSharing});
  }

  // Device Token Management (FCM-2)
  Future<void> saveUserDeviceToken(String uid, String token) async {
    await _userTokensRef.child(uid).child('primary').set({
      'token': token,
      'updatedAt': ServerValue.timestamp,
      'platform': 'android',
    });
  }

  Future<void> clearUserDeviceToken(String uid) async {
    await _userTokensRef.child(uid).child('primary').remove();
  }

  Future<String?> getUserDeviceToken(String uid) async {
    final snapshot = await _userTokensRef.child(uid).child('primary').child('token').get();
    if (snapshot.exists && snapshot.value != null) {
      return snapshot.value.toString();
    }
    return null;
  }

  // User Search (by username prefix, strictly excluding GPS and filtering out current user)
  Future<List<UserModel>> searchUsersByUsername(String query, {String? currentUid}) async {
    final trimmedQuery = query.trim().toLowerCase();
    if (trimmedQuery.isEmpty) return [];

    final snapshot = await _usersRef
        .orderByChild('username')
        .startAt(trimmedQuery)
        .endAt('$trimmedQuery\uf8ff')
        .get();

    final List<UserModel> users = [];
    if (snapshot.exists && snapshot.value != null) {
      final value = snapshot.value;
      if (value is Map) {
        value.forEach((key, map) {
          if (map is Map) {
            final uid = key.toString();
            if (currentUid == null || uid != currentUid) {
              users.add(UserModel.fromMap(map, uid));
            }
          }
        });
      }
    }
    return users;
  }

  // Connection Requests
  Future<void> sendConnectionRequest({
    required UserModel sender,
    required String targetUid,
  }) async {
    if (sender.uid == targetUid) return;

    final request = ConnectionRequestModel(
      senderUid: sender.uid,
      senderName: sender.name,
      senderUsername: sender.username,
      receiverUid: targetUid,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      status: 'pending',
    );

    final Map<String, dynamic> updates = {
      '${AppConstants.connectionRequestsPath}/$targetUid/${sender.uid}': request.toMap(),
      '${AppConstants.sentRequestsPath}/${sender.uid}/$targetUid': request.toMap(),
    };

    await _db.ref().update(updates);
  }

  Future<void> respondToConnectionRequest({
    required UserModel currentUser,
    required ConnectionRequestModel request,
    required bool accept,
  }) async {
    final targetUid = request.senderUid;
    final currentUid = currentUser.uid;

    if (accept) {
      final now = DateTime.now().millisecondsSinceEpoch;

      final connectionForCurrent = ConnectionUser(
        uid: targetUid,
        name: request.senderName,
        username: request.senderUsername,
        connectedAt: now,
      );

      final connectionForSender = ConnectionUser(
        uid: currentUid,
        name: currentUser.name,
        username: currentUser.username,
        connectedAt: now,
      );

      final Map<String, dynamic> updates = {
        '${AppConstants.connectionsPath}/$currentUid/$targetUid': connectionForCurrent.toMap(),
        '${AppConstants.connectionsPath}/$targetUid/$currentUid': connectionForSender.toMap(),
        '${AppConstants.connectionRequestsPath}/$currentUid/$targetUid': null,
        '${AppConstants.sentRequestsPath}/$targetUid/$currentUid': null,
      };

      await _db.ref().update(updates);
    } else {
      final Map<String, dynamic> updates = {
        '${AppConstants.connectionRequestsPath}/$currentUid/$targetUid': null,
        '${AppConstants.sentRequestsPath}/$targetUid/$currentUid': null,
      };
      await _db.ref().update(updates);
    }
  }

  Future<void> cancelSentRequest({
    required String currentUid,
    required String targetUid,
  }) async {
    final Map<String, dynamic> updates = {
      '${AppConstants.connectionRequestsPath}/$targetUid/$currentUid': null,
      '${AppConstants.sentRequestsPath}/$currentUid/$targetUid': null,
    };
    await _db.ref().update(updates);
  }

  // Connections & Streams
  Stream<List<ConnectionRequestModel>> getIncomingRequestsStream(String currentUid) {
    return _connectionRequestsRef.child(currentUid).onValue.map((event) {
      final List<ConnectionRequestModel> requests = [];
      if (event.snapshot.exists && event.snapshot.value != null) {
        final value = event.snapshot.value;
        if (value is Map) {
          value.forEach((key, map) {
            if (map is Map) {
              requests.add(ConnectionRequestModel.fromMap(map, senderUid: key.toString(), receiverUid: currentUid));
            }
          });
        }
      }
      requests.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return requests;
    });
  }

  Stream<List<ConnectionRequestModel>> getSentRequestsStream(String currentUid) {
    return _sentRequestsRef.child(currentUid).onValue.map((event) {
      final List<ConnectionRequestModel> requests = [];
      if (event.snapshot.exists && event.snapshot.value != null) {
        final value = event.snapshot.value;
        if (value is Map) {
          value.forEach((key, map) {
            if (map is Map) {
              requests.add(ConnectionRequestModel.fromMap(map, senderUid: currentUid, receiverUid: key.toString()));
            }
          });
        }
      }
      return requests;
    });
  }

  Stream<List<ConnectionUser>> getConnectionsStream(String currentUid) {
    return _connectionsRef.child(currentUid).onValue.map((event) {
      final List<ConnectionUser> connections = [];
      if (event.snapshot.exists && event.snapshot.value != null) {
        final value = event.snapshot.value;
        if (value is Map) {
          value.forEach((key, map) {
            if (map is Map) {
              connections.add(ConnectionUser.fromMap(map, key.toString()));
            }
          });
        }
      }
      connections.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return connections;
    });
  }

  Future<void> removeConnection(String currentUid, String targetUid) async {
    final Map<String, dynamic> updates = {
      '${AppConstants.connectionsPath}/$currentUid/$targetUid': null,
      '${AppConstants.connectionsPath}/$targetUid/$currentUid': null,
    };
    await _db.ref().update(updates);
  }

  // Real-Time 1-to-1 Chat Operations
  String getChatId(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<void> sendMessage({
    required String chatId,
    required MessageModel message,
  }) async {
    final messageRef = _chatsRef.child(chatId).child(AppConstants.messagesPath).push();
    final newId = messageRef.key ?? DateTime.now().millisecondsSinceEpoch.toString();
    final messageToSave = message.copyWith(id: newId);
    await messageRef.set(messageToSave.toMap());
  }

  Stream<List<MessageModel>> getMessagesStream(String chatId) {
    return _chatsRef
        .child(chatId)
        .child(AppConstants.messagesPath)
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      final List<MessageModel> messages = [];
      if (event.snapshot.exists && event.snapshot.value != null) {
        final value = event.snapshot.value;
        if (value is Map) {
          value.forEach((key, map) {
            if (map is Map) {
              messages.add(MessageModel.fromMap(map, key.toString()));
            }
          });
        }
      }
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    });
  }

  // Location & Directional Permission Methods
  Future<void> updateUserLocation(String uid, LocationModel location) async {
    await _locationsRef.child(uid).set(location.toMap());
  }

  Future<void> clearUserLocation(String uid) async {
    await _locationsRef.child(uid).remove();
  }

  Future<void> setLocationSharingPermission({
    required String ownerUid,
    required String friendUid,
    required bool isAllowed,
  }) async {
    await _locationPermissionsRef
        .child(ownerUid)
        .child(friendUid)
        .set(isAllowed);
  }

  Stream<bool> getLocationPermissionStream(String ownerUid, String friendUid) {
    return _locationPermissionsRef
        .child(ownerUid)
        .child(friendUid)
        .onValue
        .map((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        return event.snapshot.value as bool? ?? false;
      }
      return false;
    });
  }

  Stream<LocationModel?> getUserLocationStream(String targetUid) {
    return _locationsRef.child(targetUid).onValue.map((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final value = event.snapshot.value;
        if (value is Map) {
          return LocationModel.fromMap(value, targetUid);
        }
      }
      return null;
    });
  }

  // Emergency SOS Operations (SOS-2 / SOS-3)
  Future<void> sendSosAlert(SosAlertModel alert) async {
    await _emergencyAlertsRef.child(alert.senderUid).set(alert.toMap());
  }

  Future<void> cancelSosAlert(String uid) async {
    await _emergencyAlertsRef.child(uid).remove();
  }

  Stream<SosAlertModel?> getEmergencyAlertStream(String uid) {
    return _emergencyAlertsRef.child(uid).onValue.map((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final value = event.snapshot.value;
        if (value is Map) {
          return SosAlertModel.fromMap(value, uid);
        }
      }
      return null;
    });
  }

  // Reference Getters
  DatabaseReference get usersRef => _usersRef;
  DatabaseReference get userTokensRef => _userTokensRef;
  DatabaseReference get locationsRef => _locationsRef;
  DatabaseReference get locationPermissionsRef => _locationPermissionsRef;
  DatabaseReference get connectionsRef => _connectionsRef;
  DatabaseReference get connectionRequestsRef => _connectionRequestsRef;
  DatabaseReference get sentRequestsRef => _sentRequestsRef;
  DatabaseReference get chatsRef => _chatsRef;
  DatabaseReference get emergencyAlertsRef => _emergencyAlertsRef;
}
