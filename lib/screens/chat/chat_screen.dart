import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'chat_controller.dart';
import 'chat_theme.dart';
import 'chat_widgets.dart';
import 'conversation_message_search.dart';
import 'conversation_message_pagination.dart';
import 'conversation_latest_messages.dart';
import 'voice_message_logic.dart';
import 'reply_message.dart';
import 'message_mutations.dart';
import 'forwarded_message.dart';
import '../connection/connection_flow.dart';
import 'pinned_message.dart';
import 'chat_typing_indicator.dart';
import 'conversation_draft.dart';
import 'shared_media_screen.dart';
import 'conversation_info_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String userId;

  const ChatScreen({super.key, required this.chatId, required this.userId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  late ChatController controller;
  late final ConversationDraftPersistence _draftPersistence;
  bool _didReportDraftError = false;
  bool _showEmojiPicker = false;
  bool _isSearchingMessages = false;
  bool _isPickingImage = false;
  bool _isStartingVoiceRecording = false;
  Map<String, dynamic>? _replyToMessage;
  Map<String, dynamic>? _editingMessage;
  bool _isSavingEdit = false;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final VoiceRecordingState _voiceRecordingState = VoiceRecordingState();
  Timer? _voiceRecordingTimer;
  File? _activeRecordingFile;
  Stopwatch? _recordingStopwatch;
  String _messageSearchQuery = '';
  String? _highlightedMessageId;
  final Map<String, GlobalKey> _messageKeys = {};
  final Map<String, int> _messageIndicesById = {};
  final Map<String, Map<String, dynamic>> _messagesById = {};
  final Map<String, DocumentSnapshot<Map<String, dynamic>>>
  _loadedFirestoreMessages = {};
  final Set<String> _latestMessageIds = {};
  final List<Set<String>> _olderPageMessageIds = [];
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _olderPageSubscriptions = [];
  final OlderMessagePageLoadGuard _olderPageLoadGuard =
      OlderMessagePageLoadGuard();
  final ConversationLatestMessages _latestMessageNavigation =
      ConversationLatestMessages();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _latestMessagesSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _unreadMessagesSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _chatPinSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _pinnedMessageSubscription;
  String? _pinnedMessageId;
  Map<String, dynamic>? _pinnedMessage;
  String? _pinnedMessageLoadError;
  int _pinnedMessageWatchGeneration = 0;
  bool _isUpdatingPinnedMessage = false;
  late final ChatTypingWriter _typingWriter;
  late final TypingActivity _typingActivity;
  Map<String, dynamic>? _typingUsers;
  Timer? _typingExpiryTimer;
  bool _isOtherParticipantTyping = false;
  bool _didReportTypingWriteError = false;
  DocumentSnapshot<Map<String, dynamic>>? _oldestMessageCursor;
  bool _isLoadingInitialMessages = true;
  bool _hasMoreMessages = true;
  String? _messageStreamError;
  String? _olderPageError;
  bool _didPositionInitialMessages = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = ChatController(
      chatId: widget.chatId,
      userId: widget.userId,
      context: context,
    );
    _draftPersistence = ConversationDraftPersistence(
      store: ConversationDraftStore(
        box: Hive.box('drafts'),
        accountId: FirebaseAuth.instance.currentUser!.uid,
        chatId: widget.chatId,
      ),
      onError: (error, stackTrace) {
        debugPrint('Conversation draft save failed: $error\n$stackTrace');
        if (!mounted || _didReportDraftError) return;
        _didReportDraftError = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save this message draft.')),
        );
      },
    );
    _restoreConversationDraft();
    _typingWriter = ChatTypingWriter(
      chatId: widget.chatId,
      userId: FirebaseAuth.instance.currentUser!.uid,
    );
    _typingActivity = TypingActivity(
      onTypingChanged: _typingWriter.setTyping,
      onError: (error, stackTrace) {
        debugPrint('Typing status unavailable: $error\n$stackTrace');
        if (!mounted || _didReportTypingWriteError) return;
        _didReportTypingWriteError = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Typing status is unavailable in this conversation.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
    controller.scrollController.addListener(_onMessageListScroll);
    _chatPinSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .snapshots()
        .listen(
          _handleChatPinSnapshot,
          onError: (Object error, StackTrace stackTrace) {
            debugPrint(
              'Failed to monitor pinned message in ${widget.chatId}: '
              '$error\n$stackTrace',
            );
            if (mounted) {
              setState(
                () =>
                    _pinnedMessageLoadError = 'Could not load pinned message.',
              );
            }
          },
        );
    _latestMessagesSubscription = _messagesCollection
        .orderBy('timestamp', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(conversationMessagePageSize)
        .snapshots()
        .listen(
          _handleLatestMessages,
          onError: (Object error, StackTrace stackTrace) {
            debugPrint(
              'Failed to load latest messages in ${widget.chatId}: '
              '$error\n$stackTrace',
            );
            if (!mounted) return;
            setState(() {
              _messageStreamError =
                  'Could not load messages. Check your connection and retry.';
              _isLoadingInitialMessages = false;
            });
          },
        );
    controller.init();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      _unreadMessagesSubscription = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .where('receiverId', isEqualTo: currentUserId)
          .snapshots()
          .listen(
            (snapshot) => controller.markMessagesAsRead(snapshot.docs),
            onError: (Object error, StackTrace stackTrace) {
              debugPrint(
                'Failed to monitor unread messages in ${widget.chatId}: '
                '$error\n$stackTrace',
              );
            },
          );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_draftPersistence.dispose());
    controller.scrollController.removeListener(_onMessageListScroll);
    _latestMessagesSubscription?.cancel();
    for (final subscription in _olderPageSubscriptions) {
      subscription.cancel();
    }
    _unreadMessagesSubscription?.cancel();
    _typingExpiryTimer?.cancel();
    _typingActivity.dispose();
    _chatPinSubscription?.cancel();
    _pinnedMessageSubscription?.cancel();
    _voiceRecordingTimer?.cancel();
    unawaited(_disposeVoiceRecorder());
    unawaited(VoiceMessagePlayer.stopActivePlayback());
    _voiceRecordingState.cancel();
    _voiceRecordingState.dispose();
    _latestMessageNavigation.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> _disposeVoiceRecorder() async {
    if (_voiceRecordingState.status ==
            VoiceRecordingStatus.requestingPermission ||
        _voiceRecordingState.status == VoiceRecordingStatus.recording ||
        _voiceRecordingState.status == VoiceRecordingStatus.finalizing) {
      try {
        await _audioRecorder.cancel();
      } catch (error, stackTrace) {
        debugPrint(
          'Could not cancel recording on chat dispose: $error\n$stackTrace',
        );
      }
      await _removeTemporaryRecording(_activeRecordingFile);
    }
    try {
      await _audioRecorder.dispose();
    } catch (error, stackTrace) {
      debugPrint('Could not dispose voice recorder: $error\n$stackTrace');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_typingActivity.stop());
      unawaited(_draftPersistence.flush());
    }
    if (!shouldCancelVoiceRecordingForLifecycle(state)) return;
    if (_voiceRecordingState.status ==
            VoiceRecordingStatus.requestingPermission ||
        _voiceRecordingState.status == VoiceRecordingStatus.recording) {
      unawaited(_cancelVoiceRecording());
    }
    unawaited(VoiceMessagePlayer.stopActivePlayback());
  }

  Future<void> _startVoiceRecording() async {
    if (controller.sendGuard.isSending ||
        controller.sendDebounce?.isActive == true ||
        _isPickingImage ||
        _isStartingVoiceRecording) {
      return;
    }
    await _typingActivity.stop();
    if (!_voiceRecordingState.requestPermission()) return;

    File? recordingFile;
    var permissionWasChecked = false;
    _isStartingVoiceRecording = true;
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      permissionWasChecked = true;
      if (!hasPermission) {
        _voiceRecordingState.cancel();
        if (mounted) {
          _showVoiceRecordingError(microphonePermissionDeniedMessage());
        }
        return;
      }
      if (!mounted ||
          _voiceRecordingState.status !=
              VoiceRecordingStatus.requestingPermission) {
        _voiceRecordingState.cancel();
        return;
      }

      recordingFile = File(
        '${Directory.systemTemp.path}/voice_${controller.generateLocalId()}.m4a',
      );
      _activeRecordingFile = recordingFile;
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: recordingFile.path,
      );
      if (!mounted) {
        await _audioRecorder.cancel();
        await _removeTemporaryRecording(recordingFile);
        _activeRecordingFile = null;
        _voiceRecordingState.cancel();
        return;
      }
      if (_voiceRecordingState.status !=
          VoiceRecordingStatus.requestingPermission) {
        await _audioRecorder.cancel();
        await _removeTemporaryRecording(recordingFile);
        _activeRecordingFile = null;
        return;
      }

      final stopwatch = Stopwatch()..start();
      _recordingStopwatch = stopwatch;
      if (!_voiceRecordingState.start()) {
        await _audioRecorder.cancel();
        await _removeTemporaryRecording(recordingFile);
        _activeRecordingFile = null;
        stopwatch.stop();
        _recordingStopwatch = null;
        return;
      }
      _voiceRecordingTimer = Timer.periodic(const Duration(milliseconds: 250), (
        _,
      ) {
        _voiceRecordingState.updateDuration(stopwatch.elapsed);
      });
    } catch (error, stackTrace) {
      debugPrint('Could not start voice recording: $error\n$stackTrace');
      _voiceRecordingTimer?.cancel();
      _voiceRecordingState.cancel();
      await _removeTemporaryRecording(recordingFile);
      if (mounted) {
        _showVoiceRecordingError(
          permissionWasChecked
              ? 'Could not start recording. Please try again.'
              : microphonePermissionDeniedMessage(),
        );
      }
    } finally {
      _isStartingVoiceRecording = false;
    }
  }

  Future<void> _stopVoiceRecording() async {
    if (!_voiceRecordingState.beginFinalizing()) return;
    _voiceRecordingTimer?.cancel();
    final durationMillis = _recordingStopwatch?.elapsed.inMilliseconds ?? 0;
    try {
      final outputPath = await _audioRecorder.stop();
      final recordingFile = File(outputPath ?? _activeRecordingFile!.path);
      _activeRecordingFile = recordingFile;
      if (!await recordingFile.exists() || await recordingFile.length() == 0) {
        throw StateError('The voice recording is empty.');
      }
      if (!_voiceRecordingState.beginUpload()) return;
      await _typingActivity.stop();
      await controller.sendVoiceMessage(recordingFile, durationMillis);
      _activeRecordingFile = null;
    } catch (error, stackTrace) {
      debugPrint('Could not finish voice recording: $error\n$stackTrace');
      await _removeTemporaryRecording(_activeRecordingFile);
      _activeRecordingFile = null;
      if (mounted) {
        _showVoiceRecordingError(
          'Could not finish recording. Please try again.',
        );
      }
    } finally {
      _recordingStopwatch?.stop();
      _recordingStopwatch = null;
      _voiceRecordingState.complete();
    }
  }

  Future<void> _cancelVoiceRecording() async {
    final wasRequestingPermission =
        _voiceRecordingState.status ==
        VoiceRecordingStatus.requestingPermission;
    if (wasRequestingPermission) {
      _voiceRecordingState.cancel();
    } else if (!_voiceRecordingState.beginFinalizing()) {
      return;
    }
    _voiceRecordingTimer?.cancel();
    try {
      if (!wasRequestingPermission || _activeRecordingFile != null) {
        await _audioRecorder.cancel();
      }
    } catch (error, stackTrace) {
      debugPrint('Could not cancel voice recording: $error\n$stackTrace');
      if (mounted) {
        _showVoiceRecordingError('Could not cancel recording.');
      }
    } finally {
      await _removeTemporaryRecording(_activeRecordingFile);
      _activeRecordingFile = null;
      _recordingStopwatch?.stop();
      _recordingStopwatch = null;
      _voiceRecordingState.cancel();
    }
  }

  Future<void> _removeTemporaryRecording(File? recordingFile) async {
    await deleteTemporaryVoiceRecording(
      recordingFile,
      onError: (error, stackTrace) {
        debugPrint(
          'Could not remove temporary voice recording: $error\n$stackTrace',
        );
      },
    );
  }

  void _showVoiceRecordingError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade400),
    );
  }

  Future<void> _onSendPressed() async {
    if (_voiceRecordingState.status != VoiceRecordingStatus.idle) return;
    if (controller.messageController.text.trim().isEmpty) return;
    await _typingActivity.stop();

    final editingMessage = _editingMessage;
    if (editingMessage != null) {
      if (_isSavingEdit) return;
      setState(() => _isSavingEdit = true);
      try {
        final saved = await controller.editMessage(
          editingMessage,
          controller.messageController.text,
        );
        if (saved && mounted) {
          controller.messageController.clear();
          setState(() => _editingMessage = null);
        }
      } finally {
        if (mounted) setState(() => _isSavingEdit = false);
      }
      return;
    }

    final replyTo = _replyToMessage;
    final replyId = replyTo?[replyToMessageIdField];
    controller.onSendPressed(
      replyTo: replyTo,
      onMessageSent: (sentText) {
        unawaited(_draftPersistence.clearAfterSuccessfulSend(sentText));
      },
      onMessageQueued: replyId is String
          ? () {
              if (!mounted ||
                  _replyToMessage?[replyToMessageIdField] != replyId) {
                return;
              }
              setState(() => _replyToMessage = null);
            }
          : null,
    );
  }

  void _restoreConversationDraft() {
    final existingText = controller.messageController.text;
    final draft = _draftPersistence.restore();
    if (draft == null || existingText.isNotEmpty) return;
    controller.messageController.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
  }

  void _onComposerTextChanged(String text) {
    _typingActivity.onTextChanged(text);
    if (_editingMessage != null) return;
    _draftPersistence.onTextChanged(text);
  }

  void _beginEditing(Map<String, dynamic> message) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (_editingMessage != null ||
        _isSavingEdit ||
        currentUserId == null ||
        !canEditOwnTextMessage(message: message, userId: currentUserId)) {
      return;
    }
    final text = message['text'];
    if (text is! String) return;
    controller.messageController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() {
      _editingMessage = message;
      _replyToMessage = null;
      _showEmojiPicker = false;
    });
  }

  void _cancelEditing() {
    controller.messageController.clear();
    setState(() => _editingMessage = null);
  }

  void _beginReply(Map<String, dynamic> message) {
    if (_editingMessage != null) return;
    final metadata = buildReplyMetadata(message);
    if (metadata == null) return;
    setState(() => _replyToMessage = metadata);
  }

  void _navigateToReply(String messageId) {
    final message = _messagesById[messageId];
    final messageIndex = _messageIndicesById[messageId];
    if (message == null || messageIndex == null) return;

    final result = ConversationMessageSearchResult(
      messageId: messageId,
      messageIndex: messageIndex,
      message: message,
      preview: message['text'] is String ? message['text'] as String : '',
    );
    setState(() => _highlightedMessageId = messageId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_scrollToMessage(result));
    });
  }

  CollectionReference<Map<String, dynamic>> get _messagesCollection =>
      FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages');

  void _handleChatPinSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final chatData = snapshot.data();
    _handleTypingSnapshot(chatData?[typingUsersField]);
    final nextPinnedMessageId = pinnedMessageIdFromChatData(chatData);
    if (nextPinnedMessageId == _pinnedMessageId) return;
    unawaited(_watchPinnedMessage(nextPinnedMessageId));
  }

  void _handleTypingSnapshot(Object? rawTypingUsers) {
    _typingUsers = rawTypingUsers is Map
        ? Map<String, dynamic>.from(rawTypingUsers)
        : null;
    _refreshOtherParticipantTyping();
  }

  void _refreshOtherParticipantTyping() {
    _typingExpiryTimer?.cancel();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isTyping = hasOtherParticipantTyping(
      typingUsers: _typingUsers,
      currentUserId: currentUserId,
      now: DateTime.now(),
    );
    if (mounted && isTyping != _isOtherParticipantTyping) {
      setState(() => _isOtherParticipantTyping = isTyping);
    }
    if (!isTyping) return;

    final expiry = timeUntilTypingExpires(
      typingUsers: _typingUsers,
      currentUserId: currentUserId,
      now: DateTime.now(),
    );
    if (expiry != null) {
      _typingExpiryTimer = Timer(
        expiry + const Duration(milliseconds: 20),
        _refreshOtherParticipantTyping,
      );
    }
  }

  Future<void> _watchPinnedMessage(String? messageId) async {
    final generation = ++_pinnedMessageWatchGeneration;
    await _pinnedMessageSubscription?.cancel();
    if (!mounted || generation != _pinnedMessageWatchGeneration) return;
    setState(() {
      _pinnedMessageId = messageId;
      _pinnedMessage = null;
      _pinnedMessageLoadError = null;
    });
    if (messageId == null) return;

    _pinnedMessageSubscription = _messagesCollection
        .doc(messageId)
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted || generation != _pinnedMessageWatchGeneration) return;
            if (!snapshot.exists) {
              setState(() {
                _pinnedMessageId = null;
                _pinnedMessage = null;
                _loadedFirestoreMessages.remove(messageId);
              });
              unawaited(controller.clearPinnedMessageIfMatches(messageId));
              return;
            }

            _loadedFirestoreMessages[messageId] = snapshot;
            setState(() {
              _pinnedMessage = {...?snapshot.data(), 'firestoreId': messageId};
              _pinnedMessageLoadError = null;
            });
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint(
              'Failed to load pinned message $messageId: $error\n$stackTrace',
            );
            if (!mounted || generation != _pinnedMessageWatchGeneration) return;
            setState(
              () => _pinnedMessageLoadError = 'Could not load pinned message.',
            );
          },
        );
  }

  Future<void> _navigateToPinnedMessage() async {
    final messageId = _pinnedMessageId;
    if (messageId == null) return;
    var snapshot = _loadedFirestoreMessages[messageId];
    if (snapshot == null || !snapshot.exists) {
      try {
        snapshot = await _messagesCollection.doc(messageId).get();
      } catch (error, stackTrace) {
        debugPrint(
          'Could not fetch pinned message $messageId: $error\n$stackTrace',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open pinned message.')),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    final pinnedSnapshot = snapshot;
    if (!pinnedSnapshot.exists) {
      setState(() {
        _pinnedMessageId = null;
        _pinnedMessage = null;
      });
      unawaited(controller.clearPinnedMessageIfMatches(messageId));
      return;
    }

    _loadedFirestoreMessages[messageId] = pinnedSnapshot;
    setState(() {
      _pinnedMessage = {...?pinnedSnapshot.data(), 'firestoreId': messageId};
      _isSearchingMessages = false;
      _messageSearchQuery = '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _navigateToReply(messageId);
    });
  }

  Future<void> _togglePinnedMessage(Map<String, dynamic> message) async {
    if (_isUpdatingPinnedMessage || !canPinMessage(message)) return;
    final messageId = message['firestoreId'] as String;
    final shouldUnpin = _pinnedMessageId == messageId;
    setState(() => _isUpdatingPinnedMessage = true);
    try {
      final updated = shouldUnpin
          ? await controller.unpinMessage(messageId)
          : await controller.pinMessage(message);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              updated
                  ? shouldUnpin
                        ? 'Message unpinned'
                        : 'Message pinned'
                  : shouldUnpin
                  ? 'This message is no longer pinned'
                  : 'Could not pin message. It may have been deleted.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _isUpdatingPinnedMessage = false);
    }
  }

  void _handleLatestMessages(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final isInitialSnapshot = !_didPositionInitialMessages;
    final wasNearLatest = _latestMessageNavigation.isNearLatest;
    final oldIds = _latestMessageIds.toSet();
    _latestMessageIds
      ..clear()
      ..addAll(snapshot.docs.map((document) => document.id));
    for (final document in snapshot.docs) {
      _loadedFirestoreMessages[document.id] = document;
    }
    if (_oldestMessageCursor == null && snapshot.docs.isNotEmpty) {
      _oldestMessageCursor = snapshot.docs.last;
    }

    final latestAddedMessage = snapshot.docChanges.any(
      (change) => change.type == DocumentChangeType.added,
    );
    if (!isInitialSnapshot && !wasNearLatest) {
      _latestMessageNavigation.recordIncomingMessages(
        snapshot.docChanges
            .where((change) => change.type == DocumentChangeType.added)
            .map(
              (change) => MapEntry(
                change.doc.id,
                change.doc.data()?['senderId'] as String? ?? '',
              ),
            ),
        currentUserId: FirebaseAuth.instance.currentUser?.uid,
      );
    }
    if (!latestAddedMessage) {
      for (final removedId in oldIds.difference(_latestMessageIds)) {
        _removeDeletedMessageIfUnreferenced(removedId);
      }
    }

    if (!mounted) return;
    setState(() {
      _messageStreamError = null;
      _isLoadingInitialMessages = false;
      if (_olderPageMessageIds.isEmpty) {
        _hasMoreMessages = pageHasMoreMessages(snapshot.docs.length);
      }
    });

    if (!_didPositionInitialMessages) {
      _didPositionInitialMessages = true;
      _latestMessageNavigation.markInitialMessagesLoaded();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && controller.scrollController.hasClients) {
          controller.scrollController.jumpTo(
            controller.scrollController.position.maxScrollExtent,
          );
        }
      });
    }

    if (shouldFollowLatestMessages(
      isInitialSnapshot: isInitialSnapshot,
      hasAddedMessages: latestAddedMessage,
      wasNearLatest: wasNearLatest,
    )) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _jumpToLatest();
      });
    }
  }

  void _removeDeletedMessageIfUnreferenced(String messageId) {
    unawaited(_removeIfMessageDeleted(messageId));
  }

  Future<void> _removeIfMessageDeleted(String messageId) async {
    try {
      final document = await _messagesCollection.doc(messageId).get();
      if (!document.exists && mounted) {
        setState(() => _loadedFirestoreMessages.remove(messageId));
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Could not verify removed message $messageId: $error\n$stackTrace',
      );
    }
  }

  void _onMessageListScroll() {
    final scrollController = controller.scrollController;
    if (!scrollController.hasClients) return;
    _latestMessageNavigation.updateScrollPosition(
      pixels: scrollController.position.pixels,
      maxScrollExtent: scrollController.position.maxScrollExtent,
    );
    if (_isLoadingInitialMessages ||
        !_hasMoreMessages ||
        _olderPageLoadGuard.isLoading ||
        _isSearchingMessages) {
      return;
    }

    if (isNearConversationStart(scrollController.position.pixels)) {
      unawaited(_loadOlderMessages());
    }
  }

  void _jumpToLatest() {
    unawaited(jumpConversationToLatest(controller.scrollController));
  }

  Future<void> _loadOlderMessages() async {
    final cursor = _oldestMessageCursor;
    if (!_hasMoreMessages || cursor == null || !mounted) return;

    final scrollController = controller.scrollController;
    final hadScrollPosition = scrollController.hasClients;
    final previousPixels = hadScrollPosition
        ? scrollController.position.pixels
        : 0.0;
    final previousMaxExtent = hadScrollPosition
        ? scrollController.position.maxScrollExtent
        : 0.0;

    await _olderPageLoadGuard
        .run(() async {
          if (!mounted) return;
          setState(() {
            _olderPageError = null;
          });
          final firstPage = Completer<void>();
          final query = _messagesCollection
              .orderBy('timestamp', descending: true)
              .orderBy(FieldPath.documentId, descending: true)
              .startAfterDocument(cursor)
              .limit(conversationMessagePageSize);
          late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
          subscription;
          var isFirstSnapshot = true;
          var pageIndex = -1;
          subscription = query.snapshots().listen(
            (snapshot) {
              final previousPageIds = isFirstSnapshot
                  ? <String>{}
                  : _olderPageMessageIds[pageIndex];
              final pageIds = snapshot.docs
                  .map((document) => document.id)
                  .toSet();
              for (final document in snapshot.docs) {
                _loadedFirestoreMessages[document.id] = document;
              }
              if (isFirstSnapshot) {
                pageIndex = _olderPageMessageIds.length;
                _olderPageMessageIds.add(pageIds);
                if (snapshot.docs.isNotEmpty) {
                  _oldestMessageCursor = snapshot.docs.last;
                }
              } else {
                _olderPageMessageIds[pageIndex] = pageIds;
              }
              for (final removedId in previousPageIds.difference(pageIds)) {
                if (!_latestMessageIds.contains(removedId) &&
                    !_olderPageMessageIds.any(
                      (ids) => ids.contains(removedId),
                    )) {
                  _loadedFirestoreMessages.remove(removedId);
                }
              }

              if (!mounted) {
                if (isFirstSnapshot && !firstPage.isCompleted) {
                  firstPage.complete();
                }
                return;
              }
              setState(() {
                if (_olderPageMessageIds.isEmpty) {
                  _hasMoreMessages = pageHasMoreMessages(snapshot.docs.length);
                } else if (isFirstSnapshot) {
                  _hasMoreMessages = pageHasMoreMessages(snapshot.docs.length);
                }
                _isLoadingInitialMessages = false;
              });
              if (isFirstSnapshot) {
                isFirstSnapshot = false;
                if (!firstPage.isCompleted) firstPage.complete();
                if (hadScrollPosition) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted || !scrollController.hasClients) return;
                    scrollController.jumpTo(
                      preserveConversationScrollOffset(
                        previousPixels: previousPixels,
                        previousMaxExtent: previousMaxExtent,
                        currentMinExtent:
                            scrollController.position.minScrollExtent,
                        currentMaxExtent:
                            scrollController.position.maxScrollExtent,
                      ),
                    );
                  });
                }
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              debugPrint(
                'Failed to load older messages in ${widget.chatId}: '
                '$error\n$stackTrace',
              );
              unawaited(subscription.cancel());
              _olderPageSubscriptions.remove(subscription);
              if (mounted) {
                setState(() {
                  _olderPageError =
                      'Could not load older messages. Tap to retry.';
                });
              }
              if (!firstPage.isCompleted) {
                firstPage.completeError(error, stackTrace);
              }
            },
          );
          _olderPageSubscriptions.add(subscription);
          try {
            await firstPage.future;
          } catch (_) {
            await subscription.cancel();
            _olderPageSubscriptions.remove(subscription);
            rethrow;
          }
        })
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint(
            'Older message pagination failed in ${widget.chatId}: '
            '$error\n$stackTrace',
          );
        });
    if (mounted) setState(() {});
  }

  List<Map<String, dynamic>> _currentMessages() {
    final localRaw =
        controller.messageBox.get(widget.chatId, defaultValue: []) as List;
    final localMessages = localRaw
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
    return controller.mergeMessages(
      localMessages,
      _loadedFirestoreMessages.values.toList(),
    );
  }

  Widget _buildPaginationStatus({required bool isSearchResults}) {
    if (_isLoadingInitialMessages) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_messageStreamError != null) {
      return Center(
        child: TextButton(
          onPressed: _retryLatestMessages,
          child: Text(_messageStreamError!),
        ),
      );
    }
    if (_olderPageError != null) {
      return Center(
        child: TextButton(
          onPressed: _loadOlderMessages,
          child: Text(_olderPageError!),
        ),
      );
    }
    if (_olderPageLoadGuard.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_hasMoreMessages) {
      return Center(
        child: TextButton(
          onPressed: _loadOlderMessages,
          child: Text(
            isSearchResults ? 'Search older messages' : 'Load older messages',
          ),
        ),
      );
    }
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Text('Beginning of conversation'),
      ),
    );
  }

  Widget _buildLoadedMessagesView(bool isDark) {
    if (_isLoadingInitialMessages) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_messageStreamError != null) {
      return Center(
        child: TextButton(
          onPressed: _retryLatestMessages,
          child: Text(_messageStreamError!),
        ),
      );
    }

    final messages = _currentMessages();
    _messagesById.clear();
    _messageIndicesById.clear();
    for (var index = 0; index < messages.length; index++) {
      final messageId = conversationMessageId(messages[index], index);
      _messagesById[messageId] = messages[index];
      _messageIndicesById[messageId] = index;
    }
    if (_isSearchingMessages) {
      if (_messageSearchQuery.trim().isEmpty) {
        return const Center(child: Text('Enter a word or phrase to search.'));
      }
      final results = searchConversationMessages(
        messages: messages,
        query: _messageSearchQuery,
      );
      if (results.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No matches in loaded messages.'),
              if (_olderPageError != null)
                TextButton(
                  onPressed: _loadOlderMessages,
                  child: Text(_olderPageError!),
                ),
              if (_hasMoreMessages && _olderPageError == null)
                TextButton(
                  onPressed: _loadOlderMessages,
                  child: Text(
                    _olderPageLoadGuard.isLoading
                        ? 'Loading older messages…'
                        : 'Load older messages and search again',
                  ),
                ),
              if (!_hasMoreMessages)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Beginning of conversation reached.'),
                ),
            ],
          ),
        );
      }

      return Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              'Search covers loaded messages. Load older messages for earlier results.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: results.length + (_hasMoreMessages ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= results.length) {
                  return _buildPaginationStatus(isSearchResults: true);
                }
                final result = results[index];
                final senderId = result.message['senderId'];
                final senderName =
                    senderId == FirebaseAuth.instance.currentUser?.uid
                    ? 'You'
                    : (controller.receiverData?['name'] ?? 'Contact');
                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.message_outlined),
                  ),
                  title: Text(
                    result.preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(senderName.toString()),
                  onTap: () => _selectSearchResult(result),
                );
              },
            ),
          ),
        ],
      );
    }

    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: ChatTheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 44,
                color: ChatTheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Say hello! 👋',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: controller.scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return SizedBox(
            height: 48,
            child: _buildPaginationStatus(isSearchResults: false),
          );
        }
        final messageIndex = index - 1;
        final message = messages[messageIndex];
        final messageId = conversationMessageId(message, messageIndex);
        _messageIndicesById[messageId] = messageIndex;
        final messageKey = _messageKeys.putIfAbsent(messageId, GlobalKey.new);
        return MessageTile(
          key: messageKey,
          message: message,
          isHighlighted: _highlightedMessageId == messageId,
          senderPhotoUrl: FirebaseAuth.instance.currentUser?.photoURL,
          receiverPhotoUrl: controller.receiverData?['photoUrl'] as String?,
          currentUserId: FirebaseAuth.instance.currentUser?.uid,
          onLongPress: message['type'] == 'image' || message['type'] == 'voice'
              ? () => _showMessageOptions(context, message)
              : null,
          onTextLongPressStart: (position) {
            final text = message['text'];
            if (text is String) {
              showTextMessageCopyMenu(
                context,
                globalPosition: position,
                text: text,
                onReply: buildReplyMetadata(message) == null
                    ? null
                    : () => _beginReply(message),
                onReact: message['firestoreId'] is String
                    ? () => _showReactionPicker(context, message)
                    : null,
                onEdit:
                    canEditOwnTextMessage(
                      message: message,
                      userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                    )
                    ? () => _beginEditing(message)
                    : null,
                onDelete:
                    canDeleteOwnMessage(
                      message: message,
                      userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                    )
                    ? () => _confirmDeleteMessage(context, message)
                    : null,
                onForward: canForwardMessage(message)
                    ? () => unawaited(_forwardMessage(message))
                    : null,
                onPin: canPinMessage(message)
                    ? () => unawaited(_togglePinnedMessage(message))
                    : null,
                pinActionLabel: _pinnedMessageId == message['firestoreId']
                    ? 'Unpin Message'
                    : 'Pin Message',
              );
            }
          },
          onReplyTap: _navigateToReply,
          onReactionTap: message['firestoreId'] is String
              ? (emoji) => unawaited(
                  controller.toggleMessageReaction(
                    messageId: message['firestoreId'] as String,
                    emoji: emoji,
                  ),
                )
              : null,
        );
      },
    );
  }

  Future<void> _retryLatestMessages() async {
    await _latestMessagesSubscription?.cancel();
    if (!mounted) return;
    setState(() {
      _messageStreamError = null;
      _isLoadingInitialMessages = true;
      _didPositionInitialMessages = false;
    });
    _latestMessagesSubscription = _messagesCollection
        .orderBy('timestamp', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(conversationMessagePageSize)
        .snapshots()
        .listen(
          _handleLatestMessages,
          onError: (Object error, StackTrace stackTrace) {
            debugPrint(
              'Retry failed loading latest messages: $error\n$stackTrace',
            );
            if (mounted) {
              setState(() {
                _messageStreamError =
                    'Could not load messages. Check your connection and retry.';
                _isLoadingInitialMessages = false;
              });
            }
          },
        );
  }

  Future<void> _deleteMessage(Map<String, dynamic> message) async {
    final deleted = await controller.deleteMessage(message);
    if (!deleted) return;
    final firestoreId = message['firestoreId'];
    if (mounted) {
      setState(() {
        if (firestoreId is String) {
          _loadedFirestoreMessages.remove(firestoreId);
          _messagesById.remove(firestoreId);
        }
        if (_editingMessage?['firestoreId'] == firestoreId) {
          controller.messageController.clear();
          _editingMessage = null;
        }
      });
    }
  }

  Future<void> _confirmDeleteMessage(
    BuildContext context,
    Map<String, dynamic> message,
  ) async {
    if (!await confirmMessageDeletion(context) || !mounted) return;
    await _deleteMessage(message);
  }

  void _showReactionPicker(BuildContext context, Map<String, dynamic> message) {
    final messageId = message['firestoreId'];
    if (messageId is! String || messageId.isEmpty) return;
    showMessageReactionPicker(
      context,
      onSelected: (emoji) => unawaited(
        controller.toggleMessageReaction(messageId: messageId, emoji: emoji),
      ),
    );
  }

  void _toggleMessageSearch() {
    setState(() {
      _isSearchingMessages = !_isSearchingMessages;
      _messageSearchQuery = '';
      _highlightedMessageId = null;
    });
  }

  void _selectSearchResult(ConversationMessageSearchResult result) {
    _messageKeys.putIfAbsent(result.messageId, GlobalKey.new);
    setState(() {
      _isSearchingMessages = false;
      _messageSearchQuery = '';
      _highlightedMessageId = result.messageId;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _scrollToMessage(result);
    });
  }

  Future<void> _scrollToMessage(ConversationMessageSearchResult result) async {
    final scrollController = controller.scrollController;
    for (var attempt = 0; attempt < 6; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !scrollController.hasClients) return;

      final targetContext = _messageKeys[result.messageId]?.currentContext;
      if (targetContext != null) {
        if (!targetContext.mounted) continue;
        await Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: 0.4,
        );
        return;
      }

      final visibleMessages = <({int index, double height})>[];
      for (final entry in _messageIndicesById.entries) {
        final itemContext = _messageKeys[entry.key]?.currentContext;
        final renderObject = itemContext?.findRenderObject();
        if (renderObject is RenderBox && renderObject.hasSize) {
          visibleMessages.add((
            index: entry.value,
            height: renderObject.size.height,
          ));
        }
      }
      if (visibleMessages.isEmpty) return;

      visibleMessages.sort(
        (left, right) => (left.index - result.messageIndex).abs().compareTo(
          (right.index - result.messageIndex).abs(),
        ),
      );
      final nearest = visibleMessages.first;
      final averageHeight =
          visibleMessages.fold<double>(
            0,
            (totalHeight, item) => totalHeight + item.height,
          ) /
          visibleMessages.length;
      final position = scrollController.position;
      final estimatedOffset =
          position.pixels +
          (result.messageIndex - nearest.index) * averageHeight;
      scrollController.jumpTo(
        estimatedOffset
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble(),
      );
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_isPickingImage ||
        controller.sendGuard.isSending ||
        _voiceRecordingState.status != VoiceRecordingStatus.idle) {
      return;
    }
    setState(() => _isPickingImage = true);
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        await _typingActivity.stop();
        await controller.sendImage(image);
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to select chat image: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not select that image.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<void> _openSharedMedia() async {
    final messageId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SharedMediaScreen(chatId: widget.chatId),
      ),
    );
    if (!mounted || messageId == null) return;
    await _navigateToMediaMessage(messageId);
  }

  Future<void> _navigateToMediaMessage(String messageId) async {
    var messageSnapshot = _loadedFirestoreMessages[messageId];
    if (messageSnapshot == null || !messageSnapshot.exists) {
      try {
        messageSnapshot = await _messagesCollection.doc(messageId).get();
      } catch (error, stackTrace) {
        debugPrint(
          'Could not open shared media message $messageId: '
          '$error\n$stackTrace',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open that message.')),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    final loadedMessage = messageSnapshot;
    if (!loadedMessage.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That message is no longer available.')),
      );
      return;
    }

    _loadedFirestoreMessages[messageId] = loadedMessage;
    setState(() {
      _isSearchingMessages = false;
      _messageSearchQuery = '';
      _highlightedMessageId = messageId;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _navigateToReply(messageId);
    });
  }

  IconButton _sharedMediaAction() {
    return IconButton(
      icon: const Icon(Icons.photo_library_outlined),
      color: ChatTheme.primary,
      tooltip: 'Shared media',
      onPressed: _openSharedMedia,
    );
  }

  void _openConversationInfo() {
    unawaited(VoiceMessagePlayer.stopActivePlayback());
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConversationInfoScreen(
          chatId: widget.chatId,
          participantId: widget.userId,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final receiverId = controller.receiverData?['uid'] ?? widget.userId;

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(receiverId)
            .snapshots(),
        builder: (context, snapshot) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          if (!snapshot.hasData) {
            return AppBar(
              backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: false,
              title: GestureDetector(
                onTap: _openConversationInfo,
                child: Text(
                  'Loading...',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 16,
                  ),
                ),
              ),
              actions: [
                _sharedMediaAction(),
                IconButton(
                  icon: Icon(_isSearchingMessages ? Icons.close : Icons.search),
                  color: ChatTheme.primary,
                  tooltip: _isSearchingMessages
                      ? 'Close message search'
                      : 'Search messages',
                  onPressed: _toggleMessageSearch,
                ),
              ],
            );
          }

          final receiverData =
              snapshot.data!.data() as Map<String, dynamic>? ?? {};

          final nameRaw = (receiverData['name'] ?? 'Unknown') as String;
          final name = nameRaw.isNotEmpty
              ? nameRaw[0].toUpperCase() + nameRaw.substring(1)
              : nameRaw;

          final photo = (receiverData['photoUrl'] ?? '') as String;
          final status = (receiverData['status'] ?? 'offline')
              .toString()
              .toLowerCase();

          final isOnline =
              status == 'online' || status == 'active' || status == 'available';

          return AppBar(
            backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            systemOverlayStyle: isDark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            title: GestureDetector(
              onTap: _openConversationInfo,
              child: Row(
                children: [
                  // Avatar with online dot
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: photo.isNotEmpty
                            ? NetworkImage(photo)
                            : null,
                        backgroundColor: Colors.grey.shade300,
                        child: photo.isEmpty
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      if (isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF1A1A2E)
                                    : Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isOnline
                              ? const Color(0xFF4CAF50)
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              _sharedMediaAction(),
              IconButton(
                icon: Icon(_isSearchingMessages ? Icons.close : Icons.search),
                color: ChatTheme.primary,
                tooltip: _isSearchingMessages
                    ? 'Close message search'
                    : 'Search messages',
                onPressed: _toggleMessageSearch,
              ),
              IconButton(
                icon: const Icon(Icons.videocam_outlined),
                color: ChatTheme.primary,
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.call_outlined),
                color: ChatTheme.primary,
                onPressed: () {},
              ),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.grey.shade200,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: ChatTheme.getBackground(context),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_isOtherParticipantTyping)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 5, 16, 5),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Typing…',
                  key: ValueKey('other-participant-typing'),
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
            ),
          if (_pinnedMessageId != null &&
              (_pinnedMessage != null || _pinnedMessageLoadError != null))
            PinnedMessageBanner(
              preview: _pinnedMessage == null
                  ? 'Pinned message'
                  : pinnedMessagePreview(_pinnedMessage!),
              onTap: _navigateToPinnedMessage,
            ),
          if (_isSearchingMessages)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                autofocus: true,
                onChanged: (value) =>
                    setState(() => _messageSearchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search messages in this conversation',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _messageSearchQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.clear),
                          onPressed: () =>
                              setState(() => _messageSearchQuery = ''),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  isDense: true,
                ),
              ),
            ),
          Expanded(
            child: AnimatedBuilder(
              animation: _latestMessageNavigation,
              builder: (context, _) => Stack(
                children: [
                  ValueListenableBuilder<Box>(
                    valueListenable: controller.messageBox.listenable(
                      keys: [widget.chatId],
                    ),
                    builder: (context, _, __) =>
                        _buildLoadedMessagesView(isDark),
                  ),
                  if (_latestMessageNavigation.shouldShowButton &&
                      !_isSearchingMessages)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: ConversationJumpToLatestButton(
                        newMessageCount:
                            _latestMessageNavigation.newMessageCount,
                        onPressed: _jumpToLatest,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Input area
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _voiceRecordingState,
                    builder: (context, _) {
                      final status = _voiceRecordingState.status;
                      if (status == VoiceRecordingStatus.idle) {
                        return const SizedBox.shrink();
                      }
                      final isRecording =
                          status == VoiceRecordingStatus.recording;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                        child: Row(
                          children: [
                            Icon(
                              isRecording
                                  ? Icons.fiber_manual_record_rounded
                                  : Icons.mic_rounded,
                              color: isRecording
                                  ? Colors.red.shade400
                                  : ChatTheme.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(switch (status) {
                                VoiceRecordingStatus.requestingPermission =>
                                  'Requesting microphone permission…',
                                VoiceRecordingStatus.recording =>
                                  'Recording  ${formatVoiceDuration(_voiceRecordingState.duration)}',
                                _ => 'Sending voice message…',
                              }, style: const TextStyle(fontSize: 13)),
                            ),
                            if (isRecording)
                              TextButton(
                                onPressed: _cancelVoiceRecording,
                                child: const Text('Cancel'),
                              )
                            else
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  ValueListenableBuilder<double?>(
                    valueListenable: controller.imageUploadProgress,
                    builder: (context, progress, _) {
                      if (progress == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 4,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${(progress * 100).round()}%'),
                            IconButton(
                              tooltip: 'Cancel image upload',
                              onPressed: controller.cancelImageUpload,
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (_replyToMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: ReplyMessagePreview(
                        text: replyPreviewText(_replyToMessage!),
                        type: replyPreviewType(_replyToMessage!),
                        isComposer: true,
                        onCancel: () => setState(() => _replyToMessage = null),
                      ),
                    ),
                  if (_editingMessage != null)
                    MessageEditBanner(onCancel: _cancelEditing),
                  ChatInputBar(
                    controller: controller,
                    showEmojiPicker: _showEmojiPicker,
                    onToggleEmoji: () =>
                        setState(() => _showEmojiPicker = !_showEmojiPicker),
                    onSendPressed: _onSendPressed,
                    onAttachImage: _pickAndSendImage,
                    isPickingImage: _isPickingImage,
                    isEditingMessage: _editingMessage != null,
                    isSavingEdit: _isSavingEdit,
                    voiceRecordingState: _voiceRecordingState,
                    onStartRecording: _startVoiceRecording,
                    onStopRecording: _stopVoiceRecording,
                    onTextChanged: _onComposerTextChanged,
                  ),
                  if (_showEmojiPicker)
                    ChatEmojiPicker(
                      textController: controller.messageController,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<({String id, String name})?> _pickForwardRecipient() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return null;

    return showModalBottomSheet<({String id, String name})>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.65,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Forward to',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUserId)
                      .collection('connections')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Could not load accepted contacts.'),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final acceptedContacts = filterConnectionsByStatus(
                      snapshot.data!.docs.map(
                        (doc) => ConnectionEntry(doc.id, doc.data()),
                      ),
                      'accepted',
                    ).where((entry) => entry.key != currentUserId).toList();
                    if (acceptedContacts.isEmpty) {
                      return const Center(
                        child: Text('No accepted contacts to forward to.'),
                      );
                    }

                    return ListView.builder(
                      itemCount: acceptedContacts.length,
                      itemBuilder: (context, index) {
                        final contactId = acceptedContacts[index].key;
                        return FutureBuilder<
                          DocumentSnapshot<Map<String, dynamic>>
                        >(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(contactId)
                              .get(),
                          builder: (context, profileSnapshot) {
                            if (profileSnapshot.hasError) {
                              return const ListTile(
                                title: Text('Could not load contact'),
                              );
                            }
                            if (!profileSnapshot.hasData) {
                              return const ListTile(
                                leading: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                title: Text('Loading contact…'),
                              );
                            }
                            final profile = profileSnapshot.data!.data();
                            final name = profile?['name'] is String
                                ? profile!['name'] as String
                                : 'Contact';
                            final photoUrl = profile?['photoUrl'] is String
                                ? profile!['photoUrl'] as String
                                : '';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: photoUrl.isNotEmpty
                                    ? NetworkImage(photoUrl)
                                    : null,
                                child: photoUrl.isEmpty
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              title: Text(name),
                              onTap: () => Navigator.pop(sheetContext, (
                                id: contactId,
                                name: name,
                              )),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _forwardMessage(Map<String, dynamic> message) async {
    if (!canForwardMessage(message)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This message cannot be forwarded.')),
      );
      return;
    }

    final recipient = await _pickForwardRecipient();
    if (!mounted || recipient == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Forward message?'),
        content: Text(
          'Forward “${forwardedMessageDescription(message)}” to '
          '${recipient.name}?',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Forward'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    final didForward = await controller.forwardMessage(
      message,
      recipientId: recipient.id,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            didForward
                ? 'Message forwarded to ${recipient.name}'
                : 'Could not forward message. Please try again.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showMessageOptions(BuildContext context, Map<String, dynamic> msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
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
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                _SheetOption(
                  icon: Icons.copy_rounded,
                  label: 'Copy',
                  color: ChatTheme.primary,
                  isDark: isDark,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: msg['text'] ?? ''));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: ChatTheme.primaryDark,
                      ),
                    );
                  },
                ),
                if (buildReplyMetadata(msg) != null)
                  _SheetOption(
                    icon: Icons.reply_rounded,
                    label: 'Reply',
                    color: ChatTheme.primary,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      _beginReply(msg);
                    },
                  ),
                if (canForwardMessage(msg))
                  _SheetOption(
                    icon: Icons.forward_rounded,
                    label: 'Forward',
                    color: ChatTheme.primary,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      unawaited(_forwardMessage(msg));
                    },
                  ),
                if (canPinMessage(msg))
                  _SheetOption(
                    icon: Icons.push_pin_outlined,
                    label: _pinnedMessageId == msg['firestoreId']
                        ? 'Unpin Message'
                        : 'Pin Message',
                    color: ChatTheme.primary,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      unawaited(_togglePinnedMessage(msg));
                    },
                  ),
                if (msg['firestoreId'] is String)
                  _SheetOption(
                    icon: Icons.add_reaction_outlined,
                    label: 'React',
                    color: ChatTheme.primary,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      _showReactionPicker(context, msg);
                    },
                  ),
                if (msg['senderId'] ==
                    FirebaseAuth.instance.currentUser?.uid) ...[
                  if (msg['status'] == 'failed')
                    _SheetOption(
                      icon: Icons.refresh_rounded,
                      label: 'Retry',
                      color: Colors.orange.shade400,
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(context);
                        controller.retryFailedMessage(msg);
                      },
                    ),
                  if (canDeleteOwnMessage(
                    message: msg,
                    userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                  ))
                    _SheetOption(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete',
                      color: Colors.red.shade400,
                      isDark: isDark,
                      onTap: () {
                        Navigator.pop(context);
                        _confirmDeleteMessage(context, msg);
                      },
                    ),
                ],
                _SheetOption(
                  icon: Icons.close_rounded,
                  label: 'Cancel',
                  color: Colors.grey.shade500,
                  isDark: isDark,
                  onTap: () => Navigator.pop(context),
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

/// ─── Reusable bottom-sheet option row ─────────────────────────────────────
class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
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
