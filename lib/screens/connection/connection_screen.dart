import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../chat/chat_screen.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen>
    with SingleTickerProviderStateMixin {
  final currentUser = FirebaseAuth.instance.currentUser;
  final Color themeColor = const Color(0xFF4CAFAB);
  late TabController _tabController;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  // ---------- 🔹 Firestore Actions ----------
  Future<void> _acceptRequest(String userId) async {
    final firestore = FirebaseFirestore.instance;

    await firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('connections')
        .doc(userId)
        .set({'status': 'accepted', 'userId': userId});

    await firestore
        .collection('users')
        .doc(userId)
        .collection('connections')
        .doc(currentUser!.uid)
        .set({'status': 'accepted', 'userId': currentUser!.uid});

    _showSnackbar('✅ Connected with user');
  }

  Future<void> _rejectRequest(String userId) async {
    final firestore = FirebaseFirestore.instance;

    await firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('connections')
        .doc(userId)
        .set({'status': 'rejected', 'userId': userId});

    await firestore
        .collection('users')
        .doc(userId)
        .collection('connections')
        .doc(currentUser!.uid)
        .set({'status': 'rejected', 'userId': currentUser!.uid});

    _showSnackbar('❌ Request declined');
  }

  Future<void> _cancelRequest(String userId) async {
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

    _showSnackbar('📤 Request cancelled');
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: themeColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _sendMessage(String userId) async {
    // Generate chat ID and navigate to chat screen
    final currentUserId = currentUser!.uid;
    final chatId = [currentUserId, userId]..sort();
    final chatIdStr = chatId.join('_');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(chatId: chatIdStr, userId: userId),
      ),
    );
  }

  Future<void> _disconnectUser(String userId) async {
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

    _showSnackbar('✅ Disconnected from user');
  }

  // ---------- 🔹 Fetch User Data ----------
  Future<Map<String, dynamic>> _getUserData(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        return {
          'name': data['name'] ?? 'Unknown User',
          'photoUrl': data['photoUrl'] ?? null,
          'phone': data['phone'] ?? '',
        };
      }
      return {'name': 'Unknown User', 'photoUrl': null, 'phone': ''};
    } catch (e) {
      return {'name': 'Unknown User', 'photoUrl': null, 'phone': ''};
    }
  }

  // ---------- 🔹 Build Connection Card ----------
  Widget _buildConnectionCard(
    Map<String, dynamic> connectionData,
    String type,
    String userId,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    if (userId.isEmpty) return const SizedBox();

    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserData(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildShimmerCard();

        final userData = snapshot.data!;
        final userName = userData['name'] ?? 'Unknown User';
        final photoUrl = userData['photoUrl'];
        final phone = userData['phone'] ?? '';

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Profile Avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: themeColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: photoUrl != null && photoUrl.isNotEmpty
                      ? Image.network(photoUrl, fit: BoxFit.cover)
                      : _buildDefaultAvatar(),
                ),
              ),
              const SizedBox(width: 16),
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (phone.isNotEmpty)
                      Text(
                        phone,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(type).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getStatusText(type),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _getStatusColor(type),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Action Buttons
              _buildActionButtons(type, userId),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, color: Colors.grey, size: 24),
    );
  }

  Widget _buildShimmerCard() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 16,
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
                  margin: const EdgeInsets.only(bottom: 8),
                ),
                Container(
                  width: 80,
                  height: 12,
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String type) {
    switch (type) {
      case 'pending':
        return Colors.orange;
      case 'sent':
        return Colors.blue;
      case 'accepted':
        return themeColor;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String type) {
    switch (type) {
      case 'pending':
        return 'PENDING REQUEST';
      case 'sent':
        return 'REQUEST SENT';
      case 'accepted':
        return 'CONNECTED';
      case 'rejected':
        return 'REJECTED';
      default:
        return 'UNKNOWN';
    }
  }

  Widget _buildActionButtons(String type, String userId) {
    switch (type) {
      case 'pending':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: themeColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.check, color: themeColor, size: 18),
                onPressed: () => _acceptRequest(userId),
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.red, size: 18),
                onPressed: () => _rejectRequest(userId),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        );
      case 'sent':
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(Icons.close, color: Colors.red, size: 18),
            onPressed: () => _cancelRequest(userId),
            padding: EdgeInsets.zero,
            tooltip: 'Cancel Request',
          ),
        );
      case 'accepted':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: themeColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.message, color: themeColor, size: 18),
                onPressed: () => _sendMessage(userId),
                padding: EdgeInsets.zero,
                tooltip: 'Send Message',
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.link_off, color: Colors.red, size: 18),
                onPressed: () => _disconnectUser(userId),
                padding: EdgeInsets.zero,
                tooltip: 'Disconnect',
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------- 🔹 Build Connection List ----------
  Widget _buildConnectionList(String type) {
    if (currentUser == null) {
      return const Center(child: Text('Please log in'));
    }

    final firestore = FirebaseFirestore.instance;

    Stream<QuerySnapshot> stream = firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('connections')
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allConnections = snapshot.data!.docs;

        // Filter connections by status in code
        final connections = allConnections.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] as String?;
          return status == type;
        }).toList();

        if (connections.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getEmptyStateIcon(type),
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  _getEmptyStateText(type),
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getEmptyStateSubtext(type),
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          itemCount: connections.length,
          itemBuilder: (context, index) {
            final doc = connections[index];
            final data = doc.data() as Map<String, dynamic>;
            final userId = doc.id;
            return _buildConnectionCard(data, type, userId);
          },
        );
      },
    );
  }

  IconData _getEmptyStateIcon(String type) {
    switch (type) {
      case 'pending':
        return Icons.person_outline;
      case 'sent':
        return Icons.send_outlined;
      case 'accepted':
        return Icons.people_outline;
      case 'rejected':
        return Icons.do_not_disturb_outlined;
      default:
        return Icons.people_outline;
    }
  }

  String _getEmptyStateText(String type) {
    switch (type) {
      case 'pending':
        return 'No Pending Requests';
      case 'sent':
        return 'No Sent Requests';
      case 'accepted':
        return 'No Connections';
      case 'rejected':
        return 'No Rejected Requests';
      default:
        return 'No Data';
    }
  }

  String _getEmptyStateSubtext(String type) {
    switch (type) {
      case 'pending':
        return 'Connection requests will appear here';
      case 'sent':
        return 'Your sent requests will appear here';
      case 'accepted':
        return 'Start connecting with people to see them here';
      case 'rejected':
        return 'Rejected requests will appear here';
      default:
        return '';
    }
  }

  // ---------- 🔹 Build UI ----------
  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0, top: 8.0),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: isDark ? Colors.white70 : Colors.black87,
              size: 20,
            ),
          ),
        ),
        title: Text(
          'Connections',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: themeColor,
          labelColor: themeColor,
          unselectedLabelColor: isDark
              ? Colors.grey.shade400
              : Colors.grey.shade600,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 12,
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(icon: Icon(Icons.pending_actions, size: 20), text: 'Pending'),
            Tab(icon: Icon(Icons.send, size: 20), text: 'Sent'),
            Tab(icon: Icon(Icons.people, size: 20), text: 'Connected'),
            Tab(icon: Icon(Icons.cancel, size: 20), text: 'Rejected'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConnectionList('pending'),
          _buildConnectionList('sent'),
          _buildConnectionList('accepted'),
          _buildConnectionList('rejected'),
        ],
      ),
    );
  }
}
