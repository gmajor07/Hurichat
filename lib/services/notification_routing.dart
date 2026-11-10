enum NotificationAppState { foreground, background, terminated }

enum NotificationDisplayOwner { local, operatingSystem }

NotificationDisplayOwner notificationDisplayOwnerFor(
  NotificationAppState state,
) => state == NotificationAppState.foreground
    ? NotificationDisplayOwner.local
    : NotificationDisplayOwner.operatingSystem;

class NotificationChatTarget {
  final String chatId;
  final String userId;

  const NotificationChatTarget({required this.chatId, required this.userId});
}

NotificationChatTarget? resolveNotificationChatTarget(
  Map<String, dynamic> data,
  String? currentUserId,
) {
  if (currentUserId == null || currentUserId.isEmpty) return null;

  final chatId = data['chatId']?.toString() ?? '';
  final senderId = data['senderId']?.toString() ?? '';
  final receiverId = data['receiverId']?.toString() ?? '';
  if (chatId.isEmpty || senderId.isEmpty || receiverId.isEmpty) return null;

  final peerId = switch (currentUserId) {
    final id when id == senderId => receiverId,
    final id when id == receiverId => senderId,
    _ => '',
  };
  if (peerId.isEmpty) return null;

  return NotificationChatTarget(chatId: chatId, userId: peerId);
}
