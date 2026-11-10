import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

const Duration typingIndicatorTimeout = Duration(seconds: 5);
const String typingUsersField = 'typingUsers';

int? _typingTimestampMillis(Object? value) {
  return switch (value) {
    Timestamp timestamp => timestamp.millisecondsSinceEpoch,
    DateTime dateTime => dateTime.millisecondsSinceEpoch,
    int millis => millis,
    _ => null,
  };
}

bool hasOtherParticipantTyping({
  required Map<String, dynamic>? typingUsers,
  required String currentUserId,
  required DateTime now,
  Duration timeout = typingIndicatorTimeout,
}) {
  if (typingUsers == null || currentUserId.isEmpty) return false;
  final nowMillis = now.millisecondsSinceEpoch;
  final timeoutMillis = timeout.inMilliseconds;
  return typingUsers.entries.any((entry) {
    if (entry.key == currentUserId) return false;
    final timestamp = _typingTimestampMillis(entry.value);
    return timestamp != null &&
        nowMillis - timestamp <= timeoutMillis &&
        nowMillis - timestamp >= -timeoutMillis;
  });
}

Duration? timeUntilTypingExpires({
  required Map<String, dynamic>? typingUsers,
  required String currentUserId,
  required DateTime now,
  Duration timeout = typingIndicatorTimeout,
}) {
  if (typingUsers == null || currentUserId.isEmpty) return null;
  final nowMillis = now.millisecondsSinceEpoch;
  final timeoutMillis = timeout.inMilliseconds;
  final expirations = typingUsers.entries
      .where((entry) => entry.key != currentUserId)
      .map((entry) => _typingTimestampMillis(entry.value))
      .whereType<int>()
      .where(
        (timestamp) =>
            nowMillis - timestamp <= timeoutMillis &&
            nowMillis - timestamp >= -timeoutMillis,
      )
      .map(
        (timestamp) =>
            (timeoutMillis - (nowMillis - timestamp)).clamp(0, timeoutMillis),
      );
  if (expirations.isEmpty) return null;
  return Duration(milliseconds: expirations.reduce((a, b) => a < b ? a : b));
}

Map<String, dynamic> mergeTypingUserTimestamp({
  required Map<String, dynamic>? currentTypingUsers,
  required String userId,
  required Object timestamp,
}) {
  if (userId.isEmpty) {
    throw ArgumentError.value(userId, 'userId', 'Must not be empty');
  }
  return {...?currentTypingUsers, userId: timestamp};
}

Map<String, dynamic>? removeTypingUser({
  required Map<String, dynamic>? currentTypingUsers,
  required String userId,
}) {
  if (currentTypingUsers == null || !currentTypingUsers.containsKey(userId)) {
    return currentTypingUsers;
  }
  final next = Map<String, dynamic>.from(currentTypingUsers)..remove(userId);
  return next.isEmpty ? null : next;
}

class ChatTypingWriter {
  final String chatId;
  final String userId;
  final FirebaseFirestore firestore;

  Future<void> _writeQueue = Future<void>.value();

  ChatTypingWriter({
    required this.chatId,
    required this.userId,
    FirebaseFirestore? firestore,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> setTyping(bool isTyping) {
    final operation = _writeQueue.then((_) => _writeTypingState(isTyping));
    _writeQueue = operation.catchError((Object error, StackTrace stackTrace) {
      debugPrint('Typing state update failed for $chatId: $error\n$stackTrace');
    });
    return operation;
  }

  Future<void> _writeTypingState(bool isTyping) async {
    final chatRef = firestore.collection('chats').doc(chatId);
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(chatRef);
      if (!snapshot.exists) {
        throw StateError('Cannot update typing for missing chat $chatId.');
      }

      final chatData = snapshot.data() ?? const <String, dynamic>{};
      final rawTypingUsers = chatData[typingUsersField];
      final typingUsers = rawTypingUsers is Map
          ? Map<String, dynamic>.from(rawTypingUsers)
          : <String, dynamic>{};
      final nextTypingUsers = isTyping
          ? mergeTypingUserTimestamp(
              currentTypingUsers: typingUsers,
              userId: userId,
              timestamp: Timestamp.now(),
            )
          : removeTypingUser(currentTypingUsers: typingUsers, userId: userId);
      transaction.update(chatRef, {
        typingUsersField: nextTypingUsers ?? FieldValue.delete(),
      });
    });
  }
}

class TypingActivity {
  final Future<void> Function(bool isTyping) onTypingChanged;
  final void Function(Object error, StackTrace stackTrace)? onError;
  final Duration startDebounce;
  final Duration inactivityTimeout;
  final Duration refreshInterval;

  Timer? _startTimer;
  Timer? _inactivityTimer;
  Timer? _refreshTimer;
  bool _isTyping = false;
  bool _disposed = false;

  TypingActivity({
    required this.onTypingChanged,
    this.onError,
    this.startDebounce = const Duration(milliseconds: 350),
    this.inactivityTimeout = typingIndicatorTimeout,
    this.refreshInterval = const Duration(seconds: 2),
  });

  bool get isTyping => _isTyping;

  void onTextChanged(String text) {
    if (_disposed) return;
    if (text.trim().isEmpty) {
      unawaited(stop());
      return;
    }

    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(inactivityTimeout, () => unawaited(stop()));
    if (_isTyping) return;

    _startTimer ??= Timer(startDebounce, () {
      _startTimer = null;
      if (_disposed) return;
      _isTyping = true;
      _emit(true);
      _scheduleRefresh();
    });
  }

  Future<void> stop() async {
    _startTimer?.cancel();
    _startTimer = null;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    if (!_isTyping) return;
    _isTyping = false;
    await _emit(false);
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    if (_disposed || !_isTyping) return;
    _refreshTimer = Timer(refreshInterval, () {
      if (_disposed || !_isTyping) return;
      _emit(true);
      _scheduleRefresh();
    });
  }

  Future<void> _emit(bool isTyping) async {
    try {
      await onTypingChanged(isTyping);
    } catch (error, stackTrace) {
      onError?.call(error, stackTrace);
    }
  }

  void dispose() {
    if (_disposed) return;
    unawaited(stop());
    _disposed = true;
  }
}
