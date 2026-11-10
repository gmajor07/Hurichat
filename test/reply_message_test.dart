import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/screens/chat/chat_widgets.dart';
import 'package:huruchat/screens/chat/reply_message.dart';

void main() {
  for (final senderId in ['me', 'peer']) {
    test('builds a reply snapshot for a message sent by $senderId', () {
      expect(
        buildReplyMetadata({
          'firestoreId': 'original-1',
          'senderId': senderId,
          'text': 'Original message',
          'type': 'text',
        }),
        {
          replyToMessageIdField: 'original-1',
          replyToTypeField: 'text',
          replyToTextField: 'Original message',
        },
      );
    });
  }

  test('builds display snapshots for image and voice messages', () {
    expect(buildReplyMetadata({'firestoreId': 'photo-1', 'type': 'image'}), {
      replyToMessageIdField: 'photo-1',
      replyToTypeField: 'image',
      replyToTextField: 'Photo',
    });
    expect(buildReplyMetadata({'firestoreId': 'voice-1', 'type': 'voice'}), {
      replyToMessageIdField: 'voice-1',
      replyToTypeField: 'voice',
      replyToTextField: 'Voice message',
    });
  });

  test(
    'does not create reply metadata for a message without a Firestore ID',
    () {
      expect(
        buildReplyMetadata({'localId': 'local-1', 'text': 'Pending'}),
        isNull,
      );
    },
  );

  test('missing quote data renders as unavailable', () {
    expect(replyPreviewText({}), 'Message unavailable');
  });

  for (final quote in [
    ('text', 'Quoted text'),
    ('image', 'Photo'),
    ('voice', 'Voice message'),
  ]) {
    testWidgets('${quote.$1} reply quote renders its saved preview', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageTile(
              currentUserId: 'me',
              message: {
                'senderId': 'peer',
                'text': 'A reply',
                replyToTypeField: quote.$1,
                replyToTextField: quote.$2,
              },
            ),
          ),
        ),
      );

      expect(find.text(quote.$2), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reply composer can be cancelled', (tester) async {
    var cancelled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReplyMessagePreview(
            type: 'text',
            text: 'Quoted text',
            isComposer: true,
            onCancel: () => cancelled = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Cancel reply'));
    expect(cancelled, isTrue);
  });

  for (final senderId in ['me', 'peer']) {
    testWidgets('reply action selects a text message sent by $senderId', (
      tester,
    ) async {
      Map<String, dynamic>? selectedReply;
      final message = {
        'firestoreId': 'original-$senderId',
        'senderId': senderId,
        'text': 'Original message',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageTile(
              currentUserId: 'me',
              message: message,
              onTextLongPressStart: (position) {
                showTextMessageCopyMenu(
                  tester.element(find.byType(MessageTile)),
                  globalPosition: position,
                  text: 'Original message',
                  onReply: () => selectedReply = buildReplyMetadata(message),
                );
              },
            ),
          ),
        ),
      );

      await tester.longPress(find.byKey(const ValueKey('message-bubble')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reply'));
      await tester.pumpAndSettle();

      expect(selectedReply?[replyToMessageIdField], 'original-$senderId');
      expect(selectedReply?[replyToTextField], 'Original message');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reply quote invokes navigation when its original is loaded', (
    tester,
  ) async {
    String? navigatedTo;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageTile(
            currentUserId: 'me',
            message: {
              'senderId': 'peer',
              'text': 'A reply',
              replyToMessageIdField: 'original-1',
              replyToTypeField: 'image',
              replyToTextField: 'Photo',
            },
            onReplyTap: (messageId) => navigatedTo = messageId,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Photo'));
    expect(navigatedTo, 'original-1');
  });

  testWidgets('reply quote remains visible when original is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageTile(
            currentUserId: 'me',
            message: {
              'senderId': 'me',
              'text': 'A reply',
              replyToMessageIdField: 'deleted-original',
            },
          ),
        ),
      ),
    );

    expect(find.text('Message unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
