import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/screens/chat/message_mutations.dart';

void main() {
  group('conversationMessagesAfterCleared', () {
    test('returns every message when the conversation was never cleared', () {
      final messages = [
        {'firestoreId': 'a', 'timestamp': 1000},
        {'firestoreId': 'b', 'timestamp': 2000},
      ];

      final result = conversationMessagesAfterCleared(
        messages: messages,
        clearedAtMillis: null,
      );

      expect(result, same(messages));
    });

    test('hides messages at or before the cleared instant', () {
      final messages = [
        {'firestoreId': 'old1', 'timestamp': 1000},
        {'firestoreId': 'old2', 'timestamp': 1500},
        {'firestoreId': 'new1', 'timestamp': 2000},
      ];

      final result = conversationMessagesAfterCleared(
        messages: messages,
        clearedAtMillis: 1500,
      );

      expect(result.map((m) => m['firestoreId']), ['new1']);
    });

    test('keeps pending local sends even if older than the cleared instant', () {
      final messages = [
        {'localId': 'l1', 'timestamp': 1000},
        {'firestoreId': 'new1', 'timestamp': 2000},
      ];

      final result = conversationMessagesAfterCleared(
        messages: messages,
        clearedAtMillis: 1500,
      );

      expect(result.map((m) => m['localId'] ?? m['firestoreId']), ['l1', 'new1']);
    });

    test('keeps messages without a numeric timestamp', () {
      final messages = [
        {'firestoreId': 'noTs'},
        {'firestoreId': 'new1', 'timestamp': 2000},
      ];

      final result = conversationMessagesAfterCleared(
        messages: messages,
        clearedAtMillis: 1500,
      );

      expect(result.map((m) => m['firestoreId']), ['noTs', 'new1']);
    });

    test('returns an empty list when all messages predate the cleared instant',
        () {
      final messages = [
        {'firestoreId': 'old1', 'timestamp': 1000},
        {'firestoreId': 'old2', 'timestamp': 1200},
      ];

      final result = conversationMessagesAfterCleared(
        messages: messages,
        clearedAtMillis: 1500,
      );

      expect(result, isEmpty);
    });
  });
}