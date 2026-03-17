import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../user_account/receiver_details_screen.dart';
import 'chat_controller.dart';
import 'chat_theme.dart';
import 'chat_widgets.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String userId;

  const ChatScreen({super.key, required this.chatId, required this.userId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ChatController controller;
  bool _showEmojiPicker = false;

  @override
  void initState() {
    super.initState();
    controller = ChatController(
      chatId: widget.chatId,
      userId: widget.userId,
      context: context,
    );
    controller.init();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  PreferredSizeWidget _buildAppBar() {
    final receiverId = controller.receiverData?['uid'] ?? widget.userId;

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(receiverId)
            .snapshots(),
        builder: (context, snapshot) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          if (!snapshot.hasData) {
            return AppBar(
              backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              title: Text(
                'Loading...',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 16,
                ),
              ),
            );
          }

          final receiverData =
              snapshot.data!.data() as Map<String, dynamic>? ?? {};

          final nameRaw = (receiverData['name'] ?? 'Unknown') as String;
          final name = nameRaw.isNotEmpty
              ? nameRaw[0].toUpperCase() + nameRaw.substring(1)
              : nameRaw;

          final photo = (receiverData['photoUrl'] ?? '') as String;
          final status = (receiverData['status'] ?? 'offline')
              .toString()
              .toLowerCase();

          final isOnline =
              status == 'online' || status == 'active' || status == 'available';

          return AppBar(
            backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            systemOverlayStyle: isDark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: isDark ? Colors.white : Colors.black87,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ReceiverDetailsScreen(userId: receiverId),
                ),
              ),
              child: Row(
                children: [
                  // Avatar with online dot
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: photo.isNotEmpty
                            ? NetworkImage(photo)
                            : null,
                        backgroundColor: Colors.grey.shade300,
                        child: photo.isEmpty
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      if (isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF1A1A2E)
                                    : Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isOnline
                              ? const Color(0xFF4CAF50)
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.videocam_outlined),
                color: ChatTheme.primary,
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.call_outlined),
                color: ChatTheme.primary,
                onPressed: () {},
              ),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.grey.shade200,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final chatRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp');

    return Scaffold(
      backgroundColor: ChatTheme.getBackground(context),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: chatRef.snapshots(),
              builder: (context, snapshot) {
                final localRaw = controller.messageBox
                    .get(widget.chatId, defaultValue: []) as List;
                final localMessages = localRaw
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList();
                final firestoreDocs = snapshot.data?.docs ?? [];

                final messages =
                    controller.mergeMessages(localMessages, firestoreDocs);

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: ChatTheme.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 44,
                            color: ChatTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Say hello! 👋',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? Colors.grey.shade600
                                : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: controller.scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return MessageTile(
                      message: msg,
                      senderPhotoUrl:
                          FirebaseAuth.instance.currentUser?.photoURL,
                      receiverPhotoUrl:
                          controller.receiverData?['photoUrl'] as String?,
                      onLongPress: () {
                        _showMessageOptions(context, msg);
                      },
                    );
                  },
                );
              },
            ),
          ),

          // Input area
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChatInputBar(
                    controller: controller,
                    showEmojiPicker: _showEmojiPicker,
                    onToggleEmoji: () =>
                        setState(() => _showEmojiPicker = !_showEmojiPicker),
                    onSendPressed: controller.onSendPressed,
                  ),
                  if (_showEmojiPicker)
                    ChatEmojiPicker(
                        textController: controller.messageController),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(BuildContext context, Map<String, dynamic> msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white24
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                _SheetOption(
                  icon: Icons.copy_rounded,
                  label: 'Copy',
                  color: ChatTheme.primary,
                  isDark: isDark,
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: msg['text'] ?? ''));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        backgroundColor: ChatTheme.primaryDark,
                      ),
                    );
                  },
                ),
                if (msg['senderId'] ==
                    FirebaseAuth.instance.currentUser?.uid) ...[
                  if (msg['status'] == 'failed')
                    _SheetOption(
                      icon: Icons.refresh_rounded,
                      label: 'Retry',
                      color: Colors.orange.shade400,
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(context);
                        controller.retryFailedMessage(msg);
                      },
                    ),
                  _SheetOption(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    color: Colors.red.shade400,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      controller.deleteMessage(msg);
                    },
                  ),
                ],
                _SheetOption(
                  icon: Icons.close_rounded,
                  label: 'Cancel',
                  color: Colors.grey.shade500,
                  isDark: isDark,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ─── Reusable bottom-sheet option row ─────────────────────────────────────
class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 15,
          color: isDark ? Colors.white.withValues(alpha: 0.87) : Colors.black87,
        ),
      ),
      onTap: onTap,
    );
  }
}
