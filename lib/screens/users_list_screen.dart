import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'advanced_search_bar.dart';
import 'chat/chat_screen.dart';
import 'package:intl/intl.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  String searchQuery = '';

  String generateChatId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return ids.join('_');
  }

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

  String capitalize(String name) {
    if (name.isEmpty) return name;
    return name[0].toUpperCase() + name.substring(1);
  }

  Future<void> markMessagesAsRead(String chatId, String currentUserId) async {
    final unreadSnapshot = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .where('receiverId', isEqualTo: currentUserId)
        .get();

    for (var doc in unreadSnapshot.docs) {
      doc.reference.update({'isRead': true});
    }
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

    return Column(
      children: [
        // 👇 Add Search Bar Here
        // In your UsersListScreen build method:
        AdvancedSearchBar(
          hintText: "Search connections...",
          onSearchChanged: (value) {
            setState(() {
              searchQuery = value.toLowerCase().trim();
            });
          },
          autoFocus: false,
        ),
        // 👇 The rest of your existing logic wrapped in Expanded
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: connectionsCollection
                .where('status', isEqualTo: 'accepted')
                .snapshots(),
            builder: (context, connSnapshot) {
              if (!connSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final acceptedIds = connSnapshot.data!.docs
                  .map((d) => d.id)
                  .toList();

              if (acceptedIds.isEmpty) {
                return const Center(child: Text('No connections yet'));
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where(FieldPath.documentId, whereIn: acceptedIds)
                    .snapshots(),
                builder: (context, usersSnapshot) {
                  if (!usersSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var userDocs = usersSnapshot.data!.docs;
                  if (userDocs.isEmpty) {
                    return const Center(child: Text('No one found'));
                  }

                  // Filter by search query
                  userDocs = userDocs.where((userDoc) {
                    final userData =
                        userDoc.data() as Map<String, dynamic>? ?? {};
                    final name = (userData['name'] ?? '')
                        .toString()
                        .toLowerCase();
                    return name.contains(searchQuery);
                  }).toList();

                  if (userDocs.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No matches found',
                            style: TextStyle(color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Try a different search term',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }

                  final chatItems = <Map<String, dynamic>>[];

                  for (var userDoc in userDocs) {
                    final userData = userDoc.data() as Map<String, dynamic>;
                    final userId = userDoc.id;
                    final name = capitalize(userData['name'] ?? 'No Name');
                    final photoUrl = userData['photoUrl'] ?? '';
                    final chatId = generateChatId(currentUser!.uid, userId);

                    chatItems.add({
                      'userId': userId,
                      'name': name,
                      'photoUrl': photoUrl,
                      'chatId': chatId,
                    });
                  }

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
                                      ? const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                title: Text(
                                  item['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
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
                                onTap: () async {
                                  await markMessagesAsRead(
                                    chatId,
                                    currentUser!.uid,
                                  );

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        chatId: chatId,
                                        userId: userId,
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
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
