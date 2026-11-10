class SharedMediaItem {
  final String id;
  final Map<String, dynamic> data;

  const SharedMediaItem({required this.id, required this.data});

  String get type => data['type'] as String;

  String get mediaUrl =>
      data[type == 'image' ? 'imageUrl' : 'audioUrl'] as String;

  int get durationMillis => data['durationMillis'] as int? ?? 0;
}

bool _isHttpUrl(Object? value) {
  if (value is! String || value.trim().isEmpty) return false;
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.hasAuthority &&
      uri.host.isNotEmpty &&
      (uri.scheme == 'http' || uri.scheme == 'https');
}

int _timestampMillis(Object? timestamp) {
  return switch (timestamp) {
    DateTime value => value.millisecondsSinceEpoch,
    int value => value,
    _ => _timestampFromFirestoreValue(timestamp),
  };
}

int _timestampFromFirestoreValue(Object? value) {
  try {
    final dynamic timestamp = value;
    final milliseconds = timestamp.millisecondsSinceEpoch;
    return milliseconds is int ? milliseconds : 0;
  } on NoSuchMethodError {
    return 0;
  }
}

List<SharedMediaItem> filterSharedMediaItems(
  Iterable<SharedMediaItem> items, {
  String? type,
}) {
  final filtered = items.where((item) {
    if (type != null && item.type != type) return false;
    if (item.type == 'image') return _isHttpUrl(item.data['imageUrl']);
    if (item.type == 'voice') {
      return _isHttpUrl(item.data['audioUrl']) &&
          item.data['durationMillis'] is int &&
          item.durationMillis >= 0;
    }
    return false;
  }).toList();
  filtered.sort((left, right) {
    final byTime = _timestampMillis(
      left.data['timestamp'],
    ).compareTo(_timestampMillis(right.data['timestamp']));
    return byTime != 0 ? byTime : left.id.compareTo(right.id);
  });
  return filtered;
}

List<SharedMediaItem> mergeSharedMediaPage({
  required Iterable<SharedMediaItem> current,
  required Iterable<SharedMediaItem> nextPage,
}) {
  final byId = <String, SharedMediaItem>{
    for (final item in current) item.id: item,
    for (final item in nextPage) item.id: item,
  };
  return filterSharedMediaItems(byId.values);
}

bool hasMoreSharedMediaPage(int rawMessageCount, {required int pageSize}) {
  return rawMessageCount >= pageSize;
}

String formatSharedMediaDuration(int durationMillis) {
  final totalSeconds = durationMillis ~/ 1000;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
