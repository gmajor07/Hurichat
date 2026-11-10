const forwardedMessageFields = [
  'isForwarded',
  'forwardedFrom',
  'forwardedFromMessageId',
];

Map<String, dynamic>? buildForwardedMessageFields({
  required Map<String, dynamic> original,
  required String forwardedFrom,
  required String forwardedFromMessageId,
}) {
  if (forwardedFrom.isEmpty || forwardedFromMessageId.isEmpty) return null;

  final type = original['type'];
  if (type == null || type == 'text') {
    final text = original['text'];
    if (text is! String || text.trim().isEmpty) return null;
    return {
      'text': text,
      'isForwarded': true,
      'forwardedFrom': forwardedFrom,
      'forwardedFromMessageId': forwardedFromMessageId,
    };
  }

  if (type == 'image') {
    final imageUrl = _validMediaUrl(original['imageUrl']);
    if (imageUrl == null) return null;
    return {
      'text': original['text'] is String ? original['text'] as String : 'Photo',
      'type': 'image',
      'imageUrl': imageUrl,
      'isForwarded': true,
      'forwardedFrom': forwardedFrom,
      'forwardedFromMessageId': forwardedFromMessageId,
    };
  }

  if (type == 'voice') {
    final audioUrl = _validMediaUrl(original['audioUrl']);
    final durationMillis = original['durationMillis'];
    if (audioUrl == null || durationMillis is! int || durationMillis < 0) {
      return null;
    }
    return {
      'text': original['text'] is String
          ? original['text'] as String
          : 'Voice message',
      'type': 'voice',
      'audioUrl': audioUrl,
      'durationMillis': durationMillis,
      'isForwarded': true,
      'forwardedFrom': forwardedFrom,
      'forwardedFromMessageId': forwardedFromMessageId,
    };
  }

  return null;
}

String? _validMediaUrl(dynamic value) {
  if (value is! String || value.trim().isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  return value;
}

Map<String, dynamic> forwardedMessageFieldsForMerge(
  Map<String, dynamic> messageData,
) {
  if (messageData['isForwarded'] != true) return const {};
  final sender = messageData['forwardedFrom'];
  final messageId = messageData['forwardedFromMessageId'];
  if (sender is! String ||
      sender.isEmpty ||
      messageId is! String ||
      messageId.isEmpty) {
    return const {};
  }
  return {
    'isForwarded': true,
    'forwardedFrom': sender,
    'forwardedFromMessageId': messageId,
  };
}

String? forwardedMessageId(Map<String, dynamic> message) {
  final originalId = message['forwardedFromMessageId'];
  if (message['isForwarded'] == true &&
      originalId is String &&
      originalId.isNotEmpty) {
    return originalId;
  }
  final firestoreId = message['firestoreId'];
  if (firestoreId is String && firestoreId.isNotEmpty) return firestoreId;
  return originalId is String && originalId.isNotEmpty ? originalId : null;
}

bool canForwardMessage(Map<String, dynamic> message) {
  final firestoreId = message['firestoreId'];
  if (firestoreId is! String || firestoreId.isEmpty) return false;
  final id = forwardedMessageId(message);
  if (id == null) return false;
  final sender = message['forwardedFrom'] is String
      ? message['forwardedFrom'] as String
      : message['senderId'];
  return sender is String &&
      buildForwardedMessageFields(
            original: message,
            forwardedFrom: sender,
            forwardedFromMessageId: id,
          ) !=
          null;
}

String forwardedMessageDescription(Map<String, dynamic> message) {
  return switch (message['type']) {
    'image' => 'Photo',
    'voice' => 'Voice message',
    _ => message['text'] is String ? message['text'] as String : 'Message',
  };
}
