List<Map<String, dynamic>> buildDiscoverableUserEntries({
  required Iterable<Map<String, dynamic>> users,
  required String currentUserId,
  required Set<String> connectedOrPendingIds,
}) {
  final entries = <Map<String, dynamic>>[];
  final seenIds = <String>{};

  for (final user in users) {
    final userId = (user['uid'] ?? '').toString();
    if (userId.isEmpty ||
        userId == currentUserId ||
        connectedOrPendingIds.contains(userId) ||
        !seenIds.add(userId)) {
      continue;
    }

    entries.add({
      'uid': userId,
      'name': (user['name'] ?? 'Huruchat User').toString(),
      'photoUrl': (user['photoUrl'] ?? '').toString(),
      'phone': '',
      'gender': '',
      'age': '',
      'isRegistered': true,
    });
  }

  return entries;
}
