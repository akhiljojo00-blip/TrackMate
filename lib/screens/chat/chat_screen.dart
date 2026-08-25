import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/message_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/full_screen_image_viewer.dart';
import '../../widgets/connectivity_banner.dart';
import '../map/map_screen.dart';

class ChatScreen extends StatefulWidget {
  final String peerUid;
  final String peerName;
  final String peerUsername;

  const ChatScreen({
    super.key,
    required this.peerUid,
    required this.peerName,
    required this.peerUsername,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUid = context.read<AuthProvider>().user?.uid;
      if (currentUid != null) {
        context.read<ChatProvider>().openChat(
              currentUid: currentUid,
              peerUid: widget.peerUid,
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
    if (text.isEmpty) return;

    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    final currentUid = authProvider.user?.uid;
    final currentName = authProvider.userModel?.name ?? 'User';

    if (currentUid == null) return;

    _messageController.clear();
    final success = await chatProvider.sendTextMessage(
      currentUid: currentUid,
      currentName: currentName,
      text: text,
    );

    if (success) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _showMediaPickerSheet(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    final currentUid = authProvider.user?.uid;
    final currentName = authProvider.userModel?.name ?? 'User';

    if (currentUid == null || chatProvider.isUploadingImage || chatProvider.isAcquiringLocation) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Share to Chat',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                ),
                title: const Text('Take Photo'),
                subtitle: const Text('Capture using device camera'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  chatProvider.sendImageMessage(
                    currentUid: currentUid,
                    currentName: currentName,
                    source: ImageSource.camera,
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                ),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Select a picture from photos'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  chatProvider.sendImageMessage(
                    currentUid: currentUid,
                    currentName: currentName,
                    source: ImageSource.gallery,
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE91E63).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on_rounded, color: Color(0xFFE91E63)),
                ),
                title: const Text('Share Current Location'),
                subtitle: const Text('Send a one-time GPS snapshot'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  chatProvider.sendLocationMessage(
                    currentUid: currentUid,
                    currentName: currentName,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final currentUid = authProvider.user?.uid ?? '';
    final messages = chatProvider.messages;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (messages.isNotEmpty) {
        _scrollToBottom();
      }
    });

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          context.read<ChatProvider>().closeChat();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary,
                child: Text(
                  widget.peerName.isNotEmpty ? widget.peerName[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.peerName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '@${widget.peerUsername}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            const ConnectivityBanner(),
            if (chatProvider.chatError != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: AppColors.error.withValues(alpha: 0.1),
                child: Text(
                  chatProvider.chatError!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: AppColors.textSecondary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No messages yet with ${widget.peerName}',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Say hello to start the conversation!',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == currentUid;

                        return _MessageBubble(
                          message: message,
                          isMe: isMe,
                        );
                      },
                    ),
            ),
            _buildInputBar(chatProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(ChatProvider chatProvider) {
    final bool isBusy = chatProvider.isSending || chatProvider.isUploadingImage || chatProvider.isAcquiringLocation;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Uploading progress banner
            if (chatProvider.isUploadingImage)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0, left: 4.0, right: 4.0),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        chatProvider.uploadProgress > 0
                            ? 'Uploading photo ${(chatProvider.uploadProgress * 100).toInt()}%...'
                            : 'Preparing photo...',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondaryColor(context)),
                      ),
                    ),
                  ],
                ),
              ),

            // Location acquisition banner
            if (chatProvider.isAcquiringLocation)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0, left: 4.0, right: 4.0),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFE91E63),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Acquiring current GPS location...',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondaryColor(context)),
                      ),
                    ),
                  ],
                ),
              ),

            Row(
              children: [
                // Media / Location attachment button
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 26),
                  tooltip: 'Share photo or location',
                  onPressed: isBusy ? null : () => _showMediaPickerSheet(context),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(color: AppColors.textPrimaryColor(context)),
                    maxLines: 4,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
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
                    icon: isBusy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white),
                    onPressed: isBusy ? null : _handleSendMessage,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _MessageBubble({
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
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
        padding: (message.isImage || message.isLocation)
            ? const EdgeInsets.all(6)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            // Image Attachment
            if (message.isImage)
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FullScreenImageViewer(
                        imageUrl: message.imageUrl!,
                        senderName: message.senderName,
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Hero(
                    tag: message.imageUrl!,
                    child: Image.network(
                      message.imageUrl!,
                      width: 240,
                      height: 200,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 240,
                          height: 200,
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.grey.shade200,
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 240,
                          height: 140,
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey.shade300,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image_rounded, size: 36, color: Colors.grey),
                              SizedBox(height: 4),
                              Text(
                                'Unable to load photo',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

            // Location Snapshot Card
            if (message.isLocation)
              Container(
                width: 230,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isMe ? Colors.white.withValues(alpha: 0.15) : AppColors.backgroundColor(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE91E63).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFFE91E63),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Shared Location',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isMe ? Colors.white : AppColors.textPrimaryColor(context),
                                ),
                              ),
                              Text(
                                'One-time GPS snapshot',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isMe ? Colors.white70 : AppColors.textSecondaryColor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isMe ? Colors.white : AppColors.primary,
                          foregroundColor: isMe ? AppColors.primary : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.map_rounded, size: 14),
                        label: const Text(
                          'VIEW ON MAP',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MapScreen(
                                initialFocusLocation: LatLng(message.latitude!, message.longitude!),
                                focusLabel: '${message.senderName}\'s Location',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

            // Caption Text (if text is not empty and not the default location label)
            if (message.text.isNotEmpty && !message.isLocation) ...[
              Padding(
                padding: message.isImage
                    ? const EdgeInsets.only(top: 6, left: 6, right: 6)
                    : EdgeInsets.zero,
                child: Text(
                  message.text,
                  style: TextStyle(
                    color: isMe ? Colors.white : AppColors.textPrimaryColor(context),
                    fontSize: 15,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Padding(
              padding: (message.isImage || message.isLocation)
                  ? const EdgeInsets.only(right: 6, bottom: 2)
                  : EdgeInsets.zero,
              child: Text(
                timeStr,
                style: TextStyle(
                  color: isMe ? Colors.white.withValues(alpha: 0.7) : AppColors.textSecondaryColor(context),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
