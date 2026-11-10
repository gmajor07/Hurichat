import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/screens/chat/message_read_state.dart';

void main() {
  final messages = <MapEntry<String, Map<String, dynamic>>>[
    MapEntry('incoming-unread', {
      'senderId': 'peer',
      'receiverId': 'me',
      'isRead': false,
    }),
    MapEntry('incoming-read', {
      'senderId': 'peer',
      'receiverId': 'me',
      'isRead': true,
    }),
    MapEntry('outgoing-unread', {
      'senderId': 'me',
      'receiverId': 'peer',
      'isRead': false,
    }),
    MapEntry('missing-read-state', {'senderId': 'peer', 'receiverId': 'me'}),
  ];

  test('counts only explicitly unread messages received by this user', () {
    expect(
      countUnreadIncomingMessages(messages.map((entry) => entry.value), 'me'),
      1,
    );
    expect(
      countUnreadIncomingMessages(
        messages.map((entry) => entry.value),
        'someone-else',
      ),
      0,
    );
  });

  test('read updates affect only unread incoming messages in this chat', () {
    expect(buildReadReceiptUpdates(messages, 'me'), {
      'incoming-unread': const {'isRead': true},
    });
  });

  test('read receipt indicator is true only after recipient read', () {
    expect(hasReadReceipt({'isRead': true}), isTrue);
    expect(hasReadReceipt({'isRead': false}), isFalse);
    expect(hasReadReceipt({}), isFalse);
  });

  test('missing message timestamps sort safely as zero', () {
    expect(messageTimestampMillis(null), 0);
    expect(messageTimestampMillis('invalid'), 0);
    expect(messageTimestampMillis(123), 123);
    expect(
      messageTimestampMillis(Timestamp.fromMillisecondsSinceEpoch(456)),
      456,
    );
  });
}
