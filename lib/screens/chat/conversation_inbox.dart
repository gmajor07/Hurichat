import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'conversation_draft.dart';

enum ConversationInboxFilter { all, unread, drafts }

List<Map<String, dynamic>> filterConversationInboxItems({
  required Iterable<Map<String, dynamic>> items,
  required ConversationInboxFilter filter,
  required Map<String, int> unreadCounts,
}) {
  return items.where((item) {
    return switch (filter) {
      ConversationInboxFilter.all => true,
      ConversationInboxFilter.unread => (unreadCounts[item['chatId']] ?? 0) > 0,
      ConversationInboxFilter.drafts => item['isDraft'] == true,
    };
  }).toList();
}

class ConversationUnreadCounts extends ChangeNotifier {
  final Stream<int> Function(String chatId) streamForChat;
  final Map<String, int> _counts = {};
  final Map<String, StreamSubscription<int>> _subscriptions = {};

  ConversationUnreadCounts({required this.streamForChat});

  Map<String, int> get counts => Map.unmodifiable(_counts);

  int countFor(String chatId) => _counts[chatId] ?? 0;

  void watch(Iterable<String> chatIds) {
    final activeIds = chatIds.toSet();
    for (final chatId in _subscriptions.keys.toList()) {
      if (activeIds.contains(chatId)) continue;
      unawaited(_subscriptions.remove(chatId)?.cancel());
      _counts.remove(chatId);
    }

    for (final chatId in activeIds) {
      if (_subscriptions.containsKey(chatId)) continue;
      _subscriptions[chatId] = streamForChat(chatId).listen(
        (unreadCount) {
          if (_counts[chatId] == unreadCount) return;
          _counts[chatId] = unreadCount;
          notifyListeners();
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Could not load unread count for $chatId: $error');
        },
      );
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions.values) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    _counts.clear();
    super.dispose();
  }
}

List<Map<String, dynamic>> buildConversationInboxItems({
  required String currentUserId,
  required Iterable<MapEntry<String, Map<String, dynamic>>> chats,
  required Map<String, Map<String, dynamic>> profiles,
  required Set<String> pinnedUserIds,
  Map<String, String> drafts = const {},
}) {
  final itemsByUserId = <String, Map<String, dynamic>>{};

  for (final chat in chats) {
    final members = chat.value['members'];
    if (members is! List) continue;

    final otherUserId = members.whereType<String>().firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
    if (otherUserId.isEmpty) continue;

    final profile = profiles[otherUserId] ?? const <String, dynamic>{};
    final rawName = profile['name'];
    final name = rawName is String && rawName.isNotEmpty ? rawName : 'Unknown';
    final rawTimestamp =
        chat.value['last_message_timestamp'] ??
        chat.value['lastTimestamp'] ??
        chat.value['timestamp'];
    final timestamp = switch (rawTimestamp) {
      Timestamp value => value.millisecondsSinceEpoch,
      int value => value,
      _ => 0,
    };
    final lastMessage = (chat.value['lastMessage'] ?? '').toString();
    final draft =
        drafts[conversationDraftKey(
          accountId: currentUserId,
          chatId: chat.key,
        )];
    final hasDraft = draft != null && draft.trim().isNotEmpty;

    itemsByUserId[otherUserId] = {
      'userId': otherUserId,
      'name': name[0].toUpperCase() + name.substring(1),
      'photoUrl': profile['photoUrl'] is String ? profile['photoUrl'] : '',
      'status': profile['status'] is String ? profile['status'] : 'offline',
      'chatId': chat.key,
      'lastMessage': hasDraft
          ? 'Draft: $draft'
          : lastMessage.isEmpty
          ? 'No messages yet'
          : lastMessage,
      'isDraft': hasDraft,
      'lastTimestamp': timestamp,
      'isPinned': pinnedUserIds.contains(otherUserId),
    };
  }

  return itemsByUserId.values.toList();
}
