import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'advanced_search_bar.dart';
import 'chat/chat_screen.dart';
import 'package:intl/intl.dart';
import 'connection/discovery_connection_screen.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  String searchQuery = '';
  bool _isSelectionMode = false;
  final Set<String> _selectedUserIds = {};

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

  Future<void> _deleteConnection(String userId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('connections')
          .doc(userId)
          .delete();
      await firestore
          .collection('users')
          .doc(userId)
          .collection('connections')
          .doc(currentUser!.uid)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Connection deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete connection')),
        );
      }
    }
  }

  Future<void> _blockUser(String userId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('connections')
          .doc(userId)
          .set({'status': 'blocked', 'userId': userId});
      await firestore
          .collection('users')
          .doc(userId)
          .collection('connections')
          .doc(currentUser!.uid)
          .set({'status': 'blocked', 'userId': currentUser!.uid});
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User blocked')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to block user')));
      }
    }
  }

  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedUserIds.clear();
    });
  }

  void _toggleSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  void _selectAll(List<Map<String, dynamic>> chatItems) {
    setState(() {
      _selectedUserIds.clear();
      for (var item in chatItems) {
        _selectedUserIds.add(item['userId']);
      }
    });
  }

  Future<void> _deleteSelectedConnections() async {
    try {
      final firestore = FirebaseFirestore.instance;
      for (var userId in _selectedUserIds) {
        await firestore
            .collection('users')
            .doc(currentUser!.uid)
            .collection('connections')
            .doc(userId)
            .delete();
        await firestore
            .collection('users')
            .doc(userId)
            .collection('connections')
            .doc(currentUser!.uid)
            .delete();
      }
      setState(() {
        _selectedUserIds.clear();
        _isSelectionMode = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected connections deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete connections')),
        );
      }
    }
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
        // In UsersListScreen build method:
        AdvancedSearchBar(
          hintText: "Search connections || Enter name",
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
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No connections yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start connecting with people to chat!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ConnectionsDiscoveryScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.search),
                        label: const Text('Discover Connections'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAFAB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
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

                  return Stack(
                    children: [
                      ListView.builder(
                        itemCount: chatItems.length,
                        itemBuilder: (context, index) {
                          final item = chatItems[index];
                          final chatId = item['chatId'];
                          final userId = item['userId'];

                          return StreamBuilder<Map<String, dynamic>?>(
                            stream: getLastMessage(chatId),
                            builder: (context, msgSnapshot) {
                              final lastMessage =
                                  msgSnapshot.data?['text'] ?? '';
                              final timestamp =
                                  msgSnapshot.data?['timestamp'] as Timestamp?;
                              final formattedTime = timestamp != null
                                  ? DateFormat(
                                      'HH:mm',
                                    ).format(timestamp.toDate())
                                  : '';

                              return StreamBuilder<int>(
                                stream: getUnreadCount(
                                  chatId,
                                  currentUser!.uid,
                                ),
                                builder: (context, unreadSnapshot) {
                                  final unreadCount = unreadSnapshot.data ?? 0;

                                  return ListTile(
                                    leading: _isSelectionMode
                                        ? Checkbox(
                                            value: _selectedUserIds.contains(
                                              userId,
                                            ),
                                            onChanged: (bool? value) {
                                              _toggleSelection(userId);
                                            },
                                          )
                                        : CircleAvatar(
                                            backgroundImage:
                                                item['photoUrl'].isNotEmpty
                                                ? NetworkImage(item['photoUrl'])
                                                : null,
                                            backgroundColor:
                                                Colors.grey.shade400,
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
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    trailing: _isSelectionMode
                                        ? null
                                        : Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
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
                                                  padding: const EdgeInsets.all(
                                                    6,
                                                  ),
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Color(
                                                          0xFF128C7E,
                                                        ),
                                                        shape: BoxShape.circle,
                                                      ),
                                                  child: Text(
                                                    unreadCount.toString(),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                    onTap: _isSelectionMode
                                        ? () => _toggleSelection(userId)
                                        : () async {
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
                                    onLongPress: _isSelectionMode
                                        ? null
                                        : () {
                                            showModalBottomSheet(
                                              context: context,
                                              backgroundColor:
                                                  Colors.transparent,
                                              builder: (_) {
                                                return Container(
                                                  margin: const EdgeInsets.all(
                                                    16,
                                                  ),
                                                  child: SafeArea(
                                                    child: Material(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 8,
                                                            ),
                                                        child: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            ListTile(
                                                              leading: const Icon(
                                                                Icons.check_box,
                                                                color:
                                                                    Colors.blue,
                                                              ),
                                                              title: const Text(
                                                                'Select',
                                                              ),
                                                              onTap: () {
                                                                Navigator.pop(
                                                                  context,
                                                                );
                                                                _enterSelectionMode();
                                                                _toggleSelection(
                                                                  userId,
                                                                );
                                                              },
                                                            ),
                                                            ListTile(
                                                              leading: const Icon(
                                                                Icons.block,
                                                                color: Colors
                                                                    .redAccent,
                                                              ),
                                                              title: const Text(
                                                                'Block User',
                                                              ),
                                                              onTap: () {
                                                                Navigator.pop(
                                                                  context,
                                                                );
                                                                _blockUser(
                                                                  userId,
                                                                );
                                                              },
                                                            ),
                                                            ListTile(
                                                              leading: const Icon(
                                                                Icons.delete,
                                                                color: Colors
                                                                    .redAccent,
                                                              ),
                                                              title: const Text(
                                                                'Delete Connection',
                                                              ),
                                                              onTap: () {
                                                                Navigator.pop(
                                                                  context,
                                                                );
                                                                _deleteConnection(
                                                                  userId,
                                                                );
                                                              },
                                                            ),
                                                            ListTile(
                                                              leading: Icon(
                                                                Icons.cancel,
                                                                color: Colors
                                                                    .grey
                                                                    .shade600,
                                                              ),
                                                              title: const Text(
                                                                'Cancel',
                                                              ),
                                                              onTap: () =>
                                                                  Navigator.pop(
                                                                    context,
                                                                  ),
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
                          );
                        },
                      ),
                      if (_isSelectionMode)
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _selectAll(chatItems),
                                  icon: const Icon(Icons.select_all),
                                  label: const Text('Select All'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _selectedUserIds.isEmpty
                                      ? null
                                      : _deleteSelectedConnections,
                                  icon: const Icon(Icons.delete),
                                  label: const Text('Delete Selected'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                onPressed: _exitSelectionMode,
                                icon: const Icon(Icons.cancel),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.grey,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
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
