import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/screens/chat/shared_media_logic.dart';
import 'package:huruchat/screens/chat/shared_media_screen.dart';

void main() {
  SharedMediaItem item(
    String id, {
    required String type,
    required String url,
    required int timestamp,
    int? duration,
  }) {
    return SharedMediaItem(
      id: id,
      data: {
        'type': type,
        if (type == 'image') 'imageUrl': url,
        if (type == 'voice') 'audioUrl': url,
        if (duration != null) 'durationMillis': duration,
        'timestamp': timestamp,
      },
    );
  }

  test('filters supported shared images and voices only', () {
    final items = filterSharedMediaItems([
      item(
        'voice',
        type: 'voice',
        url: 'https://storage.example/voice.m4a',
        timestamp: 2,
        duration: 2500,
      ),
      item(
        'image',
        type: 'image',
        url: 'https://storage.example/photo.jpg',
        timestamp: 1,
      ),
      item(
        'invalid-image',
        type: 'image',
        url: 'file:///photo.jpg',
        timestamp: 3,
      ),
      item(
        'invalid-voice',
        type: 'voice',
        url: 'https://storage.example/voice.m4a',
        timestamp: 4,
      ),
      item('text', type: 'text', url: '', timestamp: 5),
    ]);

    expect(items.map((entry) => entry.id), ['image', 'voice']);
    expect(filterSharedMediaItems(items, type: 'voice').single.id, 'voice');
    expect(filterSharedMediaItems(items, type: 'image').single.id, 'image');
  });

  test('merges media pages in chronological order without duplicate IDs', () {
    final firstPage = [
      item(
        'later',
        type: 'image',
        url: 'https://storage.example/later.jpg',
        timestamp: 30,
      ),
      item(
        'shared',
        type: 'voice',
        url: 'https://storage.example/shared.m4a',
        timestamp: 20,
        duration: 1200,
      ),
    ];
    final olderPage = [
      item(
        'older',
        type: 'image',
        url: 'https://storage.example/older.jpg',
        timestamp: 10,
      ),
      item(
        'shared',
        type: 'voice',
        url: 'https://storage.example/shared.m4a',
        timestamp: 20,
        duration: 1200,
      ),
    ];

    final merged = mergeSharedMediaPage(
      current: firstPage,
      nextPage: olderPage,
    );
    expect(merged.map((entry) => entry.id), ['older', 'shared', 'later']);
    expect(hasMoreSharedMediaPage(30, pageSize: 30), isTrue);
    expect(hasMoreSharedMediaPage(12, pageSize: 30), isFalse);
  });

  test('formats voice duration', () {
    expect(formatSharedMediaDuration(65_000), '1:05');
    expect(formatSharedMediaDuration(9_000), '0:09');
  });

  testWidgets('empty state can request older pages', (tester) async {
    var requestedMore = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SharedMediaEmptyState(
            label: 'No shared voice messages yet.',
            onLoadMore: () => requestedMore = true,
          ),
        ),
      ),
    );

    expect(find.text('No shared voice messages yet.'), findsOneWidget);
    await tester.tap(find.text('Load older media'));
    expect(requestedMore, isTrue);
  });

  testWidgets('voice tile returns its message ID for conversation navigation', (
    tester,
  ) async {
    String? selectedId;
    final voice = item(
      'voice-message-1',
      type: 'voice',
      url: 'https://storage.example/voice.m4a',
      timestamp: 1,
      duration: 65_000,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SharedVoiceMediaTile(
            item: voice,
            onTap: (messageId) => selectedId = messageId,
          ),
        ),
      ),
    );

    expect(find.text('Voice message · 1:05'), findsOneWidget);
    await tester.tap(find.text('Voice message · 1:05'));
    expect(selectedId, 'voice-message-1');
  });
}
