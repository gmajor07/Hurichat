import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/screens/chat/conversation_info_screen.dart';

void main() {
  testWidgets('opens and closes conversation details without a header title', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => ConversationInfoScreen(
                    chatId: 'chat-1',
                    participantId: 'peer-1',
                    profileStream: Stream.value({
                      'name': 'Alex',
                      'status': 'offline',
                    }),
                  ),
                ),
              ),
              child: const Text('Open info'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open info'));
    await tester.pumpAndSettle();
    expect(find.text('Conversation info'), findsNothing);
    expect(find.text('Alex'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Open info'), findsOneWidget);
    expect(find.text('Conversation info'), findsNothing);
  });

  testWidgets('missing profile data is shown safely with offline status', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConversationInfoScreen(
          chatId: 'chat-1',
          participantId: 'missing-peer',
          profileStream: Stream.value(null),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('This profile is no longer available.'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationInfoContent(
            chatId: 'chat-1',
            profile: const {'name': 'Alex'},
          ),
        ),
      ),
    );
    expect(find.text('Alex'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('conversation-info-presence')),
      findsNothing,
    );
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Unavailable'), findsNothing);
  });

  testWidgets('does not show presence or last-seen data', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationInfoContent(
            chatId: 'chat-1',
            profile: {
              'name': 'Alex',
              'status': 'offline',
              'lastSeen': DateTime(2026, 11, 7, 9, 5),
              'phone': '123',
            },
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('conversation-info-presence')),
      findsNothing,
    );
    expect(find.text('123'), findsOneWidget);
  });

  testWidgets('capitalizes each name and shows a green indicator when online', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationInfoContent(
            chatId: 'chat-1',
            profile: const {'name': 'joe doe', 'status': 'online'},
          ),
        ),
      ),
    );

    expect(find.text('Joe Doe'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    final indicator = tester.widget<Container>(
      find.byKey(const ValueKey('conversation-info-online-indicator')),
    );
    expect(
      (indicator.decoration! as BoxDecoration).color,
      const Color(0xFF22C55E),
    );
    expect(find.text('Offline'), findsNothing);
  });

  testWidgets('offline status has no green indicator', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationInfoContent(
            chatId: 'chat-1',
            profile: const {'name': 'Alex', 'status': 'offline'},
          ),
        ),
      ),
    );

    expect(find.text('Offline'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('conversation-info-online-indicator')),
      findsNothing,
    );
  });

  testWidgets('Shared Media action navigates to its action route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ConversationInfoContent(
              chatId: 'chat-1',
              profile: const {'name': 'Alex'},
              onOpenSharedMedia: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: Center(child: Text('Shared media destination')),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('conversation-info-shared-media')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Shared media destination'), findsOneWidget);
  });

  testWidgets('shows profile details without a View Profile action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationInfoContent(
            chatId: 'chat-1',
            profile: const {'name': 'Alex', 'phone': '123'},
          ),
        ),
      ),
    );

    expect(find.text('123'), findsOneWidget);
    expect(find.text('View Profile'), findsNothing);
    expect(
      find.byKey(const ValueKey('conversation-info-view-profile')),
      findsNothing,
    );
  });

  testWidgets('Call requires a phone number and Message returns to the chat', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    body: ConversationInfoContent(
                      chatId: 'chat-1',
                      profile: const {
                        'name': 'Alex',
                        'status': 'offline',
                        'phone': '+1 (555) 010-1234',
                      },
                    ),
                  ),
                ),
              ),
              child: const Text('Open chat'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open chat'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('conversation-info-call')),
          )
          .onPressed,
      isNotNull,
    );

    final messageButton = find.byKey(
      const ValueKey('conversation-info-message'),
    );
    await tester.ensureVisible(messageButton);
    await tester.tap(messageButton);
    await tester.pumpAndSettle();
    expect(find.text('Open chat'), findsOneWidget);
  });
}
