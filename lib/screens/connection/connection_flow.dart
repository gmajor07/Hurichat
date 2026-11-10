typedef ConnectionEntry = MapEntry<String, Map<String, dynamic>>;

List<ConnectionEntry> filterConnectionsByStatus(
  Iterable<ConnectionEntry> entries,
  String status,
) {
  final seenIds = <String>{};
  return entries
      .where(
        (entry) => entry.value['status'] == status && seenIds.add(entry.key),
      )
      .toList();
}

Map<String, dynamic> contactProfileOrFallback(Map<String, dynamic>? profile) {
  final data = profile ?? const <String, dynamic>{};
  return {
    'name': data['name'] ?? 'Unknown User',
    'photoUrl': data['photoUrl'] ?? '',
    'phone': data['phone'] ?? '',
  };
}

class ConnectionRequestDocuments {
  final Map<String, dynamic> incoming;
  final Map<String, dynamic> outgoing;

  const ConnectionRequestDocuments({
    required this.incoming,
    required this.outgoing,
  });
}

ConnectionRequestDocuments createConnectionRequestDocuments({
  required String senderId,
  required String senderName,
  required String receiverId,
  required String receiverName,
  required Object timestamp,
}) {
  return ConnectionRequestDocuments(
    incoming: {
      'status': 'pending',
      'senderId': senderId,
      'senderName': senderName,
      'receiverId': receiverId,
      'timestamp': timestamp,
    },
    outgoing: {
      'status': 'sent',
      'senderId': senderId,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'timestamp': timestamp,
    },
  );
}

Future<bool> runConnectionActionOnce(
  Set<String> processingIds,
  String userId,
  Future<void> Function() action, {
  void Function()? onStateChanged,
}) async {
  if (!processingIds.add(userId)) return false;
  onStateChanged?.call();
  try {
    await action();
    return true;
  } finally {
    processingIds.remove(userId);
    onStateChanged?.call();
  }
}
