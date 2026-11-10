import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

String conversationDraftKey({
  required String accountId,
  required String chatId,
}) {
  final encodedAccount = base64Url.encode(utf8.encode(accountId));
  final encodedChat = base64Url.encode(utf8.encode(chatId));
  return '$encodedAccount:$encodedChat';
}

class ConversationDraftStore {
  final Box box;
  final String key;

  ConversationDraftStore({
    required this.box,
    required String accountId,
    required String chatId,
  }) : key = conversationDraftKey(accountId: accountId, chatId: chatId);

  String? load() {
    final value = box.get(key);
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  Future<void> save(String text) async {
    if (text.trim().isEmpty) {
      await box.delete(key);
      return;
    }
    await box.put(key, text);
  }

  Future<void> clear() => box.delete(key);

  Future<bool> clearIfMatches(String sentText) async {
    final draft = box.get(key);
    if (draft is! String || draft.trim() != sentText.trim()) return false;
    await box.delete(key);
    return true;
  }
}

class ConversationDraftPersistence {
  final ConversationDraftStore store;
  final Duration debounceDuration;
  final void Function(Object error, StackTrace stackTrace)? onError;

  Timer? _timer;
  Future<void> _writeQueue = Future<void>.value();
  String? _latestText;
  bool _disposed = false;

  ConversationDraftPersistence({
    required this.store,
    this.debounceDuration = const Duration(milliseconds: 300),
    this.onError,
  });

  String? restore() {
    final draft = store.load();
    _latestText ??= draft ?? '';
    return draft;
  }

  void onTextChanged(String text) {
    if (_disposed) return;
    _latestText = text;
    _timer?.cancel();
    if (text.trim().isEmpty) {
      unawaited(_enqueue(store.clear));
      return;
    }
    _timer = Timer(debounceDuration, () {
      unawaited(_enqueue(() => store.save(text)));
    });
  }

  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    final text = _latestText;
    if (text == null) return _writeQueue;
    return _enqueue(() => store.save(text));
  }

  Future<void> clearAfterSuccessfulSend(String sentText) async {
    await flush();
    final currentText = _latestText;
    if (currentText == null || currentText.trim() != sentText.trim()) return;
    var cleared = false;
    await _enqueue(() async {
      cleared = await store.clearIfMatches(sentText);
    });
    if (cleared) _latestText = '';
  }

  Future<void> dispose() {
    if (_disposed) return _writeQueue;
    _disposed = true;
    return flush();
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    _writeQueue = _writeQueue.then((_) => operation()).catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      debugPrint('Could not persist conversation draft: $error\n$stackTrace');
      onError?.call(error, stackTrace);
    });
    return _writeQueue;
  }
}
