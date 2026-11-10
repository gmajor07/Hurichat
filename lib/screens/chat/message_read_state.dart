import 'package:cloud_firestore/cloud_firestore.dart';

bool isUnreadIncomingMessage(
  Map<String, dynamic> message,
  String currentUserId,
) {
  return message['receiverId'] == currentUserId && message['isRead'] == false;
}

int countUnreadIncomingMessages(
  Iterable<Map<String, dynamic>> messages,
  String currentUserId,
) {
  return messages
      .where((message) => isUnreadIncomingMessage(message, currentUserId))
      .length;
}

Map<String, Map<String, bool>> buildReadReceiptUpdates(
  Iterable<MapEntry<String, Map<String, dynamic>>> messages,
  String currentUserId,
) {
  return {
    for (final message in messages)
      if (isUnreadIncomingMessage(message.value, currentUserId))
        message.key: const {'isRead': true},
  };
}

bool hasReadReceipt(Map<String, dynamic> message) => message['isRead'] == true;

int messageTimestampMillis(dynamic timestamp) {
  return switch (timestamp) {
    Timestamp value => value.millisecondsSinceEpoch,
    DateTime value => value.millisecondsSinceEpoch,
    int value => value,
    _ => 0,
  };
}
