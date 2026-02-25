import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:huruchat/utils/phone_hash_utils.dart';

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
  List<Map<String, dynamic>> _discoveredUsers = [];
  bool _loading = true;
  bool _syncingContacts = false;
  String? _syncMessage;
  int _contactCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeDiscovery();
  }

  Future<void> _initializeDiscovery() async {
    if (currentUser == null) {
      setState(() {
        _loading = false;
        _syncMessage = 'Please sign in first.';
      });
      return;
    }

    await _loadConnections();
    await _syncContactsAndDiscoverUsers();
  }

  Future<void> _loadConnections() async {
    if (currentUser == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('connections')
        .get();

    connectedOrPendingIds = snapshot.docs.map((doc) => doc.id).toSet();
  }

  Future<void> _syncContactsAndDiscoverUsers() async {
    if (currentUser == null) return;

    setState(() {
      _syncingContacts = true;
      _loading = true;
      _syncMessage = null;
    });

    try {
      final hasPermission = await FlutterContacts.requestPermission(
        readonly: true,
      );

      if (!hasPermission) {
        setState(() {
          _syncMessage = 'Contacts permission denied.';
          _discoveredUsers = [];
          _syncingContacts = false;
          _loading = false;
          _contactCount = 0;
        });
        return;
      }

      final contacts = await FlutterContacts.getContacts(withProperties: true);

      final hashedNumbers = <String>{};
      var phoneEntries = 0;

      for (final contact in contacts) {
        for (final phone in contact.phones) {
          final normalized = normalizePhoneNumber(phone.number);
          if (normalized.isEmpty) continue;
          hashedNumbers.add(hashPhoneNumber(normalized));
          phoneEntries++;
        }
      }

      _contactCount = phoneEntries;

      if (hashedNumbers.isEmpty) {
        setState(() {
          _syncMessage = 'No phone numbers found in contacts.';
          _discoveredUsers = [];
          _syncingContacts = false;
          _loading = false;
        });
        return;
      }

      final discovered = await _findRegisteredUsersByHashes(
        hashedNumbers.toList(),
      );

      discovered.sort((a, b) {
        final nameA = (a['name'] ?? '').toString().toLowerCase();
        final nameB = (b['name'] ?? '').toString().toLowerCase();
        return nameA.compareTo(nameB);
      });

      setState(() {
        _discoveredUsers = discovered;
        _syncMessage = discovered.isEmpty
            ? 'No registered users found in your contacts.'
            : null;
        _syncingContacts = false;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _syncMessage = 'Failed to sync contacts.';
        _discoveredUsers = [];
        _syncingContacts = false;
        _loading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _findRegisteredUsersByHashes(
    List<String> hashes,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final discovered = <Map<String, dynamic>>[];
    final seenUserIds = <String>{};

    const chunkSize = 10;

    for (var i = 0; i < hashes.length; i += chunkSize) {
      final end = (i + chunkSize < hashes.length)
          ? i + chunkSize
          : hashes.length;
      final chunk = hashes.sublist(i, end);

      final snapshot = await firestore
          .collection('users')
          .where('phoneHash', whereIn: chunk)
          .get();

      for (final doc in snapshot.docs) {
        if (doc.id == currentUser!.uid) continue;
        if (connectedOrPendingIds.contains(doc.id)) continue;
        if (seenUserIds.contains(doc.id)) continue;

        final data = doc.data();
        discovered.add({
          'uid': doc.id,
          'name': data['name'] ?? 'No Name',
          'phone': data['phone'] ?? '',
          'photoUrl': data['photoUrl'] ?? '',
          'gender': data['gender'] ?? '',
          'age': data['age']?.toString() ?? '',
        });
        seenUserIds.add(doc.id);
      }
    }

    return discovered;
  }

  Future<void> _sendRequest(String targetUserId, String targetUserName) async {
    if (currentUser == null) return;

    final firestore = FirebaseFirestore.instance;

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

    if (!mounted) return;

    setState(() {
      connectedOrPendingIds.add(targetUserId);
      _discoveredUsers.removeWhere((user) => user['uid'] == targetUserId);
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

  Widget _buildUserCard(Map<String, dynamic> data) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = data['uid'] as String;
    final name = data['name'] ?? 'No Name';
    final phone = data['phone'] ?? '';
    final photoUrl = data['photoUrl'] ?? '';
    final gender = data['gender'] ?? '';
    final age = data['age'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: themeColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: photoUrl.isNotEmpty
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
                if (phone.toString().isNotEmpty) ...[
                  Text(
                    phone,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 2),
                ],
                if (gender.toString().isNotEmpty || age.toString().isNotEmpty)
                  Text(
                    [
                      if (gender.toString().isNotEmpty) gender.toString(),
                      if (age.toString().isNotEmpty) '${age.toString()} years',
                    ].join(' • '),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () => _sendRequest(userId, name.toString()),
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
        actions: [
          IconButton(
            onPressed: _syncingContacts ? null : _syncContactsAndDiscoverUsers,
            icon: _syncingContacts
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.sync,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
            tooltip: 'Sync Contacts',
          ),
        ],
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Synced $_contactCount contact numbers • Found ${_discoveredUsers.length} registered users',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _discoveredUsers.isEmpty
                      ? Center(
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
                                _syncMessage ?? 'No users available',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _discoveredUsers.length,
                          itemBuilder: (context, index) {
                            final data = _discoveredUsers[index];
                            return _buildUserCard(data);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
