import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/avatar_presets.dart';
import '../../models/group_location_session_model.dart';
import '../../models/group_member_model.dart';
import '../../models/group_model.dart';
import '../../models/group_session_participant_model.dart';
import '../../models/message_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../map/group_map_screen.dart';
import 'group_info_screen.dart';

class GroupChatScreen extends StatefulWidget {
  final GroupModel group;

  const GroupChatScreen({
    super.key,
    required this.group,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DatabaseService _databaseService = DatabaseService();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUid = context.read<AuthProvider>().user?.uid;
      if (currentUid != null) {
        _databaseService.markGroupAsRead(
          groupId: widget.group.id,
          uid: currentUid,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    if (text.length > 2000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message cannot exceed 2,000 characters.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final currentUid = authProvider.user?.uid;
    final currentName = authProvider.userModel?.name ?? 'User';

    if (currentUid == null) return;

    _messageController.clear();
    setState(() => _isSending = true);

    try {
      final message = MessageModel(
        id: '',
        senderId: currentUid,
        senderName: currentName,
        text: text,
        type: 'text',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      await _databaseService.sendGroupTextMessage(
        groupId: widget.group.id,
        message: message,
      );

      await _databaseService.markGroupAsRead(
        groupId: widget.group.id,
        uid: currentUid,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showStartSessionSheet(BuildContext context) {
    final titleController = TextEditingController(text: '${widget.group.name} Live Track');
    final authProvider = context.read<AuthProvider>();
    final currentUid = authProvider.user?.uid;
    final currentName = authProvider.userModel?.name ?? 'User';
    final avatarIndex = authProvider.userModel?.avatarPresetIndex ?? 0;

    if (currentUid == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.radar_rounded, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Start Live Location Session',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Session Title',
                  hintText: 'e.g. Roadtrip, Hike, Meetup',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Opt-in only: Group members will only appear on the map if they explicitly choose to share.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start Session & Share', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final String sessionId = await _databaseService.startGroupLocationSession(
                    groupId: widget.group.id,
                    creatorUid: currentUid,
                    creatorName: currentName,
                    avatarPresetIndex: avatarIndex,
                    title: titleController.text.trim(),
                  );

                  if (context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GroupMapScreen(
                          group: widget.group,
                          initialSession: GroupLocationSessionModel(
                            sessionId: sessionId,
                            groupId: widget.group.id,
                            createdBy: currentUid,
                            createdAt: DateTime.now().millisecondsSinceEpoch,
                            title: titleController.text.trim(),
                            isActive: true,
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSessionManagementSheet(
    BuildContext context,
    GroupLocationSessionModel session,
    List<GroupSessionParticipantModel> participants,
    bool isCreator,
    bool isOwner,
    bool isAdmin,
    String currentUid,
  ) {
    final authProvider = context.read<AuthProvider>();
    final bool isCurrentUserSharing = participants.any((p) => p.uid == currentUid);
    final bool canEndSession = isCreator || isOwner || isAdmin;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                session.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${participants.length} member(s) currently sharing location',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              // View Live Map Action
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.map_rounded),
                label: const Text('View Live Group Map', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GroupMapScreen(
                        group: widget.group,
                        initialSession: session,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              // Share / Stop Sharing My Location
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isCurrentUserSharing ? AppColors.error : AppColors.primary,
                  side: BorderSide(color: isCurrentUserSharing ? AppColors.error : AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(isCurrentUserSharing ? Icons.location_off_rounded : Icons.location_on_rounded),
                label: Text(
                  isCurrentUserSharing ? 'Stop Sharing My Location' : 'Share My Location',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  if (isCurrentUserSharing) {
                    await _databaseService.leaveGroupLocationSession(
                      groupId: widget.group.id,
                      uid: currentUid,
                    );
                  } else {
                    await _databaseService.joinGroupLocationSession(
                      groupId: widget.group.id,
                      uid: currentUid,
                      displayName: authProvider.userModel?.name ?? 'User',
                      avatarPresetIndex: authProvider.userModel?.avatarPresetIndex ?? 0,
                    );
                  }
                },
              ),

              if (canEndSession) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: const Text('End Session for All', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _databaseService.endGroupLocationSession(groupId: widget.group.id);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUid = authProvider.user?.uid ?? '';
    final preset = AvatarPresets.getPreset(widget.group.avatarPresetIndex);

    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<GroupModel?>(
          stream: _databaseService.getGroupStream(widget.group.id),
          initialData: widget.group,
          builder: (context, snapshot) {
            final group = snapshot.data ?? widget.group;
            return Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: preset.gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Icon(preset.icon, size: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${group.memberCount} members',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          // Live Location Session Action Icon
          StreamBuilder<GroupLocationSessionModel?>(
            stream: _databaseService.listenToActiveGroupSession(widget.group.id),
            builder: (context, sessionSnapshot) {
              final session = sessionSnapshot.data;
              final bool isSessionActive = session != null && session.isActive;

              return StreamBuilder<List<GroupMemberModel>>(
                stream: _databaseService.listenToGroupMembers(widget.group.id),
                builder: (context, memberSnapshot) {
                  final members = memberSnapshot.data ?? [];
                  final currentMember = members.firstWhere(
                    (m) => m.uid == currentUid,
                    orElse: () => GroupMemberModel(uid: currentUid, role: 'member', joinedAt: 0),
                  );

                  return StreamBuilder<List<GroupSessionParticipantModel>>(
                    stream: _databaseService.listenToGroupSessionParticipants(widget.group.id),
                    builder: (context, participantSnapshot) {
                      final participants = participantSnapshot.data ?? [];

                      return IconButton(
                        icon: Badge(
                          isLabelVisible: isSessionActive,
                          backgroundColor: AppColors.success,
                          smallSize: 8,
                          child: Icon(
                            isSessionActive ? Icons.radar_rounded : Icons.location_on_outlined,
                            color: isSessionActive ? AppColors.primary : null,
                          ),
                        ),
                        tooltip: isSessionActive ? 'Manage Location Session' : 'Start Location Session',
                        onPressed: () {
                          if (isSessionActive) {
                            _showSessionManagementSheet(
                              context,
                              session,
                              participants,
                              session.createdBy == currentUid,
                              currentMember.isOwner,
                              currentMember.isAdmin,
                              currentUid,
                            );
                          } else {
                            _showStartSessionSheet(context);
                          }
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Group Details',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GroupInfoScreen(group: widget.group),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<GroupMemberModel>>(
        stream: _databaseService.listenToGroupMembers(widget.group.id),
        builder: (context, memberSnapshot) {
          final members = memberSnapshot.data ?? [];
          final bool isLoaded = memberSnapshot.hasData;
          final bool isMember = !isLoaded || members.any((m) => m.uid == currentUid);

          return Column(
            children: [
              // Notice banner if removed from group
              if (isLoaded && !isMember)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: AppColors.error.withValues(alpha: 0.1),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.error, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You are no longer a member of this group.',
                          style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

              // Active Live Location Session Pinned Banner
              StreamBuilder<GroupLocationSessionModel?>(
                stream: _databaseService.listenToActiveGroupSession(widget.group.id),
                builder: (context, sessionSnapshot) {
                  final session = sessionSnapshot.data;
                  if (session == null || !session.isActive) {
                    return const SizedBox.shrink();
                  }

                  return StreamBuilder<List<GroupSessionParticipantModel>>(
                    stream: _databaseService.listenToGroupSessionParticipants(widget.group.id),
                    builder: (context, participantsSnapshot) {
                      final participants = participantsSnapshot.data ?? [];
                      final bool isCurrentUserSharing = participants.any((p) => p.uid == currentUid);

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.cardColor(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.radar_rounded, color: AppColors.primary, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Live Location: ${session.title}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${participants.length} member(s) sharing live GPS',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                if (isCurrentUserSharing)
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.error,
                                        side: const BorderSide(color: AppColors.error),
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () async {
                                        await _databaseService.leaveGroupLocationSession(
                                          groupId: widget.group.id,
                                          uid: currentUid,
                                        );
                                      },
                                      child: const Text('Stop Sharing', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  )
                                else
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.success,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () async {
                                        await _databaseService.joinGroupLocationSession(
                                          groupId: widget.group.id,
                                          uid: currentUid,
                                          displayName: authProvider.userModel?.name ?? 'User',
                                          avatarPresetIndex: authProvider.userModel?.avatarPresetIndex ?? 0,
                                        );
                                      },
                                      child: const Text('Share Location', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.map_rounded, size: 14),
                                    label: const Text('View Map', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => GroupMapScreen(
                                            group: widget.group,
                                            initialSession: session,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),

              // Messages List
              Expanded(
                child: StreamBuilder<List<MessageModel>>(
                  stream: _databaseService.listenToGroupMessages(widget.group.id),
                  builder: (context, snapshot) {
                    final messages = snapshot.data ?? [];

                    if (messages.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _scrollToBottom();
                        if (currentUid.isNotEmpty) {
                          _databaseService.markGroupAsRead(
                            groupId: widget.group.id,
                            uid: currentUid,
                          );
                        }
                      });
                    }

                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.groups_rounded,
                              size: 64,
                              color: AppColors.textSecondary.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Welcome to ${widget.group.name}!',
                              style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Say something to start the conversation.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == currentUid;

                        final timeStr = DateFormat('hh:mm a').format(
                          DateTime.fromMillisecondsSinceEpoch(message.timestamp),
                        );

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: isMe ? AppColors.primary : AppColors.cardColor(context),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isMe ? 16 : 4),
                                bottomRight: Radius.circular(isMe ? 4 : 16),
                              ),
                              border: isMe ? null : Border.all(color: AppColors.cardBorderColor(context)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                if (!isMe) ...[
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 8,
                                        backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                                        child: Text(
                                          message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : 'U',
                                          style: const TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        message.senderName,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                ],
                                Text(
                                  message.text,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : AppColors.textPrimaryColor(context),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    color: isMe ? Colors.white.withValues(alpha: 0.7) : AppColors.textSecondaryColor(context),
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Composer Input Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.cardColor(context),
                  border: Border(top: BorderSide(color: AppColors.cardBorderColor(context))),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      offset: const Offset(0, -1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: SafeArea(
                  child: isMember
                      ? Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                textCapitalization: TextCapitalization.sentences,
                                style: TextStyle(color: AppColors.textPrimaryColor(context)),
                                maxLines: 4,
                                minLines: 1,
                                maxLength: 2000,
                                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                decoration: InputDecoration(
                                  hintText: 'Message group...',
                                  hintStyle: TextStyle(color: AppColors.textSecondaryColor(context)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide(color: AppColors.cardBorderColor(context)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide(color: AppColors.cardBorderColor(context)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                  ),
                                  filled: true,
                                  fillColor: AppColors.inputFillColor(context),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                                onSubmitted: (_) => _handleSendMessage(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Material(
                              color: AppColors.primary,
                              shape: const CircleBorder(),
                              child: IconButton(
                                icon: _isSending
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                                onPressed: _isSending ? null : _handleSendMessage,
                              ),
                            ),
                          ],
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          child: const Text(
                            'You cannot send messages to this group.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
