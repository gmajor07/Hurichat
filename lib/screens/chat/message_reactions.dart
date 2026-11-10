const messageReactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

Map<String, String> normalizeMessageReactions(dynamic raw) {
  if (raw is! Map) return const {};

  return {
    for (final entry in raw.entries)
      if (entry.key is String &&
          entry.value is String &&
          messageReactionEmojis.contains(entry.value))
        entry.key as String: entry.value as String,
  };
}

Map<String, dynamic> messageReactionFieldsForMerge(
  Map<String, dynamic> messageData,
) {
  final rawReactions = messageData['reactions'];
  if (rawReactions is! Map) return const {};
  return {'reactions': normalizeMessageReactions(rawReactions)};
}

String? reactionValueAfterToggle({
  required Map<String, String> reactions,
  required String userId,
  required String emoji,
}) {
  if (!messageReactionEmojis.contains(emoji)) {
    throw ArgumentError.value(emoji, 'emoji', 'Unsupported reaction');
  }
  return reactions[userId] == emoji ? null : emoji;
}

Map<String, int> countMessageReactions(dynamic raw) {
  final counts = <String, int>{};
  for (final emoji in normalizeMessageReactions(raw).values) {
    counts.update(emoji, (count) => count + 1, ifAbsent: () => 1);
  }
  return counts;
}
