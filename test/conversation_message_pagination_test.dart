import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/screens/chat/conversation_message_pagination.dart';

void main() {
  test(
    'merges page overlap by document ID and preserves timestamp ordering',
    () {
      final merged = mergeAndSortMessagePages([
        [
          MapEntry('older-2', {'timestamp': 200, 'text': 'older page'}),
          MapEntry('shared', {'timestamp': 300, 'text': 'stale version'}),
        ],
        [
          MapEntry('newer', {'timestamp': 400, 'text': 'newer'}),
          MapEntry('shared', {'timestamp': 300, 'text': 'live version'}),
          MapEntry('older-1', {'timestamp': 100, 'text': 'oldest'}),
        ],
      ]);

      expect(merged.map((entry) => entry.key), [
        'older-1',
        'older-2',
        'shared',
        'newer',
      ]);
      expect(merged[2].value['text'], 'live version');
    },
  );

  test(
    'orders equal timestamps by document ID and missing timestamps safely',
    () {
      final ordered = mergeAndSortMessagePages([
        [
          MapEntry('b', {'timestamp': 50}),
          MapEntry('a', {'timestamp': 50}),
          MapEntry('missing', {'text': 'no timestamp'}),
        ],
      ]);

      expect(ordered.map((entry) => entry.key), ['missing', 'a', 'b']);
    },
  );

  test('shows more-history state only when a complete page was returned', () {
    expect(pageHasMoreMessages(30), isTrue);
    expect(pageHasMoreMessages(29), isFalse);
    expect(pageHasMoreMessages(0), isFalse);
  });

  test('scroll threshold only requests older history near list start', () {
    expect(isNearConversationStart(0), isTrue);
    expect(isNearConversationStart(120), isTrue);
    expect(isNearConversationStart(121), isFalse);
  });

  test('preserves visible scroll offset when a page is prepended', () {
    expect(
      preserveConversationScrollOffset(
        previousPixels: 80,
        previousMaxExtent: 900,
        currentMinExtent: 0,
        currentMaxExtent: 1500,
      ),
      680,
    );
    expect(
      preserveConversationScrollOffset(
        previousPixels: 80,
        previousMaxExtent: 900,
        currentMinExtent: 0,
        currentMaxExtent: 500,
      ),
      0,
    );
  });

  test(
    'prevents overlapping older-page requests and releases after errors',
    () async {
      final guard = OlderMessagePageLoadGuard();
      final completer = Completer<void>();
      var requestCount = 0;

      final first = guard.run(() async {
        requestCount++;
        await completer.future;
      });
      final repeated = await guard.run(() async {
        requestCount++;
      });

      expect(guard.isLoading, isTrue);
      expect(repeated, isNull);
      expect(requestCount, 1);
      completer.complete();
      await first;
      expect(guard.isLoading, isFalse);

      await expectLater(
        guard.run<void>(() async => throw StateError('page load failed')),
        throwsA(isA<StateError>()),
      );
      expect(guard.isLoading, isFalse);
    },
  );
}
