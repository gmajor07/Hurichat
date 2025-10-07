import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'package:intl/intl.dart';

class UsersListScreen extends StatelessWidget {
  final currentUser = FirebaseAuth.instance.currentUser;

  UsersListScreen({super.key});

  String generateChatId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return ids.join('_');
  }

  // Get last message for a chat
  Stream<Map<String, dynamic>?> getLastMessage(String chatId) {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return snapshot.docs.first.data();
        });
  }

  // Get unread message count
  Stream<int> getUnreadCount(String chatId, String currentUserId) {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .where('receiverId', isEqualTo: currentUserId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Center(
        child: Text('Not logged in', style: TextStyle(color: Colors.red)),
      );
    }

    final connectionsCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('connections');

    // Only accepted connections
    return StreamBuilder<QuerySnapshot>(
      stream: connectionsCollection
          .where('status', isEqualTo: 'accepted')
          .snapshots(),
      builder: (context, connSnapshot) {
        if (!connSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final acceptedIds = connSnapshot.data!.docs.map((d) => d.id).toList();

        if (acceptedIds.isEmpty) {
          return const Center(child: Text('No connections yet'));
        }

        // Fetch user data for accepted connections
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: acceptedIds)
              .snapshots(),
          builder: (context, usersSnapshot) {
            if (!usersSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final userDocs = usersSnapshot.data!.docs;

            if (userDocs.isEmpty) {
              return const Center(child: Text('No users found'));
            }

            // Build list of chats with last message
            final chatItems = <Map<String, dynamic>>[];

            for (var userDoc in userDocs) {
              final userData = userDoc.data() as Map<String, dynamic>;
              final userId = userDoc.id;
              final name = userData['name'] ?? 'No Name';
              final photoUrl = userData['photoUrl'] ?? '';
              final chatId = generateChatId(currentUser!.uid, userId);

              chatItems.add({
                'userId': userId,
                'name': name,
                'photoUrl': photoUrl,
                'chatId': chatId,
              });
            }

            // Sort by last message (optional, async handled per item)
            return ListView.builder(
              itemCount: chatItems.length,
              itemBuilder: (context, index) {
                final item = chatItems[index];
                final chatId = item['chatId'];
                final userId = item['userId'];

                return StreamBuilder<Map<String, dynamic>?>(
                  stream: getLastMessage(chatId),
                  builder: (context, msgSnapshot) {
                    final lastMessage = msgSnapshot.data?['text'] ?? '';
                    final timestamp =
                        msgSnapshot.data?['timestamp'] as Timestamp?;
                    final formattedTime = timestamp != null
                        ? DateFormat('HH:mm').format(timestamp.toDate())
                        : '';

                    return StreamBuilder<int>(
                      stream: getUnreadCount(chatId, currentUser!.uid),
                      builder: (context, unreadSnapshot) {
                        final unreadCount = unreadSnapshot.data ?? 0;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: item['photoUrl'].isNotEmpty
                                ? NetworkImage(item['photoUrl'])
                                : null,
                            backgroundColor: Colors.grey.shade400,
                            child: item['photoUrl'].isEmpty
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                          ),
                          title: Text(
                            item['name'],
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            lastMessage.isNotEmpty
                                ? lastMessage
                                : 'Tap to chat',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (formattedTime.isNotEmpty)
                                Text(
                                  formattedTime,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              if (unreadCount > 0)
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF128C7E),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ChatScreen(chatId: chatId, userId: userId),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
