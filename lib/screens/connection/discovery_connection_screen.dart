import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:huruchat/utils/phone_hash_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import '../chat/chat_screen.dart';
import 'connection_flow.dart';
import 'discovery_flow.dart';

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
  final ScrollController _discoveryScrollController = ScrollController();
  bool _loading = true;
  bool _syncingContacts = false;
  bool _loadingMoreUsers = false;
  bool _hasMoreUsers = true;
  String? _nextUserCursor;
  String? _syncMessage;
  int _contactCount = 0;
  final Set<String> _invitedNumbers = {};
  final Set<String> _requestingIds = {};
  final Map<String, String> _requestStatuses = {};

  @override
  void initState() {
    super.initState();
    _discoveryScrollController.addListener(_loadMoreUsersWhenNearEnd);
    _initializeDiscovery();
  }

  @override
  void dispose() {
    _discoveryScrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeDiscovery() async {
    if (currentUser == null) {
      setState(() {
        _loading = false;
        _syncMessage = 'Please sign in first.';
      });
      return;
    }

    try {
      await _loadConnections();
      await _syncContactsAndDiscoverUsers();
    } catch (e, st) {
      debugPrint('Failed to initialize discovery: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _syncingContacts = false;
        _syncMessage = 'Failed to load connections. Please try again.';
      });
    }
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
      String? firebaseUsersError;
      try {
        await _loadFirebaseUsers(reset: true);
      } catch (e, st) {
        debugPrint('Failed to load Firebase users for discovery: $e\n$st');
        firebaseUsersError = 'Could not load all Huruchat users.';
      }

      final hasPermission = await FlutterContacts.requestPermission(
        readonly: true,
      );

      if (!hasPermission) {
        if (!mounted) return;
        setState(() {
          _syncMessage = firebaseUsersError == null
              ? 'Contacts permission denied. Showing Huruchat users.'
              : 'Contacts permission denied. $firebaseUsersError';
          _syncingContacts = false;
          _loading = false;
          _contactCount = 0;
        });
        return;
      }

      final contacts = await FlutterContacts.getContacts(withProperties: true);

      final contactEntries = <Map<String, String>>[];
      final hashedNumbers = <String>{};
      var phoneEntries = 0;

      for (final contact in contacts) {
        final displayName = contact.displayName.trim();
        for (final phone in contact.phones) {
          final normalized = normalizePhoneNumber(phone.number);
          if (normalized.isEmpty) continue;
          final hash = hashPhoneNumber(normalized);
          hashedNumbers.add(hash);
          contactEntries.add({
            'name': displayName,
            'phone': normalized,
            'hash': hash,
          });
          phoneEntries++;
        }
      }

      _contactCount = phoneEntries;

      if (hashedNumbers.isEmpty) {
        if (!mounted) return;
        setState(() {
          _syncMessage = firebaseUsersError == null
              ? 'No phone numbers found. Showing Huruchat users.'
              : 'No phone numbers found. $firebaseUsersError';
          _syncingContacts = false;
          _loading = false;
        });
        return;
      }

      final registeredByHash = await _findRegisteredUsersByHashes(
        hashedNumbers.toList(),
      );

      final contactDiscoveries = _buildDiscoveredEntries(
        contactEntries,
        registeredByHash,
      );

      if (!mounted) return;
      setState(() {
        _mergeContactDiscoveries(contactDiscoveries);
        _syncMessage = _discoveredUsers.isEmpty
            ? firebaseUsersError ?? 'No discoverable users found.'
            : firebaseUsersError;
        _syncingContacts = false;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('Failed to load discoverable users: $e\n$st');
      if (!mounted) return;
      setState(() {
        _syncMessage = 'Could not load people from Huruchat. Please retry.';
        _syncingContacts = false;
        _loadingMoreUsers = false;
        _loading = false;
      });
    }
  }

  Future<void> _loadFirebaseUsers({
    bool reset = false,
    bool loadingMore = false,
  }) async {
    if (currentUser == null ||
        (_loadingMoreUsers && !loadingMore) ||
        (!reset && !_hasMoreUsers)) {
      return;
    }

    if (loadingMore) {
      setState(() => _loadingMoreUsers = true);
    }

    if (reset) {
      _nextUserCursor = null;
      _hasMoreUsers = true;
    }

    final result = await FirebaseFunctions.instance
        .httpsCallable('discoverUsers')
        .call<Map<String, dynamic>>({
          'pageSize': 40,
          if (_nextUserCursor != null) 'cursor': _nextUserCursor,
        });
    final data = result.data;
    final rawUsers = data['users'];
    if (rawUsers is! List) {
      throw StateError(
        'The discoverUsers function returned an invalid user list.',
      );
    }

    final page = buildDiscoverableUserEntries(
      users: rawUsers.whereType<Map>().map(
        (user) => Map<String, dynamic>.from(user),
      ),
      currentUserId: currentUser!.uid,
      connectedOrPendingIds: connectedOrPendingIds,
    );

    if (!mounted) return;
    setState(() {
      if (reset) _discoveredUsers = [];
      final existingIds = _discoveredUsers
          .where((user) => user['isRegistered'] == true)
          .map((user) => user['uid'] as String)
          .toSet();
      _discoveredUsers.addAll(
        page.where((user) => existingIds.add(user['uid'] as String)),
      );
      final cursor = data['nextCursor'];
      _nextUserCursor = cursor is String ? cursor : null;
      _hasMoreUsers = data['hasMore'] == true && _nextUserCursor != null;
      _loading = false;
      _loadingMoreUsers = false;
      _sortDiscoveries();
      _syncMessage = _discoveredUsers.isEmpty && !_hasMoreUsers
          ? 'No discoverable users found.'
          : null;
    });
  }

  void _sortDiscoveries() {
    _discoveredUsers.sort((a, b) {
      final aRegistered = a['isRegistered'] == true;
      final bRegistered = b['isRegistered'] == true;
      if (aRegistered != bRegistered) return aRegistered ? -1 : 1;
      return (a['name'] ?? '').toString().toLowerCase().compareTo(
        (b['name'] ?? '').toString().toLowerCase(),
      );
    });
  }

  void _mergeContactDiscoveries(List<Map<String, dynamic>> contacts) {
    final registeredIds = _discoveredUsers
        .where((user) => user['isRegistered'] == true)
        .map((user) => user['uid'] as String)
        .toSet();
    final contactIds = <String>{};

    for (final user in contacts) {
      if (user['isRegistered'] == true) {
        final userId = (user['uid'] ?? '').toString();
        if (userId.isEmpty ||
            registeredIds.contains(userId) ||
            !contactIds.add(userId)) {
          continue;
        }
      }
      _discoveredUsers.add(user);
    }
    _sortDiscoveries();
  }

  void _loadMoreUsersWhenNearEnd() {
    if (_discoveryScrollController.position.extentAfter > 300 ||
        _loadingMoreUsers ||
        !_hasMoreUsers) {
      return;
    }
    _loadFirebaseUsers(loadingMore: true).catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      debugPrint('Failed to load more discoverable users: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _loadingMoreUsers = false;
        _syncMessage = 'Could not load more people. Scroll to retry.';
      });
    });
  }

  List<Map<String, dynamic>> _buildDiscoveredEntries(
    List<Map<String, String>> contactEntries,
    Map<String, Map<String, dynamic>> registeredByHash,
  ) {
    final discovered = <Map<String, dynamic>>[];
    final seenHashes = <String>{};

    for (final entry in contactEntries) {
      final hash = entry['hash'] ?? '';
      final phone = entry['phone'] ?? '';
      if (hash.isEmpty || phone.isEmpty || seenHashes.contains(hash)) continue;
      seenHashes.add(hash);

      final user = registeredByHash[hash];
      if (user != null) {
        final userId = user['uid']?.toString() ?? '';
        if (userId.isEmpty) continue;
        discovered.add({
          'uid': userId,
          'name': (user['name'] ?? '').toString().isNotEmpty
              ? user['name']
              : (entry['name'] ?? 'No Name'),
          'phone': user['phone'] ?? phone,
          'photoUrl': user['photoUrl'] ?? '',
          'gender': user['gender'] ?? '',
          'age': user['age'] ?? '',
          'isRegistered': true,
        });
      } else {
        discovered.add({
          'uid': '',
          'name': (entry['name'] ?? '').isNotEmpty
              ? entry['name']
              : 'Unknown Contact',
          'phone': phone,
          'photoUrl': '',
          'gender': '',
          'age': '',
          'isRegistered': false,
        });
      }
    }

    return discovered;
  }

  Future<Map<String, Map<String, dynamic>>> _findRegisteredUsersByHashes(
    List<String> hashes,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final discovered = <String, Map<String, dynamic>>{};
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
        final hash = (data['phoneHash'] ?? '').toString();
        if (hash.isEmpty) continue;
        discovered[hash] = {
          'uid': doc.id,
          'name': data['name'] ?? 'No Name',
          'photoUrl': data['photoUrl'] ?? '',
          'phone': '',
          'gender': '',
          'age': '',
        };
        seenUserIds.add(doc.id);
      }
    }

    return discovered;
  }

  Future<void> _sendRequest(String targetUserId, String targetUserName) async {
    if (currentUser == null) return;

    final firestore = FirebaseFirestore.instance;

    try {
      final completed = await runConnectionActionOnce(
        _requestingIds,
        targetUserId,
        () async {
          final documents = createConnectionRequestDocuments(
            senderId: currentUser!.uid,
            senderName: currentUser!.displayName ?? 'Unknown User',
            receiverId: targetUserId,
            receiverName: targetUserName,
            timestamp: FieldValue.serverTimestamp(),
          );
          final batch = firestore.batch();
          batch.set(
            firestore
                .collection('users')
                .doc(targetUserId)
                .collection('connections')
                .doc(currentUser!.uid),
            documents.incoming,
          );
          batch.set(
            firestore
                .collection('users')
                .doc(currentUser!.uid)
                .collection('connections')
                .doc(targetUserId),
            documents.outgoing,
          );
          await batch.commit();
          if (!mounted) return;
          setState(() {
            connectedOrPendingIds.add(targetUserId);
            _requestStatuses[targetUserId] = 'sent';
          });
        },
        onStateChanged: () {
          if (mounted) setState(() {});
        },
      );
      if (!completed || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection request sent to $targetUserName'),
          backgroundColor: themeColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('Failed to send connection request: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send request. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openChat(String targetUserId) {
    if (currentUser == null) return;
    final members = [currentUser!.uid, targetUserId]..sort();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ChatScreen(chatId: members.join('_'), userId: targetUserId),
      ),
    );
  }

  Future<void> _inviteContact(Map<String, dynamic> data) async {
    final phone = (data['phone'] ?? '').toString();
    final name = (data['name'] ?? 'there').toString();
    if (phone.isEmpty) return;

    const appName = 'Huruchat';
    final inviteText =
        'Hi $name, join me on $appName so we can chat there. Download the app and message me once you sign up.';

    Future<void> openSmsApp() async {
      final encodedBody = Uri.encodeComponent(inviteText);
      final Uri smsUri = Uri.parse('sms:$phone?body=$encodedBody');
      final opened = await launchUrl(
        smsUri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open messages app. Use Copy Invite.'),
          ),
        );
      } else if (opened && mounted) {
        setState(() {
          _invitedNumbers.add(phone);
        });
      }
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite Contact'),
        content: Text(
          'This contact is not on Huruchat yet.\n\nYou can copy the invite or open your Messages app directly for $phone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openSmsApp();
            },
            child: const Text('Open Messages'),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: inviteText));
              Navigator.pop(ctx);
              setState(() {
                _invitedNumbers.add(phone);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Invite text copied. Send it via SMS/WhatsApp.',
                  ),
                ),
              );
            },
            child: const Text('Copy Invite'),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> data) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = data['uid'] as String;
    final name = data['name'] ?? 'No Name';
    final phone = data['phone'] ?? '';
    final photoUrl = (data['photoUrl'] ?? '').toString();
    final bool isRegistered = data['isRegistered'] == true;
    final bool inviteSent = _invitedNumbers.contains(phone.toString());

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
                if (isRegistered)
                  Text(
                    'On Huruchat',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
          if (isRegistered)
            Column(
              children: [
                TextButton.icon(
                  onPressed:
                      _requestingIds.contains(userId) ||
                          _requestStatuses[userId] == 'sent'
                      ? null
                      : () => _sendRequest(userId, name.toString()),
                  icon: _requestingIds.contains(userId)
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _requestStatuses[userId] == 'sent'
                              ? Icons.check
                              : Icons.person_add_alt_1,
                          size: 18,
                        ),
                  label: Text(
                    _requestStatuses[userId] == 'sent' ? 'Sent' : 'Connect',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: themeColor,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                IconButton(
                  onPressed: () => _openChat(userId),
                  icon: const Icon(Icons.chat_bubble_outline, size: 20),
                  color: themeColor,
                  tooltip: 'Message',
                ),
              ],
            )
          else
            FilledButton.icon(
              onPressed: () => _inviteContact(data),
              icon: Icon(
                inviteSent ? Icons.check : Icons.send_to_mobile_outlined,
                size: 16,
              ),
              label: Text(inviteSent ? 'Invited' : 'Invite'),
              style: FilledButton.styleFrom(
                backgroundColor: inviteSent ? Colors.grey : themeColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
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
    final int registeredCount = _discoveredUsers
        .where((u) => u['isRegistered'] == true)
        .length;
    final int unregisteredCount = _discoveredUsers.length - registeredCount;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: true,
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
            tooltip: 'Refresh people and sync contacts',
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
                      '$registeredCount people on Huruchat • $_contactCount contact numbers checked • $unregisteredCount to invite',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _discoveredUsers.isEmpty && !_hasMoreUsers
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
                          controller: _discoveryScrollController,
                          itemCount:
                              _discoveredUsers.length +
                              (_hasMoreUsers || _loadingMoreUsers ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _discoveredUsers.length) {
                              if (_syncMessage != null && !_loadingMoreUsers) {
                                return Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Center(
                                    child: Text(
                                      _syncMessage!,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              }
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
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
