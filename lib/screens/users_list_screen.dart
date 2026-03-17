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

  // ── Helpers ──────────────────────────────────────────────────────────────

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

  String _formatTime(int timestampMs) {
    if (timestampMs <= 0) return '';
    final messageDate = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final now = DateTime.now();
    final difference = now.difference(messageDate);
    if (difference.inDays == 0) return DateFormat('HH:mm').format(messageDate);
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('M/d').format(messageDate);
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _deleteConnection(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({'chatHistory': FieldValue.arrayRemove([userId])})
          .catchError((_) {});
      if (mounted) {
        _showSnack('Chat removed');
      }
    } catch (_) {
      if (mounted) _showSnack('Failed to remove chat');
    }
  }

  Future<void> _blockUser(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({'blockedUsers': FieldValue.arrayUnion([userId])});
      if (mounted) _showSnack('User blocked');
    } catch (_) {
      if (mounted) _showSnack('Failed to block user');
    }
  }

  Future<void> _togglePinnedChat(String userId, bool isPinned) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({
        'pinnedChats': isPinned
            ? FieldValue.arrayRemove([userId])
            : FieldValue.arrayUnion([userId]),
      });
      if (mounted) {
        _showSnack(isPinned ? 'Chat unpinned' : 'Chat pinned');
      }
    } catch (_) {
      if (mounted) _showSnack('Failed to update pin');
    }
  }

  void _enterSelectionMode() => setState(() => _isSelectionMode = true);

  void _exitSelectionMode() => setState(() {
        _isSelectionMode = false;
        _selectedUserIds.clear();
      });

  void _toggleSelection(String userId) => setState(() {
        if (_selectedUserIds.contains(userId)) {
          _selectedUserIds.remove(userId);
        } else {
          _selectedUserIds.add(userId);
        }
      });

  void _selectAll(List<String> userIds) => setState(() {
        _selectedUserIds
          ..clear()
          ..addAll(userIds);
      });

  Future<void> _deleteSelectedConnections() async {
    try {
      for (var userId in _selectedUserIds) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .update({'chatHistory': FieldValue.arrayRemove([userId])})
            .catchError((_) {});
      }
      setState(() {
        _selectedUserIds.clear();
        _isSelectionMode = false;
      });
      if (mounted) _showSnack('Chats removed');
    } catch (_) {
      if (mounted) _showSnack('Failed to remove chats');
    }
  }

  Future<void> markMessagesAsRead(
      String chatId, String currentUserId) async {
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

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF3D8A84),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Center(
        child: Text('Not logged in',
            style: TextStyle(color: Colors.red)),
      );
    }
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // ── Search bar ───────────────────────────────────────────────────
        _ModernSearchBar(
          controller: _searchController,
          isDark: isDark,
          query: searchQuery,
          onChanged: (v) =>
              setState(() => searchQuery = v.toLowerCase().trim()),
          onClear: () {
            _searchController.clear();
            setState(() => searchQuery = '');
          },
        ),

        // ── Chat list ────────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance.collection('users').snapshots(),
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

                  // Build chat metadata map
                  final chatMetaByUserId = <String, Map<String, dynamic>>{};
                  for (final doc in chatsSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final members =
                        List<String>.from(data['members'] ?? []);
                    final otherUserId = members.firstWhere(
                      (id) => id != currentUser!.uid,
                      orElse: () => '',
                    );
                    if (otherUserId.isEmpty) continue;
                    chatMetaByUserId[otherUserId] = {
                      'lastMessage':
                          (data['lastMessage'] ?? '').toString(),
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
                    final name =
                        (data['name'] ?? '').toString().toLowerCase();
                    return name.contains(searchQuery);
                  }).toList();

                  if (filteredUsers.isEmpty) {
                    return _EmptyState(searchQuery: searchQuery);
                  }

                  // Collect pinned chat IDs
                  final pinnedUserIds = <String>{};
                  for (final doc in usersSnapshot.data!.docs) {
                    if (doc.id != currentUser!.uid) continue;
                    final data = doc.data() as Map<String, dynamic>;
                    final raw =
                        (data['pinnedChats'] as List<dynamic>?) ?? [];
                    pinnedUserIds
                        .addAll(raw.map((id) => id.toString()));
                    break;
                  }

                  // Build chat items
                  final userIds = <String>[];
                  final chatItems = <Map<String, dynamic>>[];

                  for (final userDoc in filteredUsers) {
                    final userData =
                        userDoc.data() as Map<String, dynamic>;
                    final userId = userDoc.id;
                    final metadata = chatMetaByUserId[userId] ?? {};
                    final name = capitalize(
                        userData['name'] as String? ?? 'Unknown');
                    final photoUrl =
                        userData['photoUrl'] as String? ?? '';
                    final userStatus =
                        userData['status'] as String? ?? 'offline';
                    final chatId =
                        generateChatId(currentUser!.uid, userId);
                    final lastMessage =
                        (metadata['lastMessage'] ?? '').toString();
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

                  // Sort: pinned first, then by timestamp, then name
                  chatItems.sort((a, b) {
                    final bool pA = (a['isPinned'] as bool?) ?? false;
                    final bool pB = (b['isPinned'] as bool?) ?? false;
                    if (pA != pB) return pB ? 1 : -1;
                    final tsA = (a['lastTimestamp'] as int?) ?? 0;
                    final tsB = (b['lastTimestamp'] as int?) ?? 0;
                    final byTime = tsB.compareTo(tsA);
                    if (byTime != 0) return byTime;
                    return (a['name'] as String)
                        .compareTo(b['name'] as String);
                  });

                  return Stack(
                    children: [
                      ListView.builder(
                        itemCount: chatItems.length + 1,
                        itemBuilder: (context, index) {
                          // ── index 0 = stories + section header ──
                          if (index == 0) {
                            final stories =
                                chatItems.take(8).toList();
                            return Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                // Stories row
                                if (stories.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 8, 16, 0),
                                    child: Text(
                                      'Active Now',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.4,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.grey.shade500,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: 108,
                                    child: ListView.separated(
                                      padding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      scrollDirection: Axis.horizontal,
                                      itemCount: stories.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(width: 8),
                                      itemBuilder: (_, i) {
                                        final s = stories[i];
                                        final storyUserId =
                                            s['userId'] as String;
                                        final storyChatId =
                                            s['chatId'] as String;
                                        final photo =
                                            s['photoUrl'] as String;
                                        final name =
                                            s['name'] as String;
                                        final status =
                                            s['status'] as String;
                                        final bool online =
                                            status == 'online' ||
                                                status == 'active' ||
                                                status == 'available';
                                        return _StoryAvatar(
                                          photo: photo,
                                          name: name,
                                          online: online,
                                          isDark: isDark,
                                          onTap: () async {
                                            await markMessagesAsRead(
                                              storyChatId,
                                              currentUser!.uid,
                                            );
                                            if (!context.mounted) return;
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ChatScreen(
                                                  chatId: storyChatId,
                                                  userId: storyUserId,
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                                // Messages section header
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 4, 16, 6),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Messages',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }

                          // ── Chat tile ────────────────────────────
                          final item = chatItems[index - 1];
                          final userId = item['userId'] as String;
                          final chatId = item['chatId'] as String;
                          final userName = item['name'] as String;
                          final photoUrl = item['photoUrl'] as String;
                          final status = item['status'] as String;
                          final lastMessage =
                              item['lastMessage'] as String;
                          final lastTimestamp =
                              item['lastTimestamp'] as int;
                          final isPinned = item['isPinned'] as bool;
                          final formattedTime =
                              _formatTime(lastTimestamp);
                          final isOnline = status == 'online' ||
                              status == 'active' ||
                              status == 'available';

                          return StreamBuilder<int>(
                            stream: FirebaseFirestore.instance
                                .collection('chats')
                                .doc(chatId)
                                .collection('messages')
                                .where('isRead', isEqualTo: false)
                                .where('receiverId',
                                    isEqualTo: currentUser!.uid)
                                .snapshots()
                                .map((s) => s.docs.length),
                            builder: (context, unreadSnapshot) {
                              final unreadCount =
                                  unreadSnapshot.data ?? 0;
                              final isSelected =
                                  _selectedUserIds.contains(userId);

                              return _ChatTile(
                                userId: userId,
                                userName: userName,
                                photoUrl: photoUrl,
                                isOnline: isOnline,
                                lastMessage: lastMessage,
                                formattedTime: formattedTime,
                                unreadCount: unreadCount,
                                isPinned: isPinned,
                                isSelectionMode: _isSelectionMode,
                                isSelected: isSelected,
                                isDark: isDark,
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
                                    : () => _showChatOptions(
                                          context,
                                          userId: userId,
                                          userName: userName,
                                          isPinned: isPinned,
                                          isDark: isDark,
                                        ),
                                onCheckboxTap: () =>
                                    _toggleSelection(userId),
                              );
                            },
                          );
                        },
                      ),

                      // ── Floating selection action bar ────────────
                      if (_isSelectionMode)
                        _SelectionBar(
                          selectedCount: _selectedUserIds.length,
                          isDark: isDark,
                          onSelectAll: () => _selectAll(userIds),
                          onDelete: _selectedUserIds.isEmpty
                              ? null
                              : _deleteSelectedConnections,
                          onCancel: _exitSelectionMode,
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

  // ── Bottom sheet ─────────────────────────────────────────────────────────

  void _showChatOptions(
    BuildContext context, {
    required String userId,
    required String userName,
    required bool isPinned,
    required bool isDark,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final sheetDark =
            Theme.of(sheetCtx).brightness == Brightness.dark;
        return SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: sheetDark
                  ? const Color(0xFF1E1E1E)
                  : Colors.white,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28)),
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
                    color: sheetDark
                        ? Colors.white24
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // User name label
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    userName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: sheetDark
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  color: sheetDark
                      ? Colors.white12
                      : Colors.grey.shade200,
                ),
                _SheetOpt(
                  icon: isPinned
                      ? Icons.push_pin_outlined
                      : Icons.push_pin_rounded,
                  label: isPinned ? 'Unpin Chat' : 'Pin Chat',
                  color: const Color(0xFF4CAFaa),
                  isDark: sheetDark,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _togglePinnedChat(userId, isPinned);
                  },
                ),
                _SheetOpt(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Select',
                  color: const Color(0xFF4CAFaa),
                  isDark: sheetDark,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _enterSelectionMode();
                    _toggleSelection(userId);
                  },
                ),
                _SheetOpt(
                  icon: Icons.block_rounded,
                  label: 'Block User',
                  color: Colors.red.shade400,
                  isDark: sheetDark,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _blockUser(userId);
                  },
                ),
                _SheetOpt(
                  icon: Icons.delete_outline_rounded,
                  label: 'Remove Chat',
                  color: Colors.red.shade400,
                  isDark: sheetDark,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _deleteConnection(userId);
                  },
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

// ════════════════════════════════════════════════════════════════════════════
// Sub-widgets
// ════════════════════════════════════════════════════════════════════════════

/// Modern pill search bar
class _ModernSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _ModernSearchBar({
    required this.controller,
    required this.isDark,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(Icons.search_rounded,
              size: 20,
              color: isDark ? Colors.white38 : Colors.grey.shade400),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(
                fontSize: 14.5,
                color: isDark ? Colors.white.withValues(alpha: 0.87) : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                hintStyle: TextStyle(
                  color:
                      isDark ? Colors.white38 : Colors.grey.shade400,
                  fontSize: 14.5,
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (query.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.cancel_rounded,
                    size: 18,
                    color: isDark
                        ? Colors.white38
                        : Colors.grey.shade400),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Icon(Icons.mic_none_rounded,
                  size: 20,
                  color:
                      isDark ? Colors.white38 : Colors.grey.shade400),
            ),
        ],
      ),
    );
  }
}

/// Story avatar with gradient ring + online indicator
class _StoryAvatar extends StatelessWidget {
  final String photo;
  final String name;
  final bool online;
  final bool isDark;
  final VoidCallback onTap;

  const _StoryAvatar({
    required this.photo,
    required this.name,
    required this.online,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: online
                  ? const LinearGradient(
                      colors: [Color(0xFF4CAFaa), Color(0xFF2E7D68)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: online ? null : Colors.grey.shade300,
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF121212) : Colors.white,
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundImage:
                    photo.isNotEmpty ? NetworkImage(photo) : null,
                backgroundColor: Colors.grey.shade400,
                child: photo.isEmpty
                    ? const Icon(Icons.person,
                        color: Colors.white, size: 22)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 58,
            child: Text(
              name.split(' ').first,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chat list tile
class _ChatTile extends StatelessWidget {
  final String userId;
  final String userName;
  final String photoUrl;
  final bool isOnline;
  final String lastMessage;
  final String formattedTime;
  final int unreadCount;
  final bool isPinned;
  final bool isSelectionMode;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onCheckboxTap;

  const _ChatTile({
    required this.userId,
    required this.userName,
    required this.photoUrl,
    required this.isOnline,
    required this.lastMessage,
    required this.formattedTime,
    required this.unreadCount,
    required this.isPinned,
    required this.isSelectionMode,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
    this.onLongPress,
    required this.onCheckboxTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: isSelected
            ? const Color(0xFF4CAFaa).withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 10),
            child: Row(
              children: [
                // Selection checkbox / avatar
                if (isSelectionMode)
                  GestureDetector(
                    onTap: onCheckboxTap,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 26,
                      height: 26,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? const Color(0xFF4CAFaa)
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF4CAFaa)
                              : Colors.grey.shade400,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 14)
                          : null,
                    ),
                  )
                else
                  // Avatar with online dot
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: photoUrl.isNotEmpty
                            ? NetworkImage(photoUrl)
                            : null,
                        backgroundColor: Colors.grey.shade300,
                        child: photoUrl.isEmpty
                            ? Icon(Icons.person,
                                color: Colors.white,
                                size: 26)
                            : null,
                      ),
                      if (isOnline)
                        Positioned(
                          bottom: 1,
                          right: 1,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF121212)
                                    : Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                const SizedBox(width: 12),

                // Name + last message + meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: unreadCount > 0
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                fontSize: 15.5,
                                color: isDark
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          if (isPinned)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.push_pin_rounded,
                                size: 13,
                                color: Color(0xFF4CAFaa),
                              ),
                            ),
                          if (!isSelectionMode) ...[
                            const SizedBox(width: 4),
                            Text(
                              formattedTime,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: unreadCount > 0
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: unreadCount > 0
                                    ? const Color(0xFF4CAFaa)
                                    : (isDark
                                        ? Colors.white38
                                        : Colors.grey.shade500),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: unreadCount > 0
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                                color: isDark
                                    ? (unreadCount > 0
                                        ? Colors.white60
                                        : Colors.white38)
                                    : (unreadCount > 0
                                        ? Colors.black54
                                        : Colors.grey.shade500),
                              ),
                            ),
                          ),
                          if (!isSelectionMode && unreadCount > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAFaa),
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                              child: Text(
                                unreadCount > 99
                                    ? '99+'
                                    : unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty state widget
class _EmptyState extends StatelessWidget {
  final String searchQuery;
  const _EmptyState({required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAFaa).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_search_rounded,
              size: 42,
              color: Color(0xFF4CAFaa),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            searchQuery.isEmpty ? 'No users available' : 'No users found',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          if (searchQuery.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Try a different search term',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white30 : Colors.grey.shade400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Floating selection action bar
class _SelectionBar extends StatelessWidget {
  final int selectedCount;
  final bool isDark;
  final VoidCallback onSelectAll;
  final VoidCallback? onDelete;
  final VoidCallback onCancel;

  const _SelectionBar({
    required this.selectedCount,
    required this.isDark,
    required this.onSelectAll,
    required this.onDelete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onSelectAll,
                icon: const Icon(Icons.select_all_rounded, size: 17),
                label: const Text('All'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4CAFaa),
                  side: const BorderSide(color: Color(0xFF4CAFaa)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 17),
                label: Text(selectedCount > 0
                    ? 'Remove ($selectedCount)'
                    : 'Remove'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.red.shade200,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white12
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: IconButton(
                onPressed: onCancel,
                icon: Icon(
                  Icons.close_rounded,
                  color: isDark
                      ? Colors.white54
                      : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet option row
class _SheetOpt extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _SheetOpt({
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
