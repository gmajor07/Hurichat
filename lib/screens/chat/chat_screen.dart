import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../user_account/receiver_details_screen.dart';
import 'chat_controller.dart';
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
          if (!snapshot.hasData) {
            return AppBar(
              title: const Text('Loading...'),
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 1,
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
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 1,
            shadowColor: Colors.black12,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReceiverDetailsScreen(userId: receiverId),
                  ),
                );
              },
              child: Row(
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
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isOnline
                                  ? Colors.greenAccent.shade400
                                  : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              fontSize: 12,
                              color: isOnline
                                  ? Colors.greenAccent.shade400
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp');

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F1115)
          : Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: chatRef.snapshots(),
              builder: (context, snapshot) {
                final localRaw =
                    controller.messageBox.get(widget.chatId, defaultValue: [])
                        as List;
                final localMessages = localRaw
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList();
                final firestoreDocs = snapshot.data?.docs ?? [];

                final messages = controller.mergeMessages(
                  localMessages,
                  firestoreDocs,
                );

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: controller.scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return MessageTile(
                      message: msg,
                      onLongPress: () {
                        // reuse your original action sheet logic here
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (_) {
                            return Container(
                              margin: const EdgeInsets.all(16),
                              child: SafeArea(
                                child: Material(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(
                                          leading: Icon(
                                            Icons.copy,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                          title: const Text('Copy'),
                                          onTap: () {
                                            Clipboard.setData(
                                              ClipboardData(
                                                text: msg['text'] ?? '',
                                              ),
                                            );
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Copied to clipboard',
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        if (msg['senderId'] ==
                                            FirebaseAuth
                                                .instance
                                                .currentUser
                                                ?.uid) ...[
                                          if (msg['status'] == 'failed')
                                            ListTile(
                                              leading: Icon(
                                                Icons.refresh,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.secondary,
                                              ),
                                              title: const Text('Retry'),
                                              onTap: () {
                                                Navigator.pop(context);
                                                controller.retryFailedMessage(
                                                  msg,
                                                );
                                              },
                                            ),
                                          ListTile(
                                            leading: Icon(
                                              Icons.delete,
                                              color: Colors.redAccent,
                                            ),
                                            title: const Text('Delete'),
                                            onTap: () {
                                              Navigator.pop(context);
                                              controller.deleteMessage(msg);
                                            },
                                          ),
                                        ],
                                        ListTile(
                                          leading: const Icon(
                                            Icons.cancel,
                                            color: Colors.grey,
                                          ),
                                          title: const Text('Cancel'),
                                          onTap: () => Navigator.pop(context),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          // Divider line
          const Divider(height: 1),

          // Input + Emoji picker
          SafeArea(
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
                  ChatEmojiPicker(textController: controller.messageController),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
