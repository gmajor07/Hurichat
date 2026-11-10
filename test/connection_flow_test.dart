import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/screens/connection/connection_flow.dart';

void main() {
  test('sending a request marks the sender sent and recipient pending', () {
    final request = createConnectionRequestDocuments(
      senderId: 'sender',
      senderName: 'Sender',
      receiverId: 'receiver',
      receiverName: 'Receiver',
      timestamp: 123,
    );

    expect(request.outgoing['status'], 'sent');
    expect(request.incoming['status'], 'pending');
    expect(request.incoming['senderId'], 'sender');
    expect(request.outgoing['receiverId'], 'receiver');
    expect(request.outgoing['timestamp'], 123);
  });

  test('repeated submission runs only one request action', () async {
    final processingIds = <String>{};
    final completer = Completer<void>();
    var writes = 0;

    final first = runConnectionActionOnce(processingIds, 'receiver', () async {
      writes++;
      await completer.future;
    });
    final duplicate = await runConnectionActionOnce(
      processingIds,
      'receiver',
      () async {
        writes++;
      },
    );

    expect(duplicate, isFalse);
    expect(writes, 1);
    expect(processingIds, contains('receiver'));

    completer.complete();
    expect(await first, isTrue);
    expect(processingIds, isEmpty);
  });

  test('accepted requests add one contact; rejected requests do not', () {
    final contacts = filterConnectionsByStatus([
      const MapEntry('accepted-peer', {'status': 'accepted'}),
      const MapEntry('rejected-peer', {'status': 'rejected'}),
    ], 'accepted');

    expect(contacts.map((entry) => entry.key), ['accepted-peer']);
  });

  test(
    'Contacts excludes pending and sent requests and deduplicates peers',
    () {
      final contacts = filterConnectionsByStatus([
        const MapEntry('peer', {'status': 'accepted'}),
        const MapEntry('peer', {'status': 'accepted'}),
        const MapEntry('pending-peer', {'status': 'pending'}),
        const MapEntry('sent-peer', {'status': 'sent'}),
      ], 'accepted');

      expect(contacts.map((entry) => entry.key), ['peer']);
    },
  );

  test('missing contact profiles use safe fallback details', () {
    expect(contactProfileOrFallback(null), {
      'name': 'Unknown User',
      'photoUrl': '',
      'phone': '',
    });
  });

  test('request action errors release the guard for retry', () async {
    final processingIds = <String>{};

    await expectLater(
      runConnectionActionOnce(
        processingIds,
        'peer',
        () async => throw StateError('write failed'),
      ),
      throwsA(isA<StateError>()),
    );

    expect(processingIds, isEmpty);
    expect(
      await runConnectionActionOnce(processingIds, 'peer', () async {}),
      isTrue,
    );
  });
}
