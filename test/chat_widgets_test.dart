import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/screens/chat/chat_widgets.dart';

void main() {
  testWidgets('message input uses sentence capitalization', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageTextField(
            controller: controller,
            enabled: true,
            onSubmitted: (_) {},
            backgroundColor: Colors.white,
          ),
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.textCapitalization, TextCapitalization.sentences);
    expect(field.maxLines, isNull);
    expect(field.textInputAction, TextInputAction.newline);
  });

  testWidgets('long sender message stays within 70% bubble width', (
    tester,
  ) async {
    await _pumpMessage(tester, _textMessage(senderId: 'me'));

    final bubbleSize = tester.getSize(
      find.byKey(const ValueKey('message-bubble')),
    );
    final bubblePosition = tester.getTopLeft(
      find.byKey(const ValueKey('message-bubble')),
    );
    final chatArea = tester.getRect(
      find.byKey(const ValueKey('test-chat-area')),
    );

    expect(
      bubbleSize.width,
      lessThanOrEqualTo((chatArea.width - 24) * 0.7 + 0.1),
    );
    expect(bubbleSize.height, greaterThan(40));
    expect(
      bubblePosition.dx + bubbleSize.width,
      closeTo(chatArea.right - 12, 1),
    );
  });

  testWidgets('long receiver message stays within 70% bubble width', (
    tester,
  ) async {
    await _pumpMessage(tester, _textMessage(senderId: 'peer'));

    final bubbleSize = tester.getSize(
      find.byKey(const ValueKey('message-bubble')),
    );
    final bubblePosition = tester.getTopLeft(
      find.byKey(const ValueKey('message-bubble')),
    );

    expect(bubbleSize.width, lessThanOrEqualTo((400 - 24) * 0.7 + 0.1));
    expect(bubbleSize.height, greaterThan(40));
    expect(bubblePosition.dx, greaterThan(12));
  });

  testWidgets('short messages stay compact', (tester) async {
    await _pumpMessage(tester, _textMessage(senderId: 'me', text: 'Hi'));

    final bubbleSize = tester.getSize(
      find.byKey(const ValueKey('message-bubble')),
    );
    expect(bubbleSize.width, lessThan(100));
  });

  for (final senderId in ['me', 'peer']) {
    testWidgets('long-press copies a text message sent by $senderId', (
      tester,
    ) async {
      final clipboardCalls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          clipboardCalls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      const messageText = 'Copy this exact message';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: MessageTile(
                  message: {
                    'senderId': senderId,
                    'text': messageText,
                    'timestamp': DateTime.now().millisecondsSinceEpoch,
                  },
                  currentUserId: 'me',
                  onTextLongPressStart: (position) {
                    showTextMessageCopyMenu(
                      tester.element(find.byType(MessageTile)),
                      globalPosition: position,
                      text: messageText,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.longPress(find.byKey(const ValueKey('message-bubble')));
      await tester.pumpAndSettle();
      expect(find.text('Copy Message'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Forward'), findsNothing);
      expect(find.text('React'), findsNothing);

      await tester.tap(find.text('Copy Message'));
      await tester.pumpAndSettle();

      final clipboardCall = clipboardCalls.singleWhere(
        (call) => call.method == 'Clipboard.setData',
      );
      expect(clipboardCall.arguments['text'], messageText);
      expect(find.text('Message copied'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('scrolling a message list does not open the text action menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: 20,
            itemBuilder: (context, index) {
              if (index != 0) return Text('Message $index');
              return MessageTile(
                message: _textMessage(senderId: 'me'),
                currentUserId: 'me',
                onTextLongPressStart: (position) {
                  showTextMessageCopyMenu(
                    context,
                    globalPosition: position,
                    text: 'message',
                  );
                },
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.pixels, greaterThan(0));
    expect(find.text('Copy Message'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('image message and read receipt render within bubble width', (
    tester,
  ) async {
    await _pumpMessage(tester, {
      'senderId': 'me',
      'type': 'image',
      'imageUrl': 'file:///unavailable',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isRead': true,
    });

    final bubbleSize = tester.getSize(
      find.byKey(const ValueKey('message-bubble')),
    );
    expect(bubbleSize.width, lessThanOrEqualTo((400 - 24) * 0.7 + 0.1));
    expect(find.text('Image unavailable'), findsOneWidget);
    expect(find.byTooltip('Read'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('image message fits a narrow chat area', (tester) async {
    await _pumpMessage(tester, {
      'senderId': 'me',
      'type': 'image',
      'imageUrl': 'file:///unavailable',
      'isRead': false,
    }, width: 320);

    final bubbleSize = tester.getSize(
      find.byKey(const ValueKey('message-bubble')),
    );
    final chatArea = tester.getSize(
      find.byKey(const ValueKey('test-chat-area')),
    );

    expect(
      bubbleSize.width,
      lessThanOrEqualTo((chatArea.width - 24) * 0.7 + 0.1),
    );
    expect(tester.takeException(), isNull);
  });
}

Map<String, dynamic> _textMessage({
  required String senderId,
  String text =
      'A long message that should wrap onto several lines without stretching '
      'the conversation bubble beyond the available maximum width.',
}) {
  return {
    'senderId': senderId,
    'text': text,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'isRead': false,
  };
}

Future<void> _pumpMessage(
  WidgetTester tester,
  Map<String, dynamic> message, {
  double width = 400,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            key: const ValueKey('test-chat-area'),
            width: width,
            child: MessageTile(message: message, currentUserId: 'me'),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
