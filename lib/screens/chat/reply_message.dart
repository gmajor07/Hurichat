const replyToMessageIdField = 'replyToMessageId';
const replyToTypeField = 'replyToType';
const replyToTextField = 'replyToText';

Map<String, dynamic>? buildReplyMetadata(Map<String, dynamic> message) {
  final messageId = message['firestoreId'];
  if (messageId is! String || messageId.isEmpty) return null;

  final type = switch (message['type']) {
    'image' => 'image',
    'voice' => 'voice',
    _ => 'text',
  };
  final text = switch (type) {
    'image' => 'Photo',
    'voice' => 'Voice message',
    _ => message['text'] is String ? message['text'] as String : '',
  };

  return {
    replyToMessageIdField: messageId,
    replyToTypeField: type,
    replyToTextField: text,
  };
}

String replyPreviewText(Map<String, dynamic> message) {
  final text = message[replyToTextField];
  if (text is String && text.isNotEmpty) return text;
  return 'Message unavailable';
}

bool hasReplyMetadata(Map<String, dynamic> message) {
  return message[replyToMessageIdField] != null ||
      message[replyToTypeField] != null ||
      message[replyToTextField] != null;
}

String replyPreviewType(Map<String, dynamic> message) {
  return switch (message[replyToTypeField]) {
    'image' => 'image',
    'voice' => 'voice',
    _ => 'text',
  };
}
