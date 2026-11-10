import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/screens/chat/chat_widgets.dart';
import 'package:huruchat/screens/chat/forwarded_message.dart';

void main() {
  group('forwarded message data', () {
    final cases = <({String type, Map<String, dynamic> media})>[
      (type: 'text', media: {'text': 'Forwarded text'}),
      (
        type: 'image',
        media: {
          'type': 'image',
          'text': 'Photo',
          'imageUrl': 'https://storage.example/photo.jpg',
        },
      ),
      (
        type: 'voice',
        media: {
          'type': 'voice',
          'text': 'Voice message',
          'audioUrl': 'https://storage.example/voice.m4a',
          'durationMillis': 2400,
        },
      ),
    ];

    for (final item in cases) {
      test('builds forwarding fields for ${item.type}', () {
        final original = {
          'firestoreId': 'message-1',
          'senderId': 'original-sender',
          ...item.media,
        };
        final untouchedOriginal = Map<String, dynamic>.from(original);

        final fields = buildForwardedMessageFields(
          original: original,
          forwardedFrom: 'original-sender',
          forwardedFromMessageId: 'message-1',
        );

        expect(fields, isNotNull);
        expect(fields!['isForwarded'], isTrue);
        expect(fields['forwardedFrom'], 'original-sender');
        expect(fields['forwardedFromMessageId'], 'message-1');
        expect(original, untouchedOriginal);
        if (item.type != 'text') {
          expect(
            fields[item.type == 'image' ? 'imageUrl' : 'audioUrl'],
            item.media[item.type == 'image' ? 'imageUrl' : 'audioUrl'],
          );
        }
        if (item.type == 'voice') {
          expect(fields['durationMillis'], 2400);
        }
      });
    }

    test('rejects missing and malformed media URLs or duration', () {
      for (final invalid in [
        {'type': 'image', 'imageUrl': ''},
        {'type': 'image', 'imageUrl': 'file:///tmp/photo.jpg'},
        {'type': 'voice', 'audioUrl': 'not-a-url', 'durationMillis': 20},
        {
          'type': 'voice',
          'audioUrl': 'https://storage.example/voice.m4a',
          'durationMillis': -1,
        },
      ]) {
        expect(
          buildForwardedMessageFields(
            original: invalid,
            forwardedFrom: 'sender',
            forwardedFromMessageId: 'message',
          ),
          isNull,
        );
      }
    });

    test('requires a persisted message and valid forwardable content', () {
      expect(
        canForwardMessage({'senderId': 'sender', 'text': 'Pending'}),
        isFalse,
      );
      expect(
        canForwardMessage({
          'senderId': 'me',
          'isForwarded': true,
          'forwardedFrom': 'sender',
          'forwardedFromMessageId': 'original-id',
          'text': 'Pending forwarded copy',
        }),
        isFalse,
      );
      expect(
        canForwardMessage({
          'firestoreId': 'message-1',
          'senderId': 'sender',
          'type': 'voice',
          'audioUrl': 'invalid',
          'durationMillis': 10,
        }),
        isFalse,
      );
    });

    test('re-forward preserves the original sender and message ID', () {
      final forwarded = {
        'firestoreId': 'forwarded-copy-id',
        'senderId': 'current-user',
        'isForwarded': true,
        'forwardedFrom': 'original-sender',
        'forwardedFromMessageId': 'original-message-id',
        'text': 'Forwarded text',
      };

      expect(forwardedMessageId(forwarded), 'original-message-id');
      expect(
        buildForwardedMessageFields(
          original: forwarded,
          forwardedFrom: 'original-sender',
          forwardedFromMessageId: forwardedMessageId(forwarded)!,
        ),
        containsPair('forwardedFrom', 'original-sender'),
      );
    });

    test('merges valid forwarding metadata without replacing message data', () {
      final fields = forwardedMessageFieldsForMerge({
        'text': 'Forwarded text',
        'isForwarded': true,
        'forwardedFrom': 'sender',
        'forwardedFromMessageId': 'original-id',
      });

      expect(fields['isForwarded'], isTrue);
      expect(fields['forwardedFrom'], 'sender');
      expect(fields['forwardedFromMessageId'], 'original-id');
      expect(
        forwardedMessageFieldsForMerge({
          'isForwarded': true,
          'forwardedFrom': 'sender',
        }),
        isEmpty,
      );
    });
  });

  testWidgets('forwarded message bubble displays a Forwarded label', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessageTile(
            currentUserId: 'recipient',
            message: {
              'senderId': 'sender',
              'text': 'Forwarded text',
              'isForwarded': true,
              'forwardedFrom': 'original-sender',
              'forwardedFromMessageId': 'original-message',
            },
          ),
        ),
      ),
    );

    expect(find.text('Forwarded'), findsOneWidget);
  });

  testWidgets('text action menu invokes forwarding callback', (tester) async {
    var forwarded = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => GestureDetector(
              onLongPress: () => showTextMessageCopyMenu(
                context,
                globalPosition: const Offset(120, 120),
                text: 'Forward me',
                onForward: () => forwarded = true,
              ),
              child: const Text('Hold'),
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.text('Hold'));
    await tester.pumpAndSettle();
    expect(find.text('Forward'), findsOneWidget);
    await tester.tap(find.text('Forward'));
    await tester.pumpAndSettle();
    expect(forwarded, isTrue);
  });
}
