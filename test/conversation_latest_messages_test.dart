import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/screens/chat/conversation_latest_messages.dart';

void main() {
  test('detects when scrolling away from and near the latest message', () {
    final state = ConversationLatestMessages();
    addTearDown(state.dispose);
    state.markInitialMessagesLoaded();

    state.updateScrollPosition(pixels: 500, maxScrollExtent: 1000);
    expect(state.isNearLatest, isFalse);
    expect(state.shouldShowButton, isTrue);

    state.updateScrollPosition(pixels: 940, maxScrollExtent: 1000);
    expect(state.isNearLatest, isTrue);
    expect(state.shouldShowButton, isFalse);
  });

  test('records distinct incoming messages only while reading history', () {
    final state = ConversationLatestMessages();
    addTearDown(state.dispose);
    state.markInitialMessagesLoaded();
    state.updateScrollPosition(pixels: 200, maxScrollExtent: 1000);

    final messages = [
      const MapEntry('incoming-1', 'peer'),
      const MapEntry('incoming-1', 'peer'),
      const MapEntry('outgoing-1', 'me'),
      const MapEntry('', 'peer'),
    ];
    state.recordIncomingMessages(messages, currentUserId: 'me');

    expect(state.newMessageCount, 1);
    expect(state.shouldShowNewMessageIndicator, isTrue);
    expect(state.shouldShowButton, isTrue);
  });

  test('initial messages do not produce a new-message indicator', () {
    final state = ConversationLatestMessages();
    addTearDown(state.dispose);

    state.recordIncomingMessages(const [
      MapEntry('initial-incoming', 'peer'),
    ], currentUserId: 'me');
    state.markInitialMessagesLoaded();

    expect(state.newMessageCount, 0);
    expect(state.shouldShowButton, isFalse);
  });

  test('does not auto-scroll while reading history', () {
    expect(
      shouldFollowLatestMessages(
        isInitialSnapshot: false,
        hasAddedMessages: true,
        wasNearLatest: false,
      ),
      isFalse,
    );
    expect(
      shouldFollowLatestMessages(
        isInitialSnapshot: false,
        hasAddedMessages: true,
        wasNearLatest: true,
      ),
      isTrue,
    );
    expect(
      shouldFollowLatestMessages(
        isInitialSnapshot: true,
        hasAddedMessages: true,
        wasNearLatest: true,
      ),
      isFalse,
    );
  });

  testWidgets('jump action scrolls to latest and clears the indicator', (
    tester,
  ) async {
    final state = ConversationLatestMessages();
    final scrollController = ScrollController();
    addTearDown(state.dispose);
    addTearDown(scrollController.dispose);
    state.markInitialMessagesLoaded();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            controller: scrollController,
            itemCount: 40,
            itemBuilder: (_, index) =>
                SizedBox(height: 50, child: Text('Message $index')),
          ),
        ),
      ),
    );
    state.updateScrollPosition(
      pixels: scrollController.position.maxScrollExtent / 2,
      maxScrollExtent: scrollController.position.maxScrollExtent,
    );
    state.recordIncomingMessages(const [
      MapEntry('incoming-1', 'peer'),
    ], currentUserId: 'me');
    expect(state.shouldShowNewMessageIndicator, isTrue);

    final jump = jumpConversationToLatest(scrollController);
    await tester.pumpAndSettle();
    await jump;
    state.updateScrollPosition(
      pixels: scrollController.position.pixels,
      maxScrollExtent: scrollController.position.maxScrollExtent,
    );

    expect(
      scrollController.position.pixels,
      scrollController.position.maxScrollExtent,
    );
    expect(state.isNearLatest, isTrue);
    expect(state.shouldShowNewMessageIndicator, isFalse);
  });

  testWidgets('jump button invokes its action and displays new count', (
    tester,
  ) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationJumpToLatestButton(
            newMessageCount: 2,
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    expect(find.text('2 new messages'), findsOneWidget);
    await tester.tap(find.byTooltip('Jump to latest message'));

    expect(pressed, isTrue);
  });

  testWidgets(
    'jump button hides message count when there are no new messages',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConversationJumpToLatestButton(
              newMessageCount: 0,
              onPressed: _noop,
            ),
          ),
        ),
      );

      expect(find.textContaining('new message'), findsNothing);
      expect(find.byTooltip('Jump to latest message'), findsOneWidget);
    },
  );
}

void _noop() {}
