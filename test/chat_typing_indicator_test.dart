import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/screens/chat/chat_typing_indicator.dart';

void main() {
  group('typing presence data', () {
    test('shows only a recent other participant as typing', () {
      final now = DateTime.utc(2026, 11, 7, 12);
      final typingUsers = {
        'me': Timestamp.fromDate(now),
        'peer': Timestamp.fromDate(now.subtract(const Duration(seconds: 4))),
      };

      expect(
        hasOtherParticipantTyping(
          typingUsers: typingUsers,
          currentUserId: 'me',
          now: now,
        ),
        isTrue,
      );
      expect(
        hasOtherParticipantTyping(
          typingUsers: {'me': now.millisecondsSinceEpoch},
          currentUserId: 'me',
          now: now,
        ),
        isFalse,
      );
      expect(
        hasOtherParticipantTyping(
          typingUsers: {
            'peer': now
                .subtract(const Duration(seconds: 6))
                .millisecondsSinceEpoch,
          },
          currentUserId: 'me',
          now: now,
        ),
        isFalse,
      );
    });

    test('updates one participant without replacing another participant', () {
      final existing = {
        'peer': Timestamp.fromMillisecondsSinceEpoch(100),
        'me': Timestamp.fromMillisecondsSinceEpoch(90),
      };

      final updated = mergeTypingUserTimestamp(
        currentTypingUsers: existing,
        userId: 'me',
        timestamp: Timestamp.fromMillisecondsSinceEpoch(120),
      );
      expect(updated['peer'], existing['peer']);
      expect(updated['me'], Timestamp.fromMillisecondsSinceEpoch(120));

      expect(removeTypingUser(currentTypingUsers: updated, userId: 'me'), {
        'peer': existing['peer'],
      });
    });

    test('computes time remaining until a recent typing marker expires', () {
      final now = DateTime.utc(2026, 11, 7, 12);
      expect(
        timeUntilTypingExpires(
          typingUsers: {
            'peer': Timestamp.fromDate(
              now.subtract(const Duration(seconds: 2)),
            ),
          },
          currentUserId: 'me',
          now: now,
        ),
        const Duration(seconds: 3),
      );
      expect(
        timeUntilTypingExpires(
          typingUsers: {'me': Timestamp.fromDate(now)},
          currentUserId: 'me',
          now: now,
        ),
        isNull,
      );
    });
  });

  group('typing activity lifecycle', () {
    test('debounces typing start and clears on empty text', () async {
      final events = <bool>[];
      final activity = TypingActivity(
        onTypingChanged: (isTyping) async => events.add(isTyping),
        startDebounce: const Duration(milliseconds: 25),
        inactivityTimeout: const Duration(seconds: 1),
        refreshInterval: const Duration(seconds: 1),
      );
      addTearDown(activity.dispose);

      activity.onTextChanged('h');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(events, isEmpty);

      activity.onTextChanged('hi');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(events, [true]);

      activity.onTextChanged('');
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(events, [true, false]);
      expect(activity.isTyping, isFalse);
    });

    test('stops after inactivity timeout', () async {
      final events = <bool>[];
      final activity = TypingActivity(
        onTypingChanged: (isTyping) async => events.add(isTyping),
        startDebounce: const Duration(milliseconds: 1),
        inactivityTimeout: const Duration(milliseconds: 30),
        refreshInterval: const Duration(seconds: 1),
      );
      addTearDown(activity.dispose);

      activity.onTextChanged('typing');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(events, [true]);

      await Future<void>.delayed(const Duration(milliseconds: 35));
      expect(events.last, isFalse);
      expect(activity.isTyping, isFalse);
    });

    test(
      'stop and dispose cancel pending starts and clear active state',
      () async {
        final events = <bool>[];
        final activity = TypingActivity(
          onTypingChanged: (isTyping) async => events.add(isTyping),
          startDebounce: const Duration(milliseconds: 10),
          inactivityTimeout: const Duration(seconds: 1),
        );

        activity.onTextChanged('pending');
        await activity.stop();
        await Future<void>.delayed(const Duration(milliseconds: 15));
        expect(events, isEmpty);

        activity.onTextChanged('active');
        await Future<void>.delayed(const Duration(milliseconds: 15));
        expect(events, [true]);
        activity.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 1));
        expect(events, [true, false]);

        activity.onTextChanged('after dispose');
        await Future<void>.delayed(const Duration(milliseconds: 15));
        expect(events, [true, false]);
      },
    );
  });
}
