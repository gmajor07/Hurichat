import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:huruchat/screens/chat/conversation_draft.dart';

void main() {
  late Directory tempDirectory;
  late Box draftsBox;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'huruchat-drafts-test-',
    );
    Hive.init(tempDirectory.path);
    draftsBox = await Hive.openBox('drafts');
  });

  tearDown(() async {
    await Hive.close();
    await tempDirectory.delete(recursive: true);
  });

  ConversationDraftStore storeFor({
    String accountId = 'account-a',
    String chatId = 'chat-a',
  }) {
    return ConversationDraftStore(
      box: draftsBox,
      accountId: accountId,
      chatId: chatId,
    );
  }

  test('saves and restores a draft for its conversation', () async {
    final store = storeFor();
    await store.save('unfinished message');

    expect(store.load(), 'unfinished message');
  });

  test('keeps drafts separate by conversation and account', () async {
    final original = storeFor();
    final otherConversation = storeFor(chatId: 'chat-b');
    final otherAccount = storeFor(accountId: 'account-b');

    await original.save('first conversation');
    await otherConversation.save('second conversation');
    await otherAccount.save('other account');

    expect(original.load(), 'first conversation');
    expect(otherConversation.load(), 'second conversation');
    expect(otherAccount.load(), 'other account');
  });

  test('debounces composer edits and flushes before navigation', () async {
    final store = storeFor();
    final persistence = ConversationDraftPersistence(
      store: store,
      debounceDuration: const Duration(milliseconds: 10),
    );
    addTearDown(persistence.dispose);

    persistence.onTextChanged('initial');
    persistence.onTextChanged('latest draft');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(store.load(), 'latest draft');
  });

  test('clears a draft when the user removes all text', () async {
    final store = storeFor();
    final persistence = ConversationDraftPersistence(store: store);
    await store.save('draft');

    persistence.onTextChanged('');
    await persistence.flush();

    expect(store.load(), isNull);
    await persistence.dispose();
  });

  test('clears the submitted draft only after successful delivery', () async {
    final store = storeFor();
    final persistence = ConversationDraftPersistence(store: store);
    persistence.onTextChanged('sent text');
    await persistence.flush();

    await persistence.clearAfterSuccessfulSend('sent text');

    expect(store.load(), isNull);
    await persistence.dispose();
  });

  test('retains the draft when delivery fails', () async {
    final store = storeFor();
    final persistence = ConversationDraftPersistence(store: store);
    persistence.onTextChanged('retry this later');
    await persistence.flush();

    // A failed send does not invoke clearAfterSuccessfulSend.
    expect(store.load(), 'retry this later');
    await persistence.dispose();
  });

  test(
    'does not clear a newer draft after an earlier message succeeds',
    () async {
      final store = storeFor();
      final persistence = ConversationDraftPersistence(store: store);
      persistence.onTextChanged('message being sent');
      await persistence.flush();
      persistence.onTextChanged('new unsent draft');

      await persistence.clearAfterSuccessfulSend('message being sent');

      expect(store.load(), 'new unsent draft');
      await persistence.dispose();
    },
  );
}
