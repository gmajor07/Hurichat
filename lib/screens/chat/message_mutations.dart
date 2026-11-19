bool canEditOwnTextMessage({
  required Map<String, dynamic> message,
  required String userId,
}) {
  return message['senderId'] == userId &&
      (message['type'] == null || message['type'] == 'text') &&
      message['firestoreId'] is String &&
      (message['firestoreId'] as String).isNotEmpty;
}

bool canDeleteOwnMessage({
  required Map<String, dynamic> message,
  required String userId,
}) {
  return message['senderId'] == userId;
}

String? normalizedEditedMessageText(String text) {
  final normalized = text.trim();
  return normalized.isEmpty ? null : normalized;
}

Map<String, dynamic> messageEditUpdateFields({
  required String text,
  required Object editedAt,
}) {
  return {'text': text, 'editedAt': editedAt};
}

/// Returns the messages that should be visible after the current user cleared
/// the conversation ("delete for me").
///
/// Confirmed messages whose `timestamp` (milliseconds since epoch) is at or
/// before [clearedAtMillis] are hidden. Pending local sends (those with a
/// `localId`) and messages without a numeric timestamp are always kept so a
/// message sent right after clearing still appears. When [clearedAtMillis] is
/// null the conversation was never cleared and every message is returned.
List<Map<String, dynamic>> conversationMessagesAfterCleared({
  required List<Map<String, dynamic>> messages,
  required int? clearedAtMillis,
}) {
  if (clearedAtMillis == null) return messages;
  return messages.where((message) {
    if (message['localId'] != null) return true;
    final timestamp = message['timestamp'];
    if (timestamp is! int) return true;
    return timestamp > clearedAtMillis;
  }).toList();
}
