import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String userId;

  const ChatScreen({super.key, required this.chatId, required this.userId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final user = FirebaseAuth.instance.currentUser!;

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final message = {
      'senderId': user.uid,
      'text': _controller.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    };

    final chatDoc = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId);

    await chatDoc.collection('messages').add(message);

    await chatDoc.set({
      'lastMessage': _controller.text.trim(),
      'lastTimestamp': FieldValue.serverTimestamp(),
      'members': [user.uid, widget.userId],
    }, SetOptions(merge: true));

    _controller.clear();
  }

  String getChatId(String uid1, String uid2) {
    // Always sort the UIDs alphabetically to get the same chatId for both users
    List<String> uids = [uid1, uid2];
    uids.sort();
    return uids.join('_'); // Example: "uidA_uidB"
  }

  void openChat(BuildContext context, String otherUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final chatId = getChatId(currentUser.uid, otherUserId);

    final chatDoc = FirebaseFirestore.instance.collection('chats').doc(chatId);

    // Create chat document if it doesn't exist
    final docSnapshot = await chatDoc.get();
    if (!docSnapshot.exists) {
      await chatDoc.set({
        'members': [currentUser.uid, otherUserId],
        'lastMessage': '',
        'lastTimestamp': FieldValue.serverTimestamp(),
      });
    }

    // Navigate to chat screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(chatId: chatId, userId: currentUser.uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text("Chat")),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == widget.userId;
                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.green[300] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(data['text']),
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
                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
