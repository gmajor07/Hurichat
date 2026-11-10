import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/screens/chat/conversation_message_search.dart';

void main() {
  final messages = <Map<String, dynamic>>[
    {
      'firestoreId': 'message-1',
      'senderId': 'peer',
      'text': 'A message from another conversation is not supplied here',
    },
    {
      'firestoreId': 'message-2',
      'senderId': 'me',
      'text': 'The current conversation has a useful search phrase',
    },
    {
      'localId': 'local-3',
      'senderId': 'peer',
      'text': 'Another SEARCH phrase appears in this chat',
    },
    {'firestoreId': 'message-4', 'text': 42},
  ];

  test('empty or whitespace queries return no results', () {
    expect(searchConversationMessages(messages: messages, query: ''), isEmpty);
    expect(
      searchConversationMessages(messages: messages, query: '   '),
      isEmpty,
    );
  });

  test('search is case-insensitive and returns message previews', () {
    final results = searchConversationMessages(
      messages: messages,
      query: 'SEARCH PHRASE',
    );

    expect(results, hasLength(2));
    expect(results.map((result) => result.messageId), ['message-2', 'local-3']);
    expect(results.first.preview, contains('search phrase'));
  });

  test('no results are returned for unmatched text', () {
    expect(
      searchConversationMessages(messages: messages, query: 'not present'),
      isEmpty,
    );
  });

  test('voice message audio URLs and labels are not searchable text', () {
    final voiceMessage = {
      'firestoreId': 'voice-1',
      'senderId': 'peer',
      'type': 'voice',
      'text': 'Voice message',
      'audioUrl': 'https://storage.example/chats/chat-1/audio/voice.m4a',
    };

    expect(
      searchConversationMessages(
        messages: [voiceMessage],
        query: 'https://storage.example/chats/chat-1/audio/voice.m4a',
      ),
      isEmpty,
    );
    expect(
      searchConversationMessages(
        messages: [voiceMessage],
        query: 'Voice message',
      ),
      isEmpty,
    );
  });

  test('a selected result identifies the exact loaded message and index', () {
    final result = searchConversationMessages(
      messages: messages,
      query: 'useful search phrase',
    ).single;

    expect(result.messageId, 'message-2');
    expect(result.messageIndex, 1);
    expect(result.message, same(messages[1]));
  });
}
