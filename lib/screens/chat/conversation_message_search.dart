class ConversationMessageSearchResult {
  final String messageId;
  final int messageIndex;
  final Map<String, dynamic> message;
  final String preview;

  const ConversationMessageSearchResult({
    required this.messageId,
    required this.messageIndex,
    required this.message,
    required this.preview,
  });
}

String conversationMessageId(Map<String, dynamic> message, int index) {
  final firestoreId = message['firestoreId'];
  if (firestoreId is String && firestoreId.isNotEmpty) return firestoreId;
  final localId = message['localId'];
  if (localId is String && localId.isNotEmpty) return localId;
  return 'message-$index';
}

List<ConversationMessageSearchResult> searchConversationMessages({
  required List<Map<String, dynamic>> messages,
  required String query,
  int previewLength = 100,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) return const [];

  final results = <ConversationMessageSearchResult>[];
  for (var index = 0; index < messages.length; index++) {
    final message = messages[index];
    if (message['type'] == 'voice') continue;
    final text = message['text'];
    if (text is! String || !text.toLowerCase().contains(normalizedQuery)) {
      continue;
    }

    results.add(
      ConversationMessageSearchResult(
        messageId: conversationMessageId(message, index),
        messageIndex: index,
        message: message,
        preview: _messagePreview(text, normalizedQuery, previewLength),
      ),
    );
  }
  return results;
}

String _messagePreview(String text, String query, int maxLength) {
  if (maxLength <= 0 || text.length <= maxLength) return text;
  final matchIndex = text.toLowerCase().indexOf(query);
  final start = (matchIndex - (maxLength ~/ 3)).clamp(
    0,
    text.length - maxLength,
  );
  final end = start + maxLength;
  return '${start > 0 ? '…' : ''}${text.substring(start, end)}'
      '${end < text.length ? '…' : ''}';
}
