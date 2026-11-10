// lib/screens/chat/chat_controller.dart
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'image_message_logic.dart';
import 'message_send_guard.dart';
import 'message_read_state.dart';
import 'conversation_message_pagination.dart';
import 'voice_message_logic.dart';
import 'reply_message.dart';
import 'message_reactions.dart';
import 'message_mutations.dart';
import 'forwarded_message.dart';
import 'pinned_message.dart';

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
  final MessageSendGuard sendGuard = MessageSendGuard();
  final ValueNotifier<double?> imageUploadProgress = ValueNotifier(null);
  final Set<String> _readUpdatesInFlight = {};
  UploadTask? _activeImageUpload;
  bool _imageUploadCancelled = false;
  bool _disposed = false;

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

  void onSendPressed({
    Map<String, dynamic>? replyTo,
    VoidCallback? onMessageQueued,
    ValueChanged<String>? onMessageSent,
  }) {
    if (sendGuard.isSending) return;
    sendDebounce?.cancel();
    sendDebounce = Timer(
      const Duration(milliseconds: 300),
      () => sendMessage(
        replyTo: replyTo,
        onMessageQueued: onMessageQueued,
        onMessageSent: onMessageSent,
      ),
    );
  }

  Future<void> sendMessage({
    Map<String, dynamic>? replyTo,
    VoidCallback? onMessageQueued,
    ValueChanged<String>? onMessageSent,
  }) async {
    final text = messageController.text.trim();
    if (text.isEmpty || sendGuard.isSending) return;

    await sendGuard.run(() async {
      final localId = generateLocalId();
      final localMessage = {
        'localId': localId,
        'firestoreId': null,
        'senderId': currentUser.uid,
        'text': text,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'status': 'sending',
        if (replyTo != null) ...replyTo,
      };

      try {
        final raw = messageBox.get(chatId, defaultValue: []);
        final localList = (raw as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        localList.add(localMessage);
        await messageBox.put(chatId, localList);

        messageController.clear();
        onMessageQueued?.call();
        scrollToBottom();
        final sent = await sendMessageToFirestore(localMessage);
        if (sent) onMessageSent?.call(text);
      } catch (e, st) {
        debugPrint('sendMessage error: $e\n$st');
        _showErrorSnackbar('Failed to send message. Please try again.');
      }
    });
  }

  Future<bool> sendMessageToFirestore(
    Map<String, dynamic> localMessage,
  ) async {
    return _sendMessageToFirestore(
      localMessage,
      targetChatId: chatId,
      receiverId: userId,
    );
  }

  Future<bool> _sendMessageToFirestore(
    Map<String, dynamic> localMessage, {
    required String targetChatId,
    required String receiverId,
  }) async {
    try {
      final chatRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(targetChatId);
      final messageRef = chatRef.collection('messages').doc();
      final batch = FirebaseFirestore.instance.batch();
      final messageData = <String, dynamic>{
        'senderId': currentUser.uid,
        'receiverId': receiverId,
        'text': localMessage['text'],
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      };
      if (localMessage['type'] == 'image' &&
          localMessage['imageUrl'] is String) {
        messageData['type'] = 'image';
        messageData['imageUrl'] = localMessage['imageUrl'];
      }
      if (localMessage['type'] == 'voice' &&
          localMessage['audioUrl'] is String) {
        messageData['type'] = 'voice';
        messageData['audioUrl'] = localMessage['audioUrl'];
        messageData['durationMillis'] = localMessage['durationMillis'];
      }
      messageData.addAll(forwardedMessageFieldsForMerge(localMessage));
      for (final field in [
        replyToMessageIdField,
        replyToTypeField,
        replyToTextField,
      ]) {
        final value = localMessage[field];
        if (value is String && value.isNotEmpty) {
          messageData[field] = value;
        }
      }
      batch.set(messageRef, messageData);

      batch.set(chatRef, {
        'lastMessage': switch (localMessage['type']) {
          'image' => '📷 Photo',
          'voice' => '🎤 Voice message',
          _ => localMessage['text'],
        },
        'lastTimestamp': FieldValue.serverTimestamp(),
        'last_message_timestamp': FieldValue.serverTimestamp(),
        'members': [currentUser.uid, receiverId],
      }, SetOptions(merge: true));
      await batch.commit();

      await updateLocalMessageStatus(
        localMessage['localId'],
        'sent',
        firestoreId: messageRef.id,
        targetChatId: targetChatId,
      );
      return true;
    } catch (e) {
      await updateLocalMessageStatus(
        localMessage['localId'],
        'failed',
        targetChatId: targetChatId,
      );
      _showErrorSnackbar('Failed to send message');
      return false;
    }
  }

  Future<void> toggleMessageReaction({
    required String messageId,
    required String emoji,
  }) async {
    if (!messageReactionEmojis.contains(emoji)) {
      throw ArgumentError.value(emoji, 'emoji', 'Unsupported reaction');
    }

    final messageRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(messageRef);
        if (!snapshot.exists) {
          throw StateError('Cannot react to a message that no longer exists.');
        }

        final reactions = normalizeMessageReactions(
          snapshot.data()?['reactions'],
        );
        final nextReaction = reactionValueAfterToggle(
          reactions: reactions,
          userId: currentUser.uid,
          emoji: emoji,
        );
        final updatedReactions = Map<String, String>.from(reactions);
        if (nextReaction == null) {
          updatedReactions.remove(currentUser.uid);
        } else {
          updatedReactions[currentUser.uid] = nextReaction;
        }
        transaction.update(messageRef, {'reactions': updatedReactions});
      });
    } catch (error, stackTrace) {
      debugPrint('Could not update message reaction: $error\n$stackTrace');
      if (!_disposed) {
        _showErrorSnackbar('Could not update reaction. Please try again.');
      }
    }
  }

  Future<bool> pinMessage(Map<String, dynamic> message) async {
    if (!canPinMessage(message)) return false;
    final messageId = message['firestoreId'] as String;
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    final messageRef = chatRef.collection('messages').doc(messageId);

    try {
      return await FirebaseFirestore.instance.runTransaction((
        transaction,
      ) async {
        final messageSnapshot = await transaction.get(messageRef);
        final chatSnapshot = await transaction.get(chatRef);
        if (!messageSnapshot.exists || !chatSnapshot.exists) return false;
        transaction.update(chatRef, pinnedMessageUpdate(messageId));
        return true;
      });
    } catch (error, stackTrace) {
      debugPrint('Could not pin message $messageId: $error\n$stackTrace');
      return false;
    }
  }

  Future<bool> unpinMessage(String messageId) async {
    if (messageId.isEmpty) return false;
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);

    try {
      return await FirebaseFirestore.instance.runTransaction((
        transaction,
      ) async {
        final chatSnapshot = await transaction.get(chatRef);
        if (!chatSnapshot.exists ||
            !shouldClearPinnedMessage(
              currentMessageId: pinnedMessageIdFromChatData(
                chatSnapshot.data(),
              ),
              deletedMessageId: messageId,
            )) {
          return false;
        }
        transaction.update(chatRef, {
          pinnedMessageIdField: FieldValue.delete(),
        });
        return true;
      });
    } catch (error, stackTrace) {
      debugPrint('Could not unpin message $messageId: $error\n$stackTrace');
      return false;
    }
  }

  Future<void> clearPinnedMessageIfMatches(String messageId) async {
    if (messageId.isEmpty) return;
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final chatSnapshot = await transaction.get(chatRef);
        if (shouldClearPinnedMessage(
          currentMessageId: pinnedMessageIdFromChatData(chatSnapshot.data()),
          deletedMessageId: messageId,
        )) {
          transaction.update(chatRef, {
            pinnedMessageIdField: FieldValue.delete(),
          });
        }
      });
    } catch (error, stackTrace) {
      debugPrint(
        'Could not clear deleted pinned message $messageId: '
        '$error\n$stackTrace',
      );
    }
  }

  Future<void> sendImage(XFile image) async {
    if (sendGuard.isSending) return;

    await sendGuard.run(() async {
      _imageUploadCancelled = false;
      final localId = generateLocalId();
      if (!_disposed) imageUploadProgress.value = 0;
      try {
        final imageUrl = await uploadImageSafely(
          () => _uploadChatImage(image, localId),
          onError: (error, stackTrace) {
            debugPrint('Chat image upload failed: $error\n$stackTrace');
          },
        );
        if (imageUrl == null) {
          if (!_disposed) {
            _showErrorSnackbar(
              imageMessageFailureText(cancelled: _imageUploadCancelled),
            );
          }
          return;
        }
        if (_disposed) return;

        final localMessage = <String, dynamic>{
          'localId': localId,
          'firestoreId': null,
          ...buildImageMessageFields(
            senderId: currentUser.uid,
            receiverId: userId,
            imageUrl: imageUrl,
          ),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'status': 'sending',
        };
        final raw = messageBox.get(chatId, defaultValue: []);
        final localList =
            (raw as List)
                .map((entry) => Map<String, dynamic>.from(entry as Map))
                .toList()
              ..add(localMessage);
        await messageBox.put(chatId, localList);
        scrollToBottom();
        await sendMessageToFirestore(localMessage);
      } catch (error, stackTrace) {
        debugPrint('Failed to send chat image: $error\n$stackTrace');
        if (!_disposed) {
          _showErrorSnackbar(
            imageMessageFailureText(cancelled: _imageUploadCancelled),
          );
        }
      } finally {
        _activeImageUpload = null;
        if (!_disposed) imageUploadProgress.value = null;
      }
    });
  }

  Future<bool> forwardMessage(
    Map<String, dynamic> original, {
    required String recipientId,
  }) async {
    if (_disposed ||
        sendGuard.isSending ||
        recipientId.isEmpty ||
        recipientId == currentUser.uid) {
      return false;
    }

    final originalMessageId = forwardedMessageId(original);
    if (originalMessageId == null) return false;
    final fields = buildForwardedMessageFields(
      original: original,
      forwardedFrom: original['forwardedFrom'] is String
          ? original['forwardedFrom'] as String
          : original['senderId'] is String
          ? original['senderId'] as String
          : '',
      forwardedFromMessageId: originalMessageId,
    );
    if (fields == null) return false;

    final destinationChatId = [currentUser.uid, recipientId]..sort();
    final destinationChatIdString = destinationChatId.join('_');
    final localId = generateLocalId();
    final localMessage = <String, dynamic>{
      'localId': localId,
      'firestoreId': null,
      'senderId': currentUser.uid,
      'receiverId': recipientId,
      ...fields,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'status': 'sending',
      'isRead': false,
    };

    var succeeded = false;
    final started = await sendGuard.run(() async {
      try {
        final raw = messageBox.get(destinationChatIdString, defaultValue: []);
        final localMessages =
            (raw as List)
                .map((entry) => Map<String, dynamic>.from(entry as Map))
                .toList()
              ..add(localMessage);
        await messageBox.put(destinationChatIdString, localMessages);

        await _sendMessageToFirestore(
          localMessage,
          targetChatId: destinationChatIdString,
          receiverId: recipientId,
        );
        final updatedRaw = messageBox.get(
          destinationChatIdString,
          defaultValue: [],
        );
        final updatedMessages = (updatedRaw as List)
            .map((entry) => Map<String, dynamic>.from(entry as Map))
            .toList();
        succeeded = updatedMessages.any(
          (message) =>
              message['localId'] == localId && message['status'] == 'sent',
        );
      } catch (error, stackTrace) {
        debugPrint('Could not forward message: $error\n$stackTrace');
        _showErrorSnackbar('Could not forward message. Please try again.');
      }
    });
    return started && succeeded;
  }

  Future<void> sendVoiceMessage(File recording, int durationMillis) async {
    if (sendGuard.isSending || _disposed) {
      await _deleteRecordingFile(recording);
      return;
    }

    await sendGuard.run(() async {
      final localId = generateLocalId();
      try {
        final audioUrl = await uploadVoiceSafely(
          () => _uploadChatVoice(recording, localId),
          onError: (error, stackTrace) {
            debugPrint('Chat voice upload failed: $error\n$stackTrace');
          },
        );
        if (audioUrl == null) {
          if (!_disposed) {
            _showErrorSnackbar(
              'Could not upload voice message. Please try again.',
            );
          }
          return;
        }
        if (_disposed) return;

        final localMessage = <String, dynamic>{
          'localId': localId,
          'firestoreId': null,
          ...buildVoiceMessageFields(
            senderId: currentUser.uid,
            receiverId: userId,
            audioUrl: audioUrl,
            durationMillis: durationMillis,
          ),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'status': 'sending',
        };
        final raw = messageBox.get(chatId, defaultValue: []);
        final localList =
            (raw as List)
                .map((entry) => Map<String, dynamic>.from(entry as Map))
                .toList()
              ..add(localMessage);
        await messageBox.put(chatId, localList);
        scrollToBottom();
        await sendMessageToFirestore(localMessage);
      } catch (error, stackTrace) {
        debugPrint('Failed to send chat voice message: $error\n$stackTrace');
        if (!_disposed) {
          _showErrorSnackbar('Could not send voice message. Please try again.');
        }
      } finally {
        await _deleteRecordingFile(recording);
      }
    });
  }

  Future<String> _uploadChatVoice(File recording, String localId) async {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('chats')
        .child(chatId)
        .child('audio')
        .child(currentUser.uid)
        .child('$localId.m4a');
    final snapshot = await storageRef.putFile(
      recording,
      SettableMetadata(contentType: 'audio/mp4'),
    );
    return snapshot.ref.getDownloadURL();
  }

  Future<void> _deleteRecordingFile(File recording) async {
    await deleteTemporaryVoiceRecording(
      recording,
      onError: (error, stackTrace) {
        debugPrint(
          'Could not remove temporary voice recording: $error\n$stackTrace',
        );
      },
    );
  }

  Future<String> _uploadChatImage(XFile image, String localId) async {
    final path = image.path;
    final extension = imageFileExtension(path);
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('chats')
        .child(chatId)
        .child('images')
        .child(currentUser.uid)
        .child('$localId.$extension');
    final uploadTask = storageRef.putFile(
      File(path),
      SettableMetadata(contentType: imageContentTypeForPath(path)),
    );
    _activeImageUpload = uploadTask;
    final progressSubscription = uploadTask.snapshotEvents.listen(
      (snapshot) {
        if (!_disposed && snapshot.totalBytes > 0) {
          imageUploadProgress.value =
              snapshot.bytesTransferred / snapshot.totalBytes;
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
          'Chat image upload progress stream failed: $error\n$stackTrace',
        );
      },
    );
    try {
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } finally {
      await progressSubscription.cancel();
    }
  }

  Future<void> cancelImageUpload() async {
    final task = _activeImageUpload;
    if (task == null) return;
    _imageUploadCancelled = true;
    await task.cancel();
  }

  Future<void> markMessagesAsRead(
    Iterable<QueryDocumentSnapshot> documents,
  ) async {
    final readUpdates = buildReadReceiptUpdates(
      documents.map(
        (document) => MapEntry(
          document.id,
          Map<String, dynamic>.from(document.data() as Map),
        ),
      ),
      currentUser.uid,
    );
    final updates = readUpdates.keys.where(_readUpdatesInFlight.add).toList();
    if (updates.isEmpty) return;

    try {
      final messages = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages');
      for (var start = 0; start < updates.length; start += 500) {
        final batch = FirebaseFirestore.instance.batch();
        final end = (start + 500).clamp(0, updates.length);
        for (final messageId in updates.sublist(start, end)) {
          batch.update(messages.doc(messageId), readUpdates[messageId]!);
        }
        await batch.commit();
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to mark messages as read in $chatId: $error\n$stackTrace',
      );
    } finally {
      _readUpdatesInFlight.removeAll(updates);
    }
  }

  Future<void> updateLocalMessageStatus(
    String localId,
    String status, {
    String? firestoreId,
    String? targetChatId,
  }) async {
    final messageChatId = targetChatId ?? chatId;
    final raw = messageBox.get(messageChatId, defaultValue: []);
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

    await messageBox.put(messageChatId, localList);
    if (messageChatId == chatId) scrollToBottom();
  }

  Future<void> retryFailedMessage(Map<String, dynamic> message) async {
    final text = message['text'] ?? '';
    final hasImage =
        message['type'] == 'image' &&
        message['imageUrl'] is String &&
        (message['imageUrl'] as String).isNotEmpty;
    if ((text.isEmpty && !hasImage) || sendGuard.isSending) return;

    await sendGuard.run(() async {
      try {
        final raw = messageBox.get(chatId, defaultValue: []);
        final localList = (raw as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        for (var m in localList) {
          if (m['localId'] == message['localId']) m['status'] = 'sending';
        }
        await messageBox.put(chatId, localList);

        await sendMessageToFirestore(message);
      } catch (e, st) {
        debugPrint('retryFailedMessage error: $e\n$st');
        _showErrorSnackbar('Failed to retry message. Please try again.');
      }
    });
  }

  Future<bool> editMessage(Map<String, dynamic> message, String newText) async {
    final text = normalizedEditedMessageText(newText);
    if (text == null ||
        !canEditOwnTextMessage(message: message, userId: currentUser.uid)) {
      return false;
    }

    final messageId = message['firestoreId'] as String;
    final messageRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    try {
      final updated = await FirebaseFirestore.instance.runTransaction((
        transaction,
      ) async {
        final snapshot = await transaction.get(messageRef);
        if (!snapshot.exists) return false;
        final data = snapshot.data();
        if (data?['senderId'] != currentUser.uid ||
            (data?['type'] != null && data?['type'] != 'text')) {
          return false;
        }

        transaction.update(
          messageRef,
          messageEditUpdateFields(
            text: text,
            editedAt: FieldValue.serverTimestamp(),
          ),
        );
        return true;
      });
      if (!updated) {
        _showErrorSnackbar('This message is no longer available to edit.');
        return false;
      }

      await _updateLocalMessageAfterEdit(messageId, text);
      return true;
    } catch (error, stackTrace) {
      debugPrint('Could not edit message: $error\n$stackTrace');
      if (!_disposed) {
        _showErrorSnackbar('Could not edit message. Please try again.');
      }
      return false;
    }
  }

  Future<void> _updateLocalMessageAfterEdit(
    String messageId,
    String text,
  ) async {
    final raw = messageBox.get(chatId, defaultValue: []);
    final localList = (raw as List)
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
    for (final localMessage in localList) {
      if (localMessage['firestoreId'] == messageId) {
        localMessage['text'] = text;
        localMessage['editedAt'] = DateTime.now().millisecondsSinceEpoch;
      }
    }
    await messageBox.put(chatId, localList);
  }

  Future<bool> deleteMessage(Map<String, dynamic> message) async {
    if (!canDeleteOwnMessage(message: message, userId: currentUser.uid)) {
      _showErrorSnackbar('You can only delete your own messages.');
      return false;
    }

    final messageId = message['firestoreId'];
    if (messageId is String && messageId.isNotEmpty) {
      final messageRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);
      try {
        final deleted = await FirebaseFirestore.instance.runTransaction((
          transaction,
        ) async {
          final snapshot = await transaction.get(messageRef);
          if (!snapshot.exists) return true;
          if (snapshot.data()?['senderId'] != currentUser.uid) return false;
          transaction.delete(messageRef);
          return true;
        });
        if (!deleted) {
          _showErrorSnackbar('You can only delete your own messages.');
          return false;
        }
      } catch (error, stackTrace) {
        debugPrint('Could not delete message: $error\n$stackTrace');
        if (!_disposed) {
          _showErrorSnackbar('Could not delete message. Please try again.');
        }
        return false;
      }
    }

    final raw = messageBox.get(chatId, defaultValue: []);
    final localList = (raw as List)
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
    localList.removeWhere(
      (localMessage) =>
          (message['localId'] != null &&
              localMessage['localId'] == message['localId']) ||
          (messageId != null && localMessage['firestoreId'] == messageId),
    );
    await messageBox.put(chatId, localList);
    return true;
  }

  /// Merge local messages and firestore docs into a single sorted list
  List<Map<String, dynamic>> mergeMessages(
    List<Map<String, dynamic>> localMessages,
    List<DocumentSnapshot<Map<String, dynamic>>> firestoreDocs,
  ) {
    final Map<String, Map<String, dynamic>> merged = {};

    for (var doc in firestoreDocs) {
      final data = Map<String, dynamic>.from(doc.data() ?? const {});
      final firestoreId = doc.id;
      merged['f_$firestoreId'] = {
        'firestoreId': firestoreId,
        'senderId': data['senderId'],
        'receiverId': data['receiverId'],
        'text': data['text'] ?? '',
        'type': data['type'],
        'imageUrl': data['imageUrl'],
        'audioUrl': data['audioUrl'],
        'durationMillis': data['durationMillis'],
        replyToMessageIdField: data[replyToMessageIdField],
        replyToTypeField: data[replyToTypeField],
        replyToTextField: data[replyToTextField],
        ...messageReactionFieldsForMerge(data),
        ...forwardedMessageFieldsForMerge(data),
        'editedAt': data['editedAt'],
        'timestamp': _getTimestamp(data['timestamp']),
        'status': 'sent',
        'isRead': data['isRead'] == true,
      };
    }

    for (var localMsg in localMessages) {
      final localId = localMsg['localId'];
      final firestoreId = localMsg['firestoreId'];

      if (firestoreId != null && merged.containsKey('f_$firestoreId')) continue;

      final localTimestamp = localMsg['timestamp'] is int
          ? localMsg['timestamp'] as int
          : 0;
      final isDuplicate = merged.values.any((msg) {
        final firestoreTimestamp = msg['timestamp'] is int
            ? msg['timestamp'] as int
            : 0;
        return msg['text'] == localMsg['text'] &&
            (msg['type'] ?? 'text') == (localMsg['type'] ?? 'text') &&
            msg['imageUrl'] == localMsg['imageUrl'] &&
            msg['audioUrl'] == localMsg['audioUrl'] &&
            msg[replyToMessageIdField] == localMsg[replyToMessageIdField] &&
            (firestoreTimestamp - localTimestamp).abs() < 5000 &&
            msg['senderId'] == localMsg['senderId'];
      });

      if (!isDuplicate) merged['l_$localId'] = localMsg;
    }

    final orderedMessages = mergeAndSortMessagePages([
      merged.entries.map((entry) => MapEntry(entry.key, entry.value)),
    ]);
    return orderedMessages.map((entry) => entry.value).toList();
  }

  int _getTimestamp(dynamic timestamp) {
    return messageTimestampMillis(timestamp);
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
    _disposed = true;
    _imageUploadCancelled = true;
    final activeUpload = _activeImageUpload;
    if (activeUpload != null) unawaited(activeUpload.cancel());
    messageController.dispose();
    scrollController.dispose();
    sendDebounce?.cancel();
    sendGuard.dispose();
    imageUploadProgress.dispose();
    _readUpdatesInFlight.clear();
  }
}
