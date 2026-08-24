import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import '../models/user_model.dart';
import '../models/location_model.dart';
import '../models/connection_model.dart';
import '../models/message_model.dart';
import '../models/sos_alert_model.dart';
import '../models/group_model.dart';
import '../models/group_member_model.dart';
import '../models/group_location_session_model.dart';
import '../models/group_session_participant_model.dart';

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
  DatabaseReference get _groupsRef => _db.ref(AppConstants.groupsPath);
  DatabaseReference get _groupMembersRef => _db.ref(AppConstants.groupMembersPath);
  DatabaseReference get _userGroupsRef => _db.ref(AppConstants.userGroupsPath);
  DatabaseReference get _groupMessagesRef => _db.ref(AppConstants.groupMessagesPath);
  DatabaseReference get _groupReadStateRef => _db.ref(AppConstants.groupReadStatePath);
  DatabaseReference get _groupLocationSessionsRef => _db.ref(AppConstants.groupLocationSessionsPath);
  DatabaseReference get _groupSessionParticipantsRef => _db.ref(AppConstants.groupSessionParticipantsPath);
  DatabaseReference get _groupLiveLocationsRef => _db.ref(AppConstants.groupLiveLocationsPath);

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

  Future<String?> getEmailByUsername(String username) async {
    try {
      final query = username.trim().toLowerCase();
      final snapshot = await _usersRef
          .orderByChild('username')
          .equalTo(query)
          .limitToFirst(1)
          .get();

      if (snapshot.exists && snapshot.value != null) {
        final value = snapshot.value;
        if (value is Map) {
          final firstUser = value.values.first;
          if (firstUser is Map && firstUser['email'] != null) {
            return firstUser['email'].toString();
          }
        }
      }
    } catch (e) {
      debugPrint('Notice: unable to query user email by username: $e');
    }
    return null;
  }

  Stream<DatabaseEvent> getUserStream(String uid) {
    return _usersRef.child(uid).onValue;
  }

  Future<void> updateLocationSharingConsent(String uid, bool isSharing) async {
    await _usersRef.child(uid).update({'isLocationSharing': isSharing});
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> updates) async {
    // Exclude protected fields from being modified
    updates.remove('email');
    updates.remove('username');
    updates.remove('createdAt');
    updates.remove('uid');
    await _usersRef.child(uid).update(updates);
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

  // Emergency SOS Operations (SOS-2 / SOS-3 / SOS-4)
  Future<void> sendSosAlert(SosAlertModel alert) async {
    try {
      await _emergencyAlertsRef.child(alert.senderUid).set(alert.toMap());
      debugPrint('SOS alert broadcasted to Realtime Database: emergency_alerts/${alert.senderUid}');
    } catch (e) {
      debugPrint('Error writing SOS alert to database: $e');
      rethrow;
    }
  }

  Future<void> cancelSosAlert(String uid) async {
    try {
      await _emergencyAlertsRef.child(uid).update({'isActive': false});
      await _emergencyAlertsRef.child(uid).remove();
      debugPrint('SOS alert successfully removed from emergency_alerts/$uid');
    } catch (e) {
      debugPrint('Error canceling SOS alert from database: $e');
      // Fallback direct remove
      await _emergencyAlertsRef.child(uid).remove();
    }
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

  // Group Chat Operations (Phase 7.1)
  Future<String> createGroup({
    required String name,
    String? description,
    int avatarPresetIndex = 0,
    required String creatorUid,
    required List<String> memberUids,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final groupId = _groupsRef.push().key!;
    final allMembers = {creatorUid, ...memberUids}.toList();

    final group = GroupModel(
      id: groupId,
      name: name.trim(),
      description: description?.trim(),
      avatarPresetIndex: avatarPresetIndex,
      ownerId: creatorUid,
      createdAt: now,
      updatedAt: now,
      memberCount: allMembers.length,
    );

    final updates = <String, dynamic>{};
    updates['${AppConstants.groupsPath}/$groupId'] = group.toMap();
    updates['${AppConstants.groupMembersPath}/$groupId/$creatorUid'] = GroupMemberModel(
      uid: creatorUid,
      role: 'owner',
      joinedAt: now,
    ).toMap();

    for (final memberUid in memberUids) {
      if (memberUid != creatorUid) {
        updates['${AppConstants.groupMembersPath}/$groupId/$memberUid'] = GroupMemberModel(
          uid: memberUid,
          role: 'member',
          joinedAt: now,
        ).toMap();
      }
    }

    for (final u in allMembers) {
      updates['${AppConstants.userGroupsPath}/$u/$groupId'] = true;
    }

    await _db.ref().update(updates);
    return groupId;
  }

  Future<GroupModel?> getGroup(String groupId) async {
    final snapshot = await _groupsRef.child(groupId).get();
    if (snapshot.exists && snapshot.value is Map) {
      return GroupModel.fromMap(snapshot.value as Map, groupId);
    }
    return null;
  }

  Stream<GroupModel?> getGroupStream(String groupId) {
    return _groupsRef.child(groupId).onValue.map((event) {
      if (event.snapshot.exists && event.snapshot.value is Map) {
        return GroupModel.fromMap(event.snapshot.value as Map, groupId);
      }
      return null;
    });
  }

  Stream<List<GroupModel>> listenToUserGroups(String uid) {
    return _userGroupsRef.child(uid).onValue.asyncMap((event) async {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return <GroupModel>[];
      }

      final dynamic val = event.snapshot.value;
      if (val is! Map) return <GroupModel>[];

      final groupIds = val.keys.map((k) => k.toString()).toList();
      final List<GroupModel> groups = [];

      for (final gId in groupIds) {
        final groupSnapshot = await _groupsRef.child(gId).get();
        if (groupSnapshot.exists && groupSnapshot.value is Map) {
          groups.add(GroupModel.fromMap(groupSnapshot.value as Map, gId));
        }
      }

      // Sort by updatedAt descending (most recent group messages/activity first)
      groups.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return groups;
    });
  }

  Stream<List<GroupMemberModel>> listenToGroupMembers(String groupId) {
    return _groupMembersRef.child(groupId).onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return <GroupMemberModel>[];
      }

      final dynamic val = event.snapshot.value;
      if (val is! Map) return <GroupMemberModel>[];

      final List<GroupMemberModel> members = [];
      val.forEach((key, data) {
        if (data is Map) {
          members.add(GroupMemberModel.fromMap(data, key.toString()));
        }
      });

      return members;
    });
  }

  Future<void> addMemberToGroup({
    required String groupId,
    required String targetUid,
    String role = 'member',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updates = <String, dynamic>{
      '${AppConstants.groupMembersPath}/$groupId/$targetUid': GroupMemberModel(
        uid: targetUid,
        role: role,
        joinedAt: now,
      ).toMap(),
      '${AppConstants.userGroupsPath}/$targetUid/$groupId': true,
      '${AppConstants.groupsPath}/$groupId/updatedAt': now,
    };

    final membersSnapshot = await _groupMembersRef.child(groupId).get();
    int currentCount = 0;
    if (membersSnapshot.exists && membersSnapshot.value is Map) {
      currentCount = (membersSnapshot.value as Map).length;
    }
    updates['${AppConstants.groupsPath}/$groupId/memberCount'] = currentCount + 1;

    await _db.ref().update(updates);
  }

  Future<void> removeMemberFromGroup({
    required String groupId,
    required String targetUid,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updates = <String, dynamic>{
      '${AppConstants.groupMembersPath}/$groupId/$targetUid': null,
      '${AppConstants.userGroupsPath}/$targetUid/$groupId': null,
      '${AppConstants.groupsPath}/$groupId/updatedAt': now,
    };

    final membersSnapshot = await _groupMembersRef.child(groupId).get();
    int currentCount = 1;
    if (membersSnapshot.exists && membersSnapshot.value is Map) {
      currentCount = (membersSnapshot.value as Map).length;
    }
    final newCount = (currentCount - 1).clamp(0, 9999);
    updates['${AppConstants.groupsPath}/$groupId/memberCount'] = newCount;

    await _db.ref().update(updates);
  }

  Future<void> transferGroupOwnership({
    required String groupId,
    required String currentOwnerUid,
    required String newOwnerUid,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updates = <String, dynamic>{
      '${AppConstants.groupsPath}/$groupId/ownerId': newOwnerUid,
      '${AppConstants.groupsPath}/$groupId/updatedAt': now,
      '${AppConstants.groupMembersPath}/$groupId/$currentOwnerUid/role': 'admin',
      '${AppConstants.groupMembersPath}/$groupId/$newOwnerUid/role': 'owner',
    };
    await _db.ref().update(updates);
  }

  Future<void> deleteGroup({required String groupId}) async {
    final membersSnapshot = await _groupMembersRef.child(groupId).get();
    final updates = <String, dynamic>{
      '${AppConstants.groupsPath}/$groupId': null,
      '${AppConstants.groupMembersPath}/$groupId': null,
      '${AppConstants.groupMessagesPath}/$groupId': null,
      '${AppConstants.groupReadStatePath}/$groupId': null,
    };

    if (membersSnapshot.exists && membersSnapshot.value is Map) {
      final membersMap = membersSnapshot.value as Map;
      for (final mUid in membersMap.keys) {
        updates['${AppConstants.userGroupsPath}/$mUid/$groupId'] = null;
      }
    }

    await _db.ref().update(updates);
  }

  Future<void> leaveGroup({
    required String groupId,
    required String uid,
  }) async {
    final membersSnapshot = await _groupMembersRef.child(groupId).get();
    if (membersSnapshot.exists && membersSnapshot.value is Map) {
      final membersMap = membersSnapshot.value as Map;
      if (membersMap.length <= 1) {
        // Sole member leaving -> delete entire group cleanly
        await deleteGroup(groupId: groupId);
        return;
      }
    }
    await removeMemberFromGroup(groupId: groupId, targetUid: uid);
  }

  Future<void> sendGroupTextMessage({
    required String groupId,
    required MessageModel message,
  }) async {
    final msgId = _groupMessagesRef.child(groupId).push().key!;
    final now = DateTime.now().millisecondsSinceEpoch;
    final fullMessage = message.copyWith(id: msgId, timestamp: now);

    final summaryText = fullMessage.isImage
        ? '📷 Photo'
        : (fullMessage.isLocation ? '📍 Shared Location' : fullMessage.text);

    final updates = <String, dynamic>{
      '${AppConstants.groupMessagesPath}/$groupId/$msgId': fullMessage.toMap(),
      '${AppConstants.groupsPath}/$groupId/lastMessageText': summaryText,
      '${AppConstants.groupsPath}/$groupId/lastMessageTimestamp': now,
      '${AppConstants.groupsPath}/$groupId/lastMessageSenderId': fullMessage.senderId,
      '${AppConstants.groupsPath}/$groupId/lastMessageSenderName': fullMessage.senderName,
      '${AppConstants.groupsPath}/$groupId/updatedAt': now,
    };

    await _db.ref().update(updates);

    // Group Notification Fan-Out (non-blocking)
    try {
      final groupSnap = await _groupsRef.child(groupId).get();
      String groupName = 'Group Chat';
      if (groupSnap.exists && groupSnap.value is Map) {
        groupName = (groupSnap.value as Map)['name']?.toString() ?? 'Group Chat';
      }

      final membersSnap = await _groupMembersRef.child(groupId).get();
      if (membersSnap.exists && membersSnap.value is Map) {
        final membersMap = membersSnap.value as Map;
        for (final recipientUid in membersMap.keys) {
          final rUidStr = recipientUid.toString();
          if (rUidStr != fullMessage.senderId) {
            final token = await getUserDeviceToken(rUidStr);
            if (token != null && token.isNotEmpty) {
              debugPrint('FCM fan-out: group message notification to $rUidStr ($groupName: ${fullMessage.senderName}: $summaryText)');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fanning out group message notifications: $e');
    }
  }

  Stream<List<MessageModel>> listenToGroupMessages(String groupId) {
    return _groupMessagesRef
        .child(groupId)
        .orderByChild('timestamp')
        .limitToLast(50)
        .onValue
        .map((event) {
      final List<MessageModel> messages = [];
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value;
        if (data is Map) {
          data.forEach((key, value) {
            if (value is Map) {
              messages.add(MessageModel.fromMap(value, key.toString()));
            }
          });
        }
      }
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    });
  }

  Future<void> markGroupAsRead({
    required String groupId,
    required String uid,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _groupReadStateRef.child(groupId).child(uid).set({
        'lastReadTimestamp': now,
      });
    } catch (e) {
      debugPrint('Error marking group as read: $e');
    }
  }

  Stream<int?> listenToGroupLastRead({
    required String groupId,
    required String uid,
  }) {
    return _groupReadStateRef
        .child(groupId)
        .child(uid)
        .child('lastReadTimestamp')
        .onValue
        .map((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final val = event.snapshot.value;
        if (val is num) {
          return val.toInt();
        }
      }
      return null;
    });
  }

  Future<int?> getGroupLastRead({
    required String groupId,
    required String uid,
  }) async {
    try {
      final snapshot = await _groupReadStateRef
          .child(groupId)
          .child(uid)
          .child('lastReadTimestamp')
          .get();
      if (snapshot.exists && snapshot.value is num) {
        return (snapshot.value as num).toInt();
      }
    } catch (e) {
      debugPrint('Error fetching group last read timestamp: $e');
    }
    return null;
  }

  // Group Location Session Operations (Phase 8.1)
  Future<String> startGroupLocationSession({
    required String groupId,
    required String creatorUid,
    required String creatorName,
    required int avatarPresetIndex,
    String? title,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final sessionId = _groupLocationSessionsRef.child(groupId).push().key!;
    final sessionTitle = (title != null && title.trim().isNotEmpty)
        ? title.trim()
        : 'Live Group Location';

    final session = GroupLocationSessionModel(
      sessionId: sessionId,
      groupId: groupId,
      createdBy: creatorUid,
      createdAt: now,
      title: sessionTitle,
      isActive: true,
    );

    final participant = GroupSessionParticipantModel(
      uid: creatorUid,
      displayName: creatorName,
      avatarPresetIndex: avatarPresetIndex,
      isSharing: true,
      joinedAt: now,
    );

    final msgId = _groupMessagesRef.child(groupId).push().key!;
    final systemMessage = MessageModel(
      id: msgId,
      senderId: creatorUid,
      senderName: creatorName,
      text: '📍 Started a live group location session: "$sessionTitle"',
      type: 'text',
      timestamp: now,
    );

    final updates = <String, dynamic>{
      '${AppConstants.groupLocationSessionsPath}/$groupId': session.toMap(),
      '${AppConstants.groupSessionParticipantsPath}/$groupId/$creatorUid': participant.toMap(),
      '${AppConstants.groupMessagesPath}/$groupId/$msgId': systemMessage.toMap(),
      '${AppConstants.groupsPath}/$groupId/lastMessageText': '📍 Live location session active',
      '${AppConstants.groupsPath}/$groupId/lastMessageTimestamp': now,
      '${AppConstants.groupsPath}/$groupId/lastMessageSenderId': creatorUid,
      '${AppConstants.groupsPath}/$groupId/lastMessageSenderName': creatorName,
      '${AppConstants.groupsPath}/$groupId/updatedAt': now,
    };

    await _db.ref().update(updates);
    return sessionId;
  }

  Stream<GroupLocationSessionModel?> listenToActiveGroupSession(String groupId) {
    return _groupLocationSessionsRef.child(groupId).onValue.map((event) {
      if (event.snapshot.exists && event.snapshot.value is Map) {
        final session = GroupLocationSessionModel.fromMap(
          event.snapshot.value as Map,
          groupId,
        );
        if (session.isActive) {
          return session;
        }
      }
      return null;
    });
  }

  Stream<List<GroupSessionParticipantModel>> listenToGroupSessionParticipants(String groupId) {
    return _groupSessionParticipantsRef.child(groupId).onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return <GroupSessionParticipantModel>[];
      }

      final dynamic val = event.snapshot.value;
      if (val is! Map) return <GroupSessionParticipantModel>[];

      final List<GroupSessionParticipantModel> participants = [];
      val.forEach((key, data) {
        if (data is Map) {
          final participant = GroupSessionParticipantModel.fromMap(data, key.toString());
          if (participant.isSharing) {
            participants.add(participant);
          }
        }
      });

      return participants;
    });
  }

  Future<void> joinGroupLocationSession({
    required String groupId,
    required String uid,
    required String displayName,
    required int avatarPresetIndex,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final participant = GroupSessionParticipantModel(
      uid: uid,
      displayName: displayName,
      avatarPresetIndex: avatarPresetIndex,
      isSharing: true,
      joinedAt: now,
    );

    await _groupSessionParticipantsRef
        .child(groupId)
        .child(uid)
        .set(participant.toMap());
  }

  Future<void> leaveGroupLocationSession({
    required String groupId,
    required String uid,
  }) async {
    final updates = <String, dynamic>{
      '${AppConstants.groupSessionParticipantsPath}/$groupId/$uid': null,
      '${AppConstants.groupLiveLocationsPath}/$groupId/$uid': null,
    };
    await _db.ref().update(updates);
  }

  Future<void> updateGroupLiveLocation({
    required String groupId,
    required String uid,
    required double latitude,
    required double longitude,
    double heading = 0.0,
    double speed = 0.0,
    double accuracy = 0.0,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _groupLiveLocationsRef.child(groupId).child(uid).set({
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'speed': speed,
      'accuracy': accuracy,
      'updatedAt': now,
    });
  }

  Stream<Map<String, LocationModel>> listenToGroupLiveLocations(String groupId) {
    return _groupLiveLocationsRef.child(groupId).onValue.map((event) {
      final Map<String, LocationModel> locations = {};
      if (event.snapshot.exists && event.snapshot.value is Map) {
        final data = event.snapshot.value as Map;
        data.forEach((key, val) {
          if (val is Map) {
            locations[key.toString()] = LocationModel.fromMap(val, key.toString());
          }
        });
      }
      return locations;
    });
  }

  Future<void> endGroupLocationSession({required String groupId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updates = <String, dynamic>{
      '${AppConstants.groupLocationSessionsPath}/$groupId/isActive': false,
      '${AppConstants.groupLiveLocationsPath}/$groupId': null,
      '${AppConstants.groupSessionParticipantsPath}/$groupId': null,
      '${AppConstants.groupsPath}/$groupId/updatedAt': now,
    };
    await _db.ref().update(updates);
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
  DatabaseReference get groupsRef => _groupsRef;
  DatabaseReference get groupMembersRef => _groupMembersRef;
  DatabaseReference get userGroupsRef => _userGroupsRef;
  DatabaseReference get groupMessagesRef => _groupMessagesRef;
  DatabaseReference get groupReadStateRef => _groupReadStateRef;
  DatabaseReference get groupLocationSessionsRef => _groupLocationSessionsRef;
  DatabaseReference get groupSessionParticipantsRef => _groupSessionParticipantsRef;
  DatabaseReference get groupLiveLocationsRef => _groupLiveLocationsRef;
}
