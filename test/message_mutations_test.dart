import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/screens/chat/chat_widgets.dart';
import 'package:huruchat/screens/chat/message_mutations.dart';

void main() {
  group('message ownership and edit policy', () {
    test('only own text messages with Firestore IDs can be edited', () {
      expect(
        canEditOwnTextMessage(
          message: {
            'senderId': 'me',
            'type': 'text',
            'firestoreId': 'message-1',
          },
          userId: 'me',
        ),
        isTrue,
      );
      expect(
        canEditOwnTextMessage(
          message: {
            'senderId': 'peer',
            'type': 'text',
            'firestoreId': 'message-2',
          },
          userId: 'me',
        ),
        isFalse,
      );
      expect(
        canEditOwnTextMessage(
          message: {
            'senderId': 'me',
            'type': 'image',
            'firestoreId': 'message-3',
          },
          userId: 'me',
        ),
        isFalse,
      );
    });

    test('own text, image, and voice messages can be deleted', () {
      for (final type in ['text', 'image', 'voice']) {
        expect(
          canDeleteOwnMessage(
            message: {'senderId': 'me', 'type': type},
            userId: 'me',
          ),
          isTrue,
        );
      }
      expect(
        canDeleteOwnMessage(
          message: {'senderId': 'peer', 'type': 'voice'},
          userId: 'me',
        ),
        isFalse,
      );
    });

    test('edit text trims whitespace and rejects empty edits', () {
      expect(normalizedEditedMessageText('  revised  '), 'revised');
      expect(normalizedEditedMessageText('  '), isNull);
    });

    test('edit update contains only text and editedAt fields', () {
      expect(
        messageEditUpdateFields(text: 'revised', editedAt: 'server-time'),
        {'text': 'revised', 'editedAt': 'server-time'},
      );
    });
  });

  testWidgets('edit action invokes edit callback', (tester) async {
    var startedEditing = false;
    await _openTextActionMenu(tester, onEdit: () => startedEditing = true);

    expect(find.text('Edit'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(startedEditing, isTrue);
  });

  testWidgets('delete action invokes the confirmation flow callback', (
    tester,
  ) async {
    var confirmationStarted = false;
    await _openTextActionMenu(
      tester,
      onDelete: () => confirmationStarted = true,
    );

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(confirmationStarted, isTrue);
  });

  testWidgets('deletion confirmation can be cancelled', (tester) async {
    final result = await _showConfirmation(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await result.future, isFalse);
  });

  testWidgets('deletion confirmation requires explicit confirmation', (
    tester,
  ) async {
    final result = await _showConfirmation(tester);
    expect(find.text('Delete message?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(await result.future, isTrue);
  });

  testWidgets('edit banner can cancel editing', (tester) async {
    var cancelled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageEditBanner(onCancel: () => cancelled = true),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Cancel edit'));
    expect(cancelled, isTrue);
  });

  testWidgets('edited message displays Edited label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageTile(
            currentUserId: 'me',
            message: {
              'senderId': 'me',
              'text': 'Updated text',
              'timestamp': 1,
              'editedAt': 123,
            },
          ),
        ),
      ),
    );

    expect(find.text('Edited'), findsOneWidget);
  });
}

Future<void> _openTextActionMenu(
  WidgetTester tester, {
  VoidCallback? onEdit,
  VoidCallback? onDelete,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => GestureDetector(
            onLongPressStart: (details) => showTextMessageCopyMenu(
              context,
              globalPosition: details.globalPosition,
              text: 'Message',
              onEdit: onEdit,
              onDelete: onDelete,
            ),
            child: const Text('Message'),
          ),
        ),
      ),
    ),
  );
  await tester.longPress(find.text('Message'));
  await tester.pumpAndSettle();
}

Future<Completer<bool>> _showConfirmation(WidgetTester tester) async {
  final result = Completer<bool>();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () {
              confirmMessageDeletion(context).then(result.complete);
            },
            child: const Text('Prompt'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Prompt'));
  await tester.pumpAndSettle();
  return result;
}
