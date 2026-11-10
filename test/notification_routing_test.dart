import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/services/notification_routing.dart';

void main() {
  test('uses local display in foreground and system display otherwise', () {
    expect(
      notificationDisplayOwnerFor(NotificationAppState.foreground),
      NotificationDisplayOwner.local,
    );
    expect(
      notificationDisplayOwnerFor(NotificationAppState.background),
      NotificationDisplayOwner.operatingSystem,
    );
    expect(
      notificationDisplayOwnerFor(NotificationAppState.terminated),
      NotificationDisplayOwner.operatingSystem,
    );
  });

  test('resolves notification taps to the other conversation participant', () {
    final target = resolveNotificationChatTarget({
      'chatId': 'sender_receiver',
      'senderId': 'sender',
      'receiverId': 'receiver',
    }, 'receiver');

    expect(target?.chatId, 'sender_receiver');
    expect(target?.userId, 'sender');
  });

  test('ignores a tap without a valid conversation target', () {
    expect(resolveNotificationChatTarget({}, 'receiver'), isNull);
    expect(
      resolveNotificationChatTarget({
        'chatId': 'sender_receiver',
        'senderId': 'sender',
        'receiverId': 'receiver',
      }, 'stranger'),
      isNull,
    );
  });
}
