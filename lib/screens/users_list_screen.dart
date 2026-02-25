import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'chat/chat_screen.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  bool _isSelectionMode = false;
  final Set<String> _selectedUserIds = {};

  String generateChatId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return ids.join('_');
  }

  int _extractTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) return timestamp.millisecondsSinceEpoch;
    if (timestamp is int) return timestamp;
    return 0;
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
          .update({
            'chatHistory': FieldValue.arrayRemove([userId]),
          })
          .catchError((_) {});

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Chat removed')));
      }
    } catch (_) {
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to block user')));
      }
    }
  }

  Future<void> _togglePinnedChat(String userId, bool isPinned) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(currentUser!.uid).update({
        'pinnedChats': isPinned
            ? FieldValue.arrayRemove([userId])
            : FieldValue.arrayUnion([userId]),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isPinned ? 'Chat unpinned' : 'Chat pinned')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to update pin')));
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
      _selectedUserIds
        ..clear()
        ..addAll(userIds);
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
    } catch (_) {
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

  String _formatTime(int timestampMs) {
    if (timestampMs <= 0) return '';

    final messageDate = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final now = DateTime.now();
    final difference = now.difference(messageDate);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(messageDate);
    }
    if (difference.inDays == 1) {
      return 'Yesterday';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }
    return DateFormat('M/d').format(messageDate);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Center(
        child: Text('Not logged in', style: TextStyle(color: Colors.red)),
      );
    }
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF242424) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 18, color: Colors.grey.shade500),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value.toLowerCase().trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search here',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              Icon(Icons.mic_none, size: 18, color: Colors.grey.shade500),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, usersSnapshot) {
              if (!usersSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .where('members', arrayContains: currentUser!.uid)
                    .snapshots(),
                builder: (context, chatsSnapshot) {
                  if (!chatsSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final chatMetaByUserId = <String, Map<String, dynamic>>{};

                  for (final doc in chatsSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final members = List<String>.from(data['members'] ?? []);
                    final otherUserId = members.firstWhere(
                      (id) => id != currentUser!.uid,
                      orElse: () => '',
                    );

                    if (otherUserId.isEmpty) continue;

                    chatMetaByUserId[otherUserId] = {
                      'lastMessage': (data['lastMessage'] ?? '').toString(),
                      'lastTimestamp': _extractTimestamp(
                        data['last_message_timestamp'] ??
                            data['lastTimestamp'] ??
                            data['timestamp'],
                      ),
                    };
                  }

                  final allUsers = usersSnapshot.data!.docs
                      .where((doc) => doc.id != currentUser!.uid)
                      .toList();

                  final filteredUsers = allUsers.where((doc) {
                    if (searchQuery.isEmpty) return true;
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    return name.contains(searchQuery);
                  }).toList();

                  if (filteredUsers.isEmpty) {
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
                  final pinnedUserIds = <String>{};

                  for (final doc in usersSnapshot.data!.docs) {
                    if (doc.id != currentUser!.uid) continue;
                    final data = doc.data() as Map<String, dynamic>;
                    final raw = (data['pinnedChats'] as List<dynamic>?) ?? [];
                    pinnedUserIds.addAll(raw.map((id) => id.toString()));
                    break;
                  }

                  for (final userDoc in filteredUsers) {
                    final userData = userDoc.data() as Map<String, dynamic>;
                    final userId = userDoc.id;
                    final metadata = chatMetaByUserId[userId] ?? {};

                    final name = capitalize(
                      userData['name'] as String? ?? 'Unknown',
                    );
                    final photoUrl = userData['photoUrl'] as String? ?? '';
                    final userStatus =
                        userData['status'] as String? ?? 'offline';
                    final chatId = generateChatId(currentUser!.uid, userId);
                    final lastMessage = (metadata['lastMessage'] ?? '')
                        .toString();
                    final lastTimestamp =
                        (metadata['lastTimestamp'] as int?) ?? 0;

                    userIds.add(userId);
                    chatItems.add({
                      'userId': userId,
                      'name': name,
                      'photoUrl': photoUrl,
                      'status': userStatus,
                      'chatId': chatId,
                      'lastMessage': lastMessage.isEmpty
                          ? 'No messages yet'
                          : lastMessage,
                      'lastTimestamp': lastTimestamp,
                      'isPinned': pinnedUserIds.contains(userId),
                    });
                  }

                  chatItems.sort((a, b) {
                    final bool isPinnedA = (a['isPinned'] as bool?) ?? false;
                    final bool isPinnedB = (b['isPinned'] as bool?) ?? false;
                    if (isPinnedA != isPinnedB) {
                      return isPinnedB ? 1 : -1;
                    }
                    final tsA = (a['lastTimestamp'] as int?) ?? 0;
                    final tsB = (b['lastTimestamp'] as int?) ?? 0;
                    final byTime = tsB.compareTo(tsA);
                    if (byTime != 0) return byTime;
                    return (a['name'] as String).compareTo(b['name'] as String);
                  });

                  return Stack(
                    children: [
                      ListView.builder(
                        itemCount: chatItems.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            final stories = chatItems.take(8).toList();
                            return SizedBox(
                              height: 102,
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                scrollDirection: Axis.horizontal,
                                itemBuilder: (_, i) {
                                  final s = stories[i];
                                  final storyUserId = s['userId'] as String;
                                  final storyChatId = s['chatId'] as String;
                                  final photo = s['photoUrl'] as String;
                                  final name = s['name'] as String;
                                  final status = s['status'] as String;
                                  final bool online =
                                      status == 'online' ||
                                      status == 'active' ||
                                      status == 'available';
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(30),
                                    onTap: () async {
                                      await markMessagesAsRead(
                                        storyChatId,
                                        currentUser!.uid,
                                      );
                                      if (!context.mounted) return;
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ChatScreen(
                                            chatId: storyChatId,
                                            userId: storyUserId,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Column(
                                      children: [
                                        Stack(
                                          children: [
                                            CircleAvatar(
                                              radius: 26,
                                              backgroundImage: photo.isNotEmpty
                                                  ? NetworkImage(photo)
                                                  : null,
                                              backgroundColor:
                                                  Colors.grey.shade400,
                                              child: photo.isEmpty
                                                  ? const Icon(
                                                      Icons.person,
                                                      color: Colors.white,
                                                    )
                                                  : null,
                                            ),
                                            if (online)
                                              Positioned(
                                                right: 1,
                                                bottom: 1,
                                                child: Container(
                                                  width: 11,
                                                  height: 11,
                                                  decoration: BoxDecoration(
                                                    color: Colors.green,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: isDark
                                                          ? const Color(
                                                              0xFF121212,
                                                            )
                                                          : Colors.white,
                                                      width: 1.6,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        SizedBox(
                                          width: 56,
                                          child: Text(
                                            name.split(' ').first,
                                            maxLines: 1,
                                            textAlign: TextAlign.center,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 10),
                                itemCount: stories.length,
                              ),
                            );
                          }

                          final item = chatItems[index - 1];
                          final userId = item['userId'] as String;
                          final chatId = item['chatId'] as String;
                          final userName = item['name'] as String;
                          final photoUrl = item['photoUrl'] as String;
                          final status = item['status'] as String;
                          final lastMessage = item['lastMessage'] as String;
                          final lastTimestamp = item['lastTimestamp'] as int;
                          final isPinned = item['isPinned'] as bool;
                          final formattedTime = _formatTime(lastTimestamp);

                          final isOnline =
                              status == 'online' ||
                              status == 'active' ||
                              status == 'available';

                          return StreamBuilder<int>(
                            stream: FirebaseFirestore.instance
                                .collection('chats')
                                .doc(chatId)
                                .collection('messages')
                                .where('isRead', isEqualTo: false)
                                .where(
                                  'receiverId',
                                  isEqualTo: currentUser!.uid,
                                )
                                .snapshots()
                                .map((snapshot) => snapshot.docs.length),
                            builder: (context, unreadSnapshot) {
                              final unreadCount = unreadSnapshot.data ?? 0;

                              final tileBg = Colors.transparent;

                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: tileBg,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: _isSelectionMode
                                      ? () => _toggleSelection(userId)
                                      : () async {
                                          await markMessagesAsRead(
                                            chatId,
                                            currentUser!.uid,
                                          );
                                          if (!context.mounted) return;
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
                                                            leading: Icon(
                                                              isPinned
                                                                  ? Icons
                                                                        .push_pin_outlined
                                                                  : Icons
                                                                        .push_pin,
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .primary,
                                                            ),
                                                            title: Text(
                                                              isPinned
                                                                  ? 'Unpin Chat'
                                                                  : 'Pin Chat',
                                                            ),
                                                            onTap: () {
                                                              Navigator.pop(
                                                                context,
                                                              );
                                                              _togglePinnedChat(
                                                                userId,
                                                                isPinned,
                                                              );
                                                            },
                                                          ),
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
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        if (_isSelectionMode)
                                          Checkbox(
                                            value: _selectedUserIds.contains(
                                              userId,
                                            ),
                                            onChanged: (_) =>
                                                _toggleSelection(userId),
                                          )
                                        else
                                          Stack(
                                            children: [
                                              CircleAvatar(
                                                radius: 28,
                                                backgroundImage:
                                                    photoUrl.isNotEmpty
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
                                                    width: 11,
                                                    height: 11,
                                                    decoration: BoxDecoration(
                                                      color: Colors.green,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: isDark
                                                            ? const Color(
                                                                0xFF121212,
                                                              )
                                                            : Colors.white,
                                                        width: 2,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      userName,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 17,
                                                        color: isDark
                                                            ? Colors.white
                                                            : Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                  if (isPinned)
                                                    Icon(
                                                      Icons.push_pin,
                                                      size: 15,
                                                      color: const Color(
                                                        0xFF4CAFAB,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                lastMessage,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: isDark
                                                      ? Colors.white70
                                                      : Colors.grey.shade600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!_isSelectionMode) ...[
                                          const SizedBox(width: 8),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                formattedTime,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDark
                                                      ? Colors.white60
                                                      : Colors.grey.shade500,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              if (unreadCount > 0)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 7,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF4CAFAB,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    unreadCount.toString(),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
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
              );
            },
          ),
        ),
      ],
    );
  }
}
