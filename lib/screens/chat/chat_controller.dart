// lib/screens/chat/chat_controller.dart
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ChatController {
  final String chatId;
  final String userId;
  final BuildContext context;

  // Public controllers used by UI widgets
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  // Internal
  late Box messageBox;
  final currentUser = FirebaseAuth.instance.currentUser!;
  Map<String, dynamic>? receiverData;
  Timer? sendDebounce;

  ChatController({
    required this.chatId,
    required this.userId,
    required this.context,
  });

  /// Initialize (call from initState)
  Future<void> init() async {
    messageBox = Hive.box('messages');
    await _loadReceiverData();
  }

  Future<void> _loadReceiverData() async {
    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();
      if (!chatDoc.exists) return;

      final members = List<String>.from(chatDoc.data()?['members'] ?? []);
      final receiverId = members.firstWhere(
        (id) => id != currentUser.uid,
        orElse: () => userId,
      );

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .get();

      if (userDoc.exists) {
        receiverData = Map<String, dynamic>.from(userDoc.data() ?? {});
      }
    } catch (e, st) {
      debugPrint('loadReceiverData error: $e\n$st');
      _showErrorSnackbar('Failed to load user data');
    }
  }

  String generateLocalId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rnd = Random().nextInt(1000000);
    return '${now}_$rnd';
  }

  void onSendPressed() {
    sendDebounce?.cancel();
    sendDebounce = Timer(const Duration(milliseconds: 300), sendMessage);
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    final localId = generateLocalId();
    final localTs = DateTime.now().millisecondsSinceEpoch;

    final localMessage = {
      'localId': localId,
      'firestoreId': null,
      'senderId': currentUser.uid,
      'text': text,
      'timestamp': localTs,
      'status': 'sending',
    };

    // Store locally (Hive)
    final raw = messageBox.get(chatId, defaultValue: []);
    final localList = (raw as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    localList.add(localMessage);
    await messageBox.put(chatId, localList);

    // clear UI input and scroll
    messageController.clear();
    scrollToBottom();

    // send to Firestore
    await sendMessageToFirestore(localMessage);
  }

  Future<void> sendMessageToFirestore(Map<String, dynamic> localMessage) async {
    try {
      final chatRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId);
      final docRef = await chatRef.collection('messages').add({
        'senderId': currentUser.uid,
        'text': localMessage['text'],
        'timestamp': FieldValue.serverTimestamp(),
      });

      await chatRef.set({
        'lastMessage': localMessage['text'],
        'lastTimestamp': FieldValue.serverTimestamp(),
        'members': [currentUser.uid, userId],
      }, SetOptions(merge: true));

      await updateLocalMessageStatus(
        localMessage['localId'],
        'sent',
        firestoreId: docRef.id,
      );
    } catch (e) {
      await updateLocalMessageStatus(localMessage['localId'], 'failed');
      _showErrorSnackbar('Failed to send message');
    }
  }

  Future<void> updateLocalMessageStatus(
    String localId,
    String status, {
    String? firestoreId,
  }) async {
    final raw = messageBox.get(chatId, defaultValue: []);
    final localList = (raw as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    for (var m in localList) {
      if (m['localId'] == localId) {
        m['status'] = status;
        if (firestoreId != null) m['firestoreId'] = firestoreId;
        break;
      }
    }

    await messageBox.put(chatId, localList);
    scrollToBottom();
  }

  Future<void> retryFailedMessage(Map<String, dynamic> message) async {
    final text = message['text'] ?? '';
    if (text.isEmpty) return;

    final raw = messageBox.get(chatId, defaultValue: []);
    final localList = (raw as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    for (var m in localList) {
      if (m['localId'] == message['localId']) m['status'] = 'sending';
    }
    await messageBox.put(chatId, localList);

    await sendMessageToFirestore(message);
  }

  Future<void> deleteMessage(Map<String, dynamic> message) async {
    final raw = messageBox.get(chatId, defaultValue: []);
    final localList = (raw as List)
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

    await messageBox.put(chatId, localList);

    if (message['firestoreId'] != null) {
      try {
        final chatRef = FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId);
        await chatRef
            .collection('messages')
            .doc(message['firestoreId'])
            .delete();
      } catch (e) {
        _showErrorSnackbar('Failed to delete message from server');
      }
    }
  }

  /// Merge local messages and firestore docs into a single sorted list
  List<Map<String, dynamic>> mergeMessages(
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

    final list = merged.values.toList();
    list.sort(
      (a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int),
    );
    return list;
  }

  int _getTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) return timestamp.millisecondsSinceEpoch;
    if (timestamp is int) return timestamp;
    return DateTime.now().millisecondsSinceEpoch;
  }

  void scrollToBottom() {
    if (scrollController.hasClients) {
      try {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } catch (_) {}
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Clean up controllers and timers
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    sendDebounce?.cancel();
  }
}
