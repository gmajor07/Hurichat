import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/screens/chat/conversation_info_screen.dart';

void main() {
  testWidgets('opens and closes Conversation Info', (tester) async {
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
    expect(find.text('Conversation info'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Open info'), findsOneWidget);
    expect(find.text('Conversation info'), findsNothing);
  });

  testWidgets('missing profile data and presence are shown safely', (
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
            participantId: 'peer-1',
            profile: const {'name': 'Alex'},
          ),
        ),
      ),
    );
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Offline · last seen unavailable'), findsOneWidget);
    expect(find.text('Unavailable'), findsNothing);
  });

  testWidgets('uses available presence and last-seen data', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationInfoContent(
            chatId: 'chat-1',
            participantId: 'peer-1',
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

    expect(find.text('Offline · last seen 7/11/2026 09:05'), findsOneWidget);
    expect(find.text('123'), findsOneWidget);
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
              participantId: 'peer-1',
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

  testWidgets(
    'View Profile action is exposed for the existing profile screen',
    (tester) async {
      var openedProfile = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConversationInfoContent(
              chatId: 'chat-1',
              participantId: 'peer-1',
              profile: const {'name': 'Alex'},
              onViewProfile: () => openedProfile = true,
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('conversation-info-view-profile')),
      );
      expect(openedProfile, isTrue);
    },
  );
}
