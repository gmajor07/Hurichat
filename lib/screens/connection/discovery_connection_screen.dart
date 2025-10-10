import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConnectionsDiscoveryScreen extends StatefulWidget {
  const ConnectionsDiscoveryScreen({super.key});

  @override
  State<ConnectionsDiscoveryScreen> createState() =>
      _ConnectionsDiscoveryScreenState();
}

class _ConnectionsDiscoveryScreenState
    extends State<ConnectionsDiscoveryScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  final Color themeColor = const Color(0xFF4CAFAB);
  Set<String> connectedOrPendingIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  Future<void> _loadConnections() async {
    if (currentUser == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('connections')
        .get();

    setState(() {
      connectedOrPendingIds = snapshot.docs.map((doc) => doc.id).toSet();
      _loading = false;
    });
  }

  Future<void> _sendRequest(String targetUserId, String targetUserName) async {
    if (currentUser == null) return;

    final firestore = FirebaseFirestore.instance;

    // For target user → receiver record
    await firestore
        .collection('users')
        .doc(targetUserId)
        .collection('connections')
        .doc(currentUser!.uid)
        .set({
          'status': 'pending',
          'senderId': currentUser!.uid,
          'senderName': currentUser!.displayName ?? 'Unknown User',
          'receiverId': targetUserId,
          'timestamp': FieldValue.serverTimestamp(),
        });

    // For current user → sender record
    await firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('connections')
        .doc(targetUserId)
        .set({
          'status': 'sent',
          'senderId': currentUser!.uid,
          'receiverId': targetUserId,
          'receiverName': targetUserName,
          'timestamp': FieldValue.serverTimestamp(),
        });

    setState(() {
      connectedOrPendingIds.add(targetUserId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Connection request sent to $targetUserName'),
        backgroundColor: themeColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> data, String userId) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final name = data['name'] ?? 'No Name';
    final phone = data['phone'] ?? '';
    final photoUrl = data['photoUrl'];
    final gender = data['gender'] ?? '';
    final age = data['age']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: themeColor.withOpacity(0.3), width: 2),
            ),
            child: ClipOval(
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildDefaultAvatar(),
                    )
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
                  name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                if (phone.isNotEmpty) ...[
                  Text(
                    phone,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 2),
                ],
                if (gender.isNotEmpty || age.isNotEmpty) ...[
                  Text(
                    [
                      if (gender.isNotEmpty) gender,
                      if (age.isNotEmpty) '$age years',
                    ].join(' • '),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ],
            ),
          ),

          // Connect Button
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () => _sendRequest(userId, name),
              icon: Icon(Icons.person_add_alt_1, color: themeColor, size: 20),
              tooltip: 'Send Connection Request',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, color: Colors.grey, size: 30),
    );
  }

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
          'Discover People',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allUsers = snapshot.data!.docs
                    .where((doc) => doc.id != currentUser!.uid)
                    .where((doc) => !connectedOrPendingIds.contains(doc.id))
                    .toList();

                if (allUsers.isEmpty) {
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
                          'No users available',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'All users are already connected or pending',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Header Info
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: themeColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: themeColor, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Discover and connect with people around you',
                              style: TextStyle(
                                color: themeColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Users List
                    Expanded(
                      child: ListView.builder(
                        itemCount: allUsers.length,
                        itemBuilder: (context, index) {
                          final data =
                              allUsers[index].data() as Map<String, dynamic>;
                          final userId = allUsers[index].id;
                          return _buildUserCard(data, userId);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
