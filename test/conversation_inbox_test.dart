import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/screens/chat/conversation_draft.dart';
import 'package:huruchat/screens/chat/conversation_inbox.dart';

void main() {
  final inboxItems = [
    {'chatId': 'chat-unread', 'isDraft': false},
    {'chatId': 'chat-draft', 'isDraft': true},
    {'chatId': 'chat-normal', 'isDraft': false},
  ];

  test('excludes users who have no conversation', () {
    final items = buildConversationInboxItems(
      currentUserId: 'me',
      chats: [
        MapEntry('me_peer', {
          'members': ['me', 'peer'],
        }),
      ],
      profiles: {
        'peer': {'name': 'Peer'},
        'stranger': {'name': 'Stranger'},
      },
      pinnedUserIds: {},
    );

    expect(items.map((item) => item['userId']), ['peer']);
  });

  test(
    'shows existing conversations using their stored chat ID and preview',
    () {
      final items = buildConversationInboxItems(
        currentUserId: 'me',
        chats: [
          MapEntry('stored_chat_id', {
            'members': ['me', 'peer'],
            'lastMessage': 'Hello',
            'lastTimestamp': 123,
          }),
        ],
        profiles: {
          'peer': {'name': 'peer', 'photoUrl': 'photo', 'status': 'online'},
        },
        pinnedUserIds: {'peer'},
      );

      expect(items, hasLength(1));
      expect(items.single, {
        'userId': 'peer',
        'name': 'Peer',
        'photoUrl': 'photo',
        'status': 'online',
        'chatId': 'stored_chat_id',
        'lastMessage': 'Hello',
        'isDraft': false,
        'lastTimestamp': 123,
        'isPinned': true,
      });
    },
  );

  test('shows a saved draft before the last-message preview', () {
    final draftKey = conversationDraftKey(
      accountId: 'me',
      chatId: 'stored_chat_id',
    );
    final items = buildConversationInboxItems(
      currentUserId: 'me',
      chats: [
        MapEntry('stored_chat_id', {
          'members': ['me', 'peer'],
          'lastMessage': 'Previous message',
          'lastTimestamp': 456,
        }),
      ],
      profiles: {
        'peer': {'name': 'Peer'},
      },
      pinnedUserIds: {},
      drafts: {draftKey: 'unfinished reply'},
    );

    expect(items.single['lastMessage'], 'Draft: unfinished reply');
    expect(items.single['isDraft'], isTrue);
    expect(items.single['chatId'], 'stored_chat_id');
    expect(items.single['lastTimestamp'], 456);
  });

  test('does not replace preview for empty or whitespace-only drafts', () {
    final emptyDraftKey = conversationDraftKey(
      accountId: 'me',
      chatId: 'chat-empty',
    );
    final whitespaceDraftKey = conversationDraftKey(
      accountId: 'me',
      chatId: 'chat-whitespace',
    );
    final items = buildConversationInboxItems(
      currentUserId: 'me',
      chats: [
        MapEntry('chat-empty', {
          'members': ['me', 'empty'],
          'lastMessage': 'Existing message',
        }),
        MapEntry('chat-whitespace', {
          'members': ['me', 'whitespace'],
          'lastMessage': 'Another message',
        }),
      ],
      profiles: {},
      pinnedUserIds: {},
      drafts: {emptyDraftKey: '', whitespaceDraftKey: '  \n '},
    );

    expect(items[0]['lastMessage'], 'Existing message');
    expect(items[0]['isDraft'], isFalse);
    expect(items[1]['lastMessage'], 'Another message');
    expect(items[1]['isDraft'], isFalse);
  });

  test('does not show a draft from another account or conversation', () {
    final unrelatedDraftKey = conversationDraftKey(
      accountId: 'other-account',
      chatId: 'stored_chat_id',
    );
    final otherConversationDraftKey = conversationDraftKey(
      accountId: 'me',
      chatId: 'different-chat',
    );
    final items = buildConversationInboxItems(
      currentUserId: 'me',
      chats: [
        MapEntry('stored_chat_id', {
          'members': ['me', 'peer'],
          'lastMessage': 'Original preview',
        }),
      ],
      profiles: {},
      pinnedUserIds: {},
      drafts: {
        unrelatedDraftKey: 'private other-account text',
        otherConversationDraftKey: 'private other-chat text',
      },
    );

    expect(items.single['lastMessage'], 'Original preview');
    expect(items.single['isDraft'], isFalse);
  });

  test('uses safe defaults when the participant profile is missing', () {
    final items = buildConversationInboxItems(
      currentUserId: 'me',
      chats: [
        MapEntry('me_peer', {
          'members': ['me', 'peer'],
        }),
      ],
      profiles: {},
      pinnedUserIds: {},
    );

    expect(items.single['userId'], 'peer');
    expect(items.single['name'], 'Unknown');
    expect(items.single['photoUrl'], '');
    expect(items.single['status'], 'offline');
    expect(items.single['chatId'], 'me_peer');
  });

  test('All, Unread, and Drafts filters select the expected conversations', () {
    final unreadCounts = {'chat-unread': 2, 'chat-draft': 0};

    expect(
      filterConversationInboxItems(
        items: inboxItems,
        filter: ConversationInboxFilter.all,
        unreadCounts: unreadCounts,
      ),
      inboxItems,
    );
    expect(
      filterConversationInboxItems(
        items: inboxItems,
        filter: ConversationInboxFilter.unread,
        unreadCounts: unreadCounts,
      ),
      [inboxItems.first],
    );
    expect(
      filterConversationInboxItems(
        items: inboxItems,
        filter: ConversationInboxFilter.drafts,
        unreadCounts: unreadCounts,
      ),
      [inboxItems[1]],
    );
  });

  test('Unread filter reflects changing unread counts while active', () async {
    final countsStream = StreamController<int>.broadcast();
    final counts = ConversationUnreadCounts(
      streamForChat: (_) => countsStream.stream,
    );
    addTearDown(() async {
      counts.dispose();
      await countsStream.close();
    });
    counts.watch(['chat-unread']);

    countsStream.add(0);
    await Future<void>.delayed(Duration.zero);
    expect(
      filterConversationInboxItems(
        items: inboxItems,
        filter: ConversationInboxFilter.unread,
        unreadCounts: counts.counts,
      ),
      isEmpty,
    );

    countsStream.add(1);
    await Future<void>.delayed(Duration.zero);
    expect(
      filterConversationInboxItems(
        items: inboxItems,
        filter: ConversationInboxFilter.unread,
        unreadCounts: counts.counts,
      ),
      [inboxItems.first],
    );

    countsStream.add(0);
    await Future<void>.delayed(Duration.zero);
    expect(
      filterConversationInboxItems(
        items: inboxItems,
        filter: ConversationInboxFilter.unread,
        unreadCounts: counts.counts,
      ),
      isEmpty,
    );
  });

  test(
    'Drafts filter updates when draft text is created, edited, and cleared',
    () {
      final chat = [
        MapEntry('chat-a', {
          'members': ['me', 'peer'],
          'lastMessage': 'Last sent message',
        }),
      ];
      final draftKey = conversationDraftKey(accountId: 'me', chatId: 'chat-a');

      List<Map<String, dynamic>> visibleDrafts(String? draft) {
        final items = buildConversationInboxItems(
          currentUserId: 'me',
          chats: chat,
          profiles: {},
          pinnedUserIds: {},
          drafts: draft == null ? {} : {draftKey: draft},
        );
        return filterConversationInboxItems(
          items: items,
          filter: ConversationInboxFilter.drafts,
          unreadCounts: const {},
        );
      }

      expect(visibleDrafts(null), isEmpty);
      expect(
        visibleDrafts('first draft').single['lastMessage'],
        'Draft: first draft',
      );
      expect(
        visibleDrafts('edited draft').single['lastMessage'],
        'Draft: edited draft',
      );
      expect(visibleDrafts('  '), isEmpty);
    },
  );

  test('Draft filtering remains isolated to the signed-in account', () {
    final otherAccountDraft = conversationDraftKey(
      accountId: 'different-account',
      chatId: 'chat-a',
    );
    final items = buildConversationInboxItems(
      currentUserId: 'me',
      chats: [
        MapEntry('chat-a', {
          'members': ['me', 'peer'],
        }),
      ],
      profiles: {},
      pinnedUserIds: {},
      drafts: {otherAccountDraft: 'private draft'},
    );

    expect(
      filterConversationInboxItems(
        items: items,
        filter: ConversationInboxFilter.drafts,
        unreadCounts: const {},
      ),
      isEmpty,
    );
  });
}
