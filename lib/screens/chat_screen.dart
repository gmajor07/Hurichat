import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final String chatId; // e.g., "uid1_uid2"
  final String userId; // current user uid

  const ChatScreen({super.key, required this.chatId, required this.userId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  late final User user;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser!;
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    if (widget.chatId.isEmpty) return; // prevent errors

    final message = {
      'senderId': user.uid,
      'text': _controller.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add(message);

    // Update last message
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).set(
      {
        'lastMessage': _controller.text.trim(),
        'lastTimestamp': FieldValue.serverTimestamp(),
        'members': [user.uid], // add other uid(s) if needed
      },
      SetOptions(merge: true),
    );

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Expanded(
          child: widget.chatId.isEmpty
              ? Center(child: Text("No chat selected"))
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(widget.chatId)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs;
                    return ListView.builder(
                      reverse: true,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final isMe = data['senderId'] == user.uid;
                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 8,
                            ),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? (isDark
                                        ? Colors.green[700]
                                        : Colors.green[300])
                                  : (isDark
                                        ? Colors.grey[700]
                                        : Colors.grey[300]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              data['text'],
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: "Type a message...",
                    border: const OutlineInputBorder(),
                    fillColor: isDark ? Colors.grey[800] : Colors.white,
                    filled: true,
                  ),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _sendMessage,
                color: isDark ? Colors.green[200] : Colors.green[700],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
