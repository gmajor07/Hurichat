const String pinnedMessageIdField = 'pinnedMessageId';

String? pinnedMessageIdFromChatData(Map<String, dynamic>? chatData) {
  final messageId = chatData?[pinnedMessageIdField];
  return messageId is String && messageId.isNotEmpty ? messageId : null;
}

bool canPinMessage(Map<String, dynamic> message) {
  final messageId = message['firestoreId'];
  final type = message['type'];
  return messageId is String &&
      messageId.isNotEmpty &&
      (type == null || type == 'text' || type == 'image' || type == 'voice');
}

Map<String, dynamic> pinnedMessageUpdate(String messageId) {
  if (messageId.isEmpty) {
    throw ArgumentError.value(messageId, 'messageId', 'Must not be empty');
  }
  return {pinnedMessageIdField: messageId};
}

bool shouldClearPinnedMessage({
  required String? currentMessageId,
  required String deletedMessageId,
}) {
  return currentMessageId == deletedMessageId;
}

String pinnedMessagePreview(Map<String, dynamic> message) {
  return switch (message['type']) {
    'image' => 'Photo',
    'voice' => 'Voice message',
    _ =>
      message['text'] is String && (message['text'] as String).isNotEmpty
          ? message['text'] as String
          : 'Message',
  };
}
