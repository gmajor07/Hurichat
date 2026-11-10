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
