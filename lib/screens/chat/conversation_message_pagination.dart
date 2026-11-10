import 'message_read_state.dart';

const int conversationMessagePageSize = 30;

bool isNearConversationStart(double pixels, {double threshold = 120}) {
  return pixels <= threshold;
}

double preserveConversationScrollOffset({
  required double previousPixels,
  required double previousMaxExtent,
  required double currentMinExtent,
  required double currentMaxExtent,
}) {
  final insertedExtent = currentMaxExtent - previousMaxExtent;
  return (previousPixels + insertedExtent)
      .clamp(currentMinExtent, currentMaxExtent)
      .toDouble();
}

bool pageHasMoreMessages(
  int loadedCount, {
  int pageSize = conversationMessagePageSize,
}) {
  return loadedCount >= pageSize;
}

int compareConversationMessageEntries(
  MapEntry<String, Map<String, dynamic>> left,
  MapEntry<String, Map<String, dynamic>> right,
) {
  final byTimestamp = messageTimestampMillis(
    left.value['timestamp'],
  ).compareTo(messageTimestampMillis(right.value['timestamp']));
  if (byTimestamp != 0) return byTimestamp;
  return left.key.compareTo(right.key);
}

List<MapEntry<String, Map<String, dynamic>>> mergeAndSortMessagePages(
  Iterable<Iterable<MapEntry<String, Map<String, dynamic>>>> pages,
) {
  final entriesById = <String, Map<String, dynamic>>{};
  for (final page in pages) {
    for (final entry in page) {
      entriesById[entry.key] = entry.value;
    }
  }
  final entries = entriesById.entries.toList()
    ..sort(compareConversationMessageEntries);
  return entries;
}

class OlderMessagePageLoadGuard {
  bool isLoading = false;

  Future<T?> run<T>(Future<T> Function() load) async {
    if (isLoading) return null;
    isLoading = true;
    try {
      return await load();
    } finally {
      isLoading = false;
    }
  }
}
