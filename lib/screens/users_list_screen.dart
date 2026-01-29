import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'advanced_search_bar.dart';
import 'chat/chat_screen.dart';

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
      // Remove from chat history/connections
      await firestore
          .collection('users')
          .doc(currentUser!.uid)
          .update({
            'chatHistory': FieldValue.arrayRemove([userId]),
          })
          .catchError((_) {});

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Chat removed')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to remove chat')));
      }
    }
  }

  Future<void> _blockUser(String userId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(currentUser!.uid).update({
        'blockedUsers': FieldValue.arrayUnion([userId]),
      });
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

  void _selectAll(List<String> userIds) {
    setState(() {
      _selectedUserIds.clear();
      for (var id in userIds) {
        _selectedUserIds.add(id);
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
            .update({
              'chatHistory': FieldValue.arrayRemove([userId]),
            })
            .catchError((_) {});
      }
      setState(() {
        _selectedUserIds.clear();
        _isSelectionMode = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Chats removed')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to remove chats')));
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

    return Column(
      children: [
        // 👇 Add Search Bar Here
        AdvancedSearchBar(
          hintText: "Search users to chat...",
          onSearchChanged: (value) {
            setState(() {
              searchQuery = value.toLowerCase().trim();
            });
          },
          autoFocus: false,
        ),
        // 👇 Display all users
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: searchQuery.isEmpty
                ? FirebaseFirestore.instance.collection('users').snapshots()
                : FirebaseFirestore.instance
                      .collection('users')
                      .where('name', isGreaterThanOrEqualTo: searchQuery)
                      .where('name', isLessThan: '${searchQuery}z')
                      .snapshots(),
            builder: (context, usersSnapshot) {
              if (!usersSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allUsers = usersSnapshot.data!.docs
                  .where((doc) => doc.id != currentUser!.uid)
                  .toList();

              if (allUsers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_search,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        searchQuery.isEmpty
                            ? 'No users available'
                            : 'No users found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final userIds = <String>[];
              final chatItems = <Map<String, dynamic>>[];

              for (var userDoc in allUsers) {
                final userData = userDoc.data() as Map<String, dynamic>;
                final userId = userDoc.id;
                final name = capitalize(
                  userData['name'] as String? ?? 'Unknown',
                );
                final photoUrl = userData['photoUrl'] as String? ?? '';
                final userRole = userData['role'] as String? ?? '';
                final userStatus = userData['status'] as String? ?? 'offline';
                final chatId = generateChatId(currentUser!.uid, userId);

                userIds.add(userId);
                chatItems.add({
                  'userId': userId,
                  'name': name,
                  'photoUrl': photoUrl,
                  'role': userRole,
                  'status': userStatus,
                  'chatId': chatId,
                });
              }

              return Stack(
                children: [
                  ListView.builder(
                    itemCount: chatItems.length,
                    itemBuilder: (context, index) {
                      final item = chatItems[index];
                      final userId = item['userId'] as String;
                      final chatId = item['chatId'] as String;
                      final userName = item['name'] as String;
                      final photoUrl = item['photoUrl'] as String;
                      final role = item['role'] as String;
                      final status = item['status'] as String;

                      final isOnline =
                          status == 'online' ||
                          status == 'active' ||
                          status == 'available';

                      return StreamBuilder<Map<String, dynamic>?>(
                        stream: getLastMessage(chatId),
                        builder: (context, msgSnapshot) {
                          final lastMessage =
                              msgSnapshot.data?['text'] ?? 'No messages yet';
                          final timestampData = msgSnapshot.data?['timestamp'];
                          String formattedTime = '';

                          if (timestampData != null) {
                            DateTime messageDate;
                            if (timestampData is Timestamp) {
                              messageDate = timestampData.toDate();
                            } else if (timestampData is int) {
                              messageDate = DateTime.fromMillisecondsSinceEpoch(
                                timestampData,
                              );
                            } else {
                              messageDate = DateTime.now();
                            }

                            final now = DateTime.now();
                            final difference = now.difference(messageDate);

                            if (difference.inDays == 0) {
                              formattedTime = DateFormat(
                                'HH:mm',
                              ).format(messageDate);
                            } else if (difference.inDays == 1) {
                              formattedTime = 'Yesterday';
                            } else if (difference.inDays < 7) {
                              formattedTime = '${difference.inDays}d ago';
                            } else {
                              formattedTime = DateFormat(
                                'M/d',
                              ).format(messageDate);
                            }
                          }

                          return StreamBuilder<int>(
                            stream: getUnreadCount(chatId, currentUser!.uid),
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
                                    : Stack(
                                        children: [
                                          CircleAvatar(
                                            radius: 28,
                                            backgroundImage: photoUrl.isNotEmpty
                                                ? NetworkImage(photoUrl)
                                                : null,
                                            backgroundColor:
                                                Colors.grey.shade400,
                                            child: photoUrl.isEmpty
                                                ? const Icon(
                                                    Icons.person,
                                                    color: Colors.white,
                                                  )
                                                : null,
                                          ),
                                          if (isOnline)
                                            Positioned(
                                              bottom: 0,
                                              right: 0,
                                              child: Container(
                                                width: 12,
                                                height: 12,
                                                decoration: BoxDecoration(
                                                  color: Colors.green,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                title: Text(
                                  userName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (role.isNotEmpty)
                                      Text(
                                        role,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    Text(
                                      lastMessage,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: _isSelectionMode
                                    ? null
                                    : Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            formattedTime,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                          if (unreadCount > 0) ...[
                                            const SizedBox(height: 4),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                unreadCount.toString(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                onTap: _isSelectionMode
                                    ? () => _toggleSelection(userId)
                                    : () async {
                                        await markMessagesAsRead(
                                          chatId,
                                          currentUser!.uid,
                                        );
                                        if (!mounted) return;
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
                                          backgroundColor: Colors.transparent,
                                          builder: (_) {
                                            return Container(
                                              margin: const EdgeInsets.all(16),
                                              child: SafeArea(
                                                child: Material(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
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
                                                          leading: Icon(
                                                            Icons.check_box,
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .primary,
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
                                                            _blockUser(userId);
                                                          },
                                                        ),
                                                        ListTile(
                                                          leading: const Icon(
                                                            Icons.delete,
                                                            color: Colors
                                                                .redAccent,
                                                          ),
                                                          title: const Text(
                                                            'Remove Chat',
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
                              onPressed: () => _selectAll(userIds),
                              icon: const Icon(Icons.select_all),
                              label: const Text('Select All'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
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
                              label: const Text('Remove Selected'),
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
          ),
        ),
      ],
    );
  }
}
