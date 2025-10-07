import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String userId;

  const ChatScreen({super.key, required this.chatId, required this.userId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser!;
  late Box _messageBox;
  Map<String, dynamic>? receiverData;
  late ScrollController _scrollController;
  Timer? _sendDebounce;

  // Color scheme
  final Color _primaryColor = Colors.blue.shade700;
  final Color _accentColor = Colors.blue.shade400;
  final Color _sentMessageColor = Colors.blue.shade500;
  final Color _receivedMessageColor = Colors.grey.shade200;
  final Color _errorColor = Colors.red.shade400;
  final Color _successColor = Colors.green.shade600;

  @override
  void initState() {
    super.initState();
    _messageBox = Hive.box('messages');
    _loadReceiverData();
    _scrollController = ScrollController();
  }

  Future<void> _loadReceiverData() async {
    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get();
      if (!chatDoc.exists) return;

      final members = List<String>.from(chatDoc.data()?['members'] ?? []);
      final receiverId = members.firstWhere(
        (id) => id != currentUser.uid,
        orElse: () => widget.userId,
      );

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .get();

      if (userDoc.exists) {
        setState(
          () => receiverData = Map<String, dynamic>.from(userDoc.data() ?? {}),
        );
      }
    } catch (e) {
      _showErrorSnackbar('Failed to load user data');
    }
  }

  String _generateLocalId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rnd = Random().nextInt(1000000);
    return '${now}_$rnd';
  }

  void _onSendPressed() {
    _sendDebounce?.cancel();
    _sendDebounce = Timer(const Duration(milliseconds: 300), _sendMessage);
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final localId = _generateLocalId();
    final localTs = DateTime.now().millisecondsSinceEpoch;

    final localMessage = {
      'localId': localId,
      'firestoreId': null,
      'senderId': currentUser.uid,
      'text': text,
      'timestamp': localTs,
      'status': 'sending',
    };

    final localList = (_messageBox.get(widget.chatId, defaultValue: []) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    localList.add(localMessage);
    await _messageBox.put(widget.chatId, localList);

    setState(() {});
    _scrollToBottom();

    await _sendMessageToFirestore(localMessage);
  }

  Future<void> _sendMessageToFirestore(
    Map<String, dynamic> localMessage,
  ) async {
    try {
      final chatRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId);
      final docRef = await chatRef.collection('messages').add({
        'senderId': currentUser.uid,
        'text': localMessage['text'],
        'timestamp': FieldValue.serverTimestamp(),
      });

      await chatRef.set({
        'lastMessage': localMessage['text'],
        'lastTimestamp': FieldValue.serverTimestamp(),
        'members': [currentUser.uid, widget.userId],
      }, SetOptions(merge: true));

      await _updateLocalMessageStatus(
        localMessage['localId'],
        'sent',
        firestoreId: docRef.id,
      );
    } catch (e) {
      await _updateLocalMessageStatus(localMessage['localId'], 'failed');
      _showErrorSnackbar('Failed to send message');
    } finally {
      _controller.clear();
    }
  }

  Future<void> _updateLocalMessageStatus(
    String localId,
    String status, {
    String? firestoreId,
  }) async {
    final localList = (_messageBox.get(widget.chatId, defaultValue: []) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    for (var m in localList) {
      if (m['localId'] == localId) {
        m['status'] = status;
        if (firestoreId != null) m['firestoreId'] = firestoreId;
        break;
      }
    }

    await _messageBox.put(widget.chatId, localList);
    setState(() {});
    _scrollToBottom();
  }

  Future<void> _retryFailedMessage(Map<String, dynamic> message) async {
    final text = message['text'] ?? '';
    if (text.isEmpty) return;

    final localList = (_messageBox.get(widget.chatId, defaultValue: []) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    for (var m in localList) {
      if (m['localId'] == message['localId']) m['status'] = 'sending';
    }
    await _messageBox.put(widget.chatId, localList);
    setState(() {});

    await _sendMessageToFirestore(message);
  }

  List<Map<String, dynamic>> _mergeMessages(
    List<Map<String, dynamic>> localMessages,
    List<QueryDocumentSnapshot> firestoreDocs,
  ) {
    final Map<String, Map<String, dynamic>> merged = {};

    for (var doc in firestoreDocs) {
      final data = Map<String, dynamic>.from(doc.data() as Map);
      final firestoreId = doc.id;
      merged['f_$firestoreId'] = {
        'firestoreId': firestoreId,
        'senderId': data['senderId'],
        'text': data['text'] ?? '',
        'timestamp': _getTimestamp(data['timestamp']),
        'status': 'sent',
      };
    }

    for (var localMsg in localMessages) {
      final localId = localMsg['localId'];
      final firestoreId = localMsg['firestoreId'];

      if (firestoreId != null && merged.containsKey('f_$firestoreId')) continue;

      final isDuplicate = merged.values.any(
        (msg) =>
            msg['text'] == localMsg['text'] &&
            (msg['timestamp'] - localMsg['timestamp']).abs() < 5000 &&
            msg['senderId'] == localMsg['senderId'],
      );

      if (!isDuplicate) merged['l_$localId'] = localMsg;
    }

    return merged.values.toList()..sort(
      (a, b) => (a['timestamp'] as int).compareTo(a['timestamp'] as int),
    );
  }

  int _getTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) return timestamp.millisecondsSinceEpoch;
    if (timestamp is int) return timestamp;
    return DateTime.now().millisecondsSinceEpoch;
  }

  Future<void> _deleteMessage(Map<String, dynamic> message) async {
    final localList = (_messageBox.get(widget.chatId, defaultValue: []) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    localList.removeWhere(
      (m) =>
          (m['localId'] != null &&
              message['localId'] != null &&
              m['localId'] == message['localId']) ||
          (m['firestoreId'] != null &&
              message['firestoreId'] != null &&
              m['firestoreId'] == message['firestoreId']),
    );

    await _messageBox.put(widget.chatId, localList);

    if (message['firestoreId'] != null) {
      final chatRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId);
      try {
        await chatRef
            .collection('messages')
            .doc(message['firestoreId'])
            .delete();
        _showSuccessSnackbar('Message deleted');
      } catch (_) {
        _showErrorSnackbar('Failed to delete message from server');
      }
    }

    setState(() {});
  }

  Widget _buildMessageTile(Map<String, dynamic> data) {
    final isMe = data['senderId'] == currentUser.uid;
    final text = data['text'] ?? '';
    final status = data['status'] ?? 'sent';
    final isFailed = status == 'failed';

    return GestureDetector(
      onLongPress: () => _showMessageActions(data),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        child: Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (!isMe) ...[_buildAvatar(), const SizedBox(width: 8)],
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isMe
                      ? (isFailed
                            ? _errorColor.withOpacity(0.8)
                            : _sentMessageColor)
                      : _receivedMessageColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: isMe
                        ? const Radius.circular(20)
                        : const Radius.circular(4),
                    bottomRight: isMe
                        ? const Radius.circular(4)
                        : const Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 16,
                        color: isMe ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTimeFromMillis(data['timestamp'] as int?),
                          style: TextStyle(
                            fontSize: 11,
                            color: isMe ? Colors.white70 : Colors.black54,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 6),
                          _buildStatusIcon(status),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (isMe) ...[const SizedBox(width: 8), _buildAvatar(isMe: true)],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar({bool isMe = false}) {
    if (isMe) {
      final currentUserPhoto =
          FirebaseAuth.instance.currentUser?.photoURL ?? '';
      return CircleAvatar(
        radius: 16,
        backgroundImage: currentUserPhoto.isNotEmpty
            ? NetworkImage(currentUserPhoto)
            : null,
        backgroundColor: _primaryColor,
        child: currentUserPhoto.isEmpty
            ? Icon(Icons.person, size: 16, color: Colors.white)
            : null,
      );
    }

    final receiverPhoto = (receiverData?['photoUrl'] ?? '') as String;
    return CircleAvatar(
      radius: 16,
      backgroundImage: receiverPhoto.isNotEmpty
          ? NetworkImage(receiverPhoto)
          : null,
      backgroundColor: Colors.grey.shade400,
      child: receiverPhoto.isEmpty
          ? Icon(Icons.person, size: 16, color: Colors.white)
          : null,
    );
  }

  Widget _buildStatusIcon(String status) {
    switch (status) {
      case 'sending':
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
          ),
        );
      case 'failed':
        return Icon(Icons.error_outline, size: 12, color: Colors.white);
      case 'sent':
        return Icon(Icons.done_all, size: 12, color: Colors.white70);
      default:
        return const SizedBox();
    }
  }

  String _formatTimeFromMillis(int? ms) {
    if (ms == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  void _showMessageActions(Map<String, dynamic> message) {
    final isMe = message['senderId'] == currentUser.uid;
    final isFailed = message['status'] == 'failed';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        child: SafeArea(
          child: Material(
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionTile(
                    icon: Icons.copy,
                    title: 'Copy',
                    color: _primaryColor,
                    onTap: () {
                      Clipboard.setData(
                        ClipboardData(text: message['text'] ?? ''),
                      );
                      Navigator.pop(context);
                      _showSuccessSnackbar('Copied to clipboard');
                    },
                  ),
                  if (isMe) ...[
                    if (isFailed)
                      _buildActionTile(
                        icon: Icons.refresh,
                        title: 'Retry',
                        color: _accentColor,
                        onTap: () {
                          Navigator.pop(context);
                          _retryFailedMessage(message);
                        },
                      ),
                    _buildActionTile(
                      icon: Icons.delete,
                      title: 'Delete',
                      color: _errorColor,
                      onTap: () {
                        Navigator.pop(context);
                        _showDeleteConfirmation(message);
                      },
                    ),
                  ],
                  _buildActionTile(
                    icon: Icons.cancel,
                    title: 'Cancel',
                    color: Colors.grey,
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
    );
  }

  Future<void> _showDeleteConfirmation(Map<String, dynamic> message) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Message?',
          style: TextStyle(
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'This action cannot be undone.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMessage(message);
            },
            child: Text(
              'Delete',
              style: TextStyle(color: _errorColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the conversation!',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final receiverName = (receiverData?['name'] ?? 'Unknown User') as String;
    final receiverPhoto = (receiverData?['photoUrl'] ?? '') as String;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey.shade800,
        elevation: 1,
        shadowColor: Colors.black12,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              child: CircleAvatar(
                backgroundImage: receiverPhoto.isNotEmpty
                    ? NetworkImage(receiverPhoto)
                    : null,
                backgroundColor: Colors.grey.shade300,
                child: receiverPhoto.isEmpty
                    ? Icon(Icons.person, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              receiverName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                final localMessages =
                    (_messageBox.get(widget.chatId, defaultValue: []) as List)
                        .map((e) => Map<String, dynamic>.from(e as Map))
                        .toList();

                final firestoreDocs = snapshot.data?.docs ?? [];
                final messages = _mergeMessages(localMessages, firestoreDocs);

                if (messages.isEmpty) return _buildEmptyState();

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageTile(messages[index]);
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        fillColor: Colors.white,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _onSendPressed(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _onSendPressed,
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: _primaryColor,
                      child: const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
