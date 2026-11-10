import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/screens/chat/chat_widgets.dart';
import 'package:huruchat/screens/chat/message_reactions.dart';

void main() {
  test('adding a reaction assigns it to the current user', () {
    expect(
      reactionValueAfterToggle(
        reactions: const {},
        userId: 'user-1',
        emoji: '👍',
      ),
      '👍',
    );
  });

  test('changing a reaction replaces the user reaction', () {
    expect(
      reactionValueAfterToggle(
        reactions: const {'user-1': '👍'},
        userId: 'user-1',
        emoji: '❤️',
      ),
      '❤️',
    );
  });

  test('selecting the same reaction removes it', () {
    expect(
      reactionValueAfterToggle(
        reactions: const {'user-1': '👍'},
        userId: 'user-1',
        emoji: '👍',
      ),
      isNull,
    );
  });

  test('one user has one reaction while multiple users are counted', () {
    final reactions = normalizeMessageReactions({
      'user-1': '👍',
      'user-2': '👍',
      'user-3': '❤️',
      'invalid-user': '🔥',
    });

    expect(reactions, {'user-1': '👍', 'user-2': '👍', 'user-3': '❤️'});
    expect(countMessageReactions(reactions), {'👍': 2, '❤️': 1});
  });

  test('missing reaction field is compatible with older message documents', () {
    expect(normalizeMessageReactions(null), isEmpty);
    expect(countMessageReactions(null), isEmpty);
    expect(messageReactionFieldsForMerge({'text': 'Older message'}), isEmpty);
  });

  test('stored reactions are retained when message documents are merged', () {
    expect(
      messageReactionFieldsForMerge({
        'text': 'Message',
        'replyToMessageId': 'original-1',
        'replyToText': 'Quoted text',
        'reactions': {'user-1': '👍', 'user-2': '❤️'},
      }),
      {
        'reactions': {'user-1': '👍', 'user-2': '❤️'},
      },
    );
  });

  testWidgets('reaction picker contains the six supported emojis', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showMessageReactionPicker(
                context,
                onSelected: (emoji) => selected = emoji,
              ),
              child: const Text('Open picker'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    for (final emoji in messageReactionEmojis) {
      expect(find.byTooltip(emoji), findsOneWidget);
    }

    await tester.tap(find.byTooltip('😂'));
    await tester.pumpAndSettle();
    expect(selected, '😂');
  });

  testWidgets('text-message action menu exposes React', (tester) async {
    var pickerOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => GestureDetector(
              onLongPressStart: (details) => showTextMessageCopyMenu(
                context,
                globalPosition: details.globalPosition,
                text: 'Message',
                onReact: () => pickerOpened = true,
              ),
              child: const Text('Message'),
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.text('Message'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('React'));
    await tester.pumpAndSettle();

    expect(pickerOpened, isTrue);
  });

  for (final type in ['text', 'image', 'voice']) {
    testWidgets('$type message displays reaction counts and allows toggling', (
      tester,
    ) async {
      String? selected;
      final message = <String, dynamic>{
        'senderId': 'peer',
        'type': type,
        'text': 'A message',
        'imageUrl': 'invalid-image-url',
        'audioUrl': '',
        'durationMillis': 1200,
        'reactions': {'me': '👍', 'peer': '👍', 'another-user': '❤️'},
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageTile(
              currentUserId: 'me',
              message: message,
              onReactionTap: (emoji) => selected = emoji,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('👍'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('❤️'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('👍'));
      expect(selected, '👍');
    });
  }
}
