import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/screens/chat/chat_widgets.dart';
import 'package:huruchat/screens/chat/pinned_message.dart';

void main() {
  group('pinned message data', () {
    test('pinning only adds the pinned message pointer', () {
      final existingChat = {
        'members': ['sender', 'receiver'],
        'lastMessage': 'Existing conversation',
        'unrelatedMetadata': {'value': 1},
      };
      final beforePin = Map<String, dynamic>.from(existingChat);
      final update = pinnedMessageUpdate('message-1');

      expect(update, {pinnedMessageIdField: 'message-1'});
      expect(existingChat, beforePin);
      expect(
        {...existingChat, ...update},
        {...beforePin, pinnedMessageIdField: 'message-1'},
      );
    });

    test('only persisted text, image, and voice messages can be pinned', () {
      for (final type in [null, 'text', 'image', 'voice']) {
        expect(
          canPinMessage({'firestoreId': 'message-$type', 'type': type}),
          isTrue,
        );
      }
      expect(
        canPinMessage({'localId': 'pending', 'text': 'Not persisted'}),
        isFalse,
      );
      expect(
        canPinMessage({'firestoreId': 'unsupported', 'type': 'location'}),
        isFalse,
      );
    });

    test('unpin clears only the pointer that was selected', () {
      expect(
        shouldClearPinnedMessage(
          currentMessageId: 'message-1',
          deletedMessageId: 'message-1',
        ),
        isTrue,
      );
      expect(
        shouldClearPinnedMessage(
          currentMessageId: 'message-2',
          deletedMessageId: 'message-1',
        ),
        isFalse,
      );
    });

    test('deleted or unset pinned IDs are treated as absent', () {
      expect(pinnedMessageIdFromChatData(null), isNull);
      expect(pinnedMessageIdFromChatData({}), isNull);
      expect(pinnedMessageIdFromChatData({pinnedMessageIdField: ''}), isNull);
      expect(
        pinnedMessageIdFromChatData({pinnedMessageIdField: 'message-1'}),
        'message-1',
      );
    });

    test('banner preview avoids exposing media URLs', () {
      expect(
        pinnedMessagePreview({'type': 'image', 'imageUrl': 'secret'}),
        'Photo',
      );
      expect(
        pinnedMessagePreview({'type': 'voice', 'audioUrl': 'secret'}),
        'Voice message',
      );
      expect(pinnedMessagePreview({'text': 'Pinned text'}), 'Pinned text');
    });

    test('pin update rejects an empty message ID', () {
      expect(() => pinnedMessageUpdate(''), throwsArgumentError);
    });
  });

  testWidgets('pinned banner tap invokes navigation callback', (tester) async {
    var navigated = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PinnedMessageBanner(
            preview: 'Pinned text',
            onTap: () => navigated = true,
          ),
        ),
      ),
    );

    expect(find.text('Pinned message'), findsOneWidget);
    expect(find.text('Pinned text'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pinned-message-banner')));
    expect(navigated, isTrue);
  });
}
