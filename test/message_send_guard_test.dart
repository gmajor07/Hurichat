import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/screens/chat/message_send_guard.dart';

void main() {
  test('runs a successful send and clears its sending state', () async {
    final guard = MessageSendGuard();
    var sendCount = 0;
    addTearDown(guard.dispose);

    final accepted = await guard.run(() async {
      sendCount++;
    });

    expect(accepted, isTrue);
    expect(sendCount, 1);
    expect(guard.isSending, isFalse);
  });

  test('rejects repeated sends while the first send is in progress', () async {
    final guard = MessageSendGuard();
    final completer = Completer<void>();
    var sendCount = 0;
    addTearDown(guard.dispose);

    final firstSend = guard.run(() async {
      sendCount++;
      await completer.future;
    });
    final duplicateAccepted = await guard.run(() async {
      sendCount++;
    });

    expect(guard.isSending, isTrue);
    expect(duplicateAccepted, isFalse);
    expect(sendCount, 1);

    completer.complete();
    expect(await firstSend, isTrue);
    expect(guard.isSending, isFalse);
  });

  test('releases the guard after failure so a retry can run', () async {
    final guard = MessageSendGuard();
    var retryCount = 0;
    addTearDown(guard.dispose);

    await expectLater(
      guard.run(() async {
        throw StateError('send failed');
      }),
      throwsA(isA<StateError>()),
    );
    expect(guard.isSending, isFalse);

    final retryAccepted = await guard.run(() async {
      retryCount++;
    });

    expect(retryAccepted, isTrue);
    expect(retryCount, 1);
    expect(guard.isSending, isFalse);
  });
}
