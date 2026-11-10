import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/screens/chat/image_message_logic.dart';
import 'package:huruchat/screens/chat/message_send_guard.dart';

void main() {
  test('image message keeps existing participants and unread state', () {
    expect(
      buildImageMessageFields(
        senderId: 'sender',
        receiverId: 'receiver',
        imageUrl: 'https://storage.example/image.jpg',
      ),
      {
        'senderId': 'sender',
        'receiverId': 'receiver',
        'text': 'Photo',
        'type': 'image',
        'imageUrl': 'https://storage.example/image.jpg',
        'isRead': false,
      },
    );
  });

  test('repeated attachment action cannot start a second upload', () async {
    final guard = MessageSendGuard();
    addTearDown(guard.dispose);
    final uploadCompleter = Completer<void>();
    var uploadCount = 0;

    final first = guard.run(() async {
      uploadCount++;
      await uploadCompleter.future;
    });
    final second = await guard.run(() async {
      uploadCount++;
    });

    expect(second, isFalse);
    expect(uploadCount, 1);
    uploadCompleter.complete();
    expect(await first, isTrue);
    expect(guard.isSending, isFalse);
  });

  test(
    'upload failures report the error and return no URL for retry',
    () async {
      Object? reportedError;
      final result = await uploadImageSafely(
        () async => throw StateError('storage unavailable'),
        onError: (error, _) => reportedError = error,
      );

      expect(result, isNull);
      expect(reportedError, isA<StateError>());
      expect(
        imageMessageFailureText(cancelled: false),
        'Could not send image. Please try again.',
      );
    },
  );

  test('cancelled uploads provide distinct feedback', () {
    expect(imageMessageFailureText(cancelled: true), 'Image upload cancelled.');
  });

  test('image upload metadata uses image content types', () {
    expect(imageContentTypeForPath('/tmp/photo.png'), 'image/png');
    expect(imageContentTypeForPath('/tmp/photo.webp'), 'image/webp');
    expect(imageContentTypeForPath('/tmp/photo.jpg'), 'image/jpeg');
    expect(imageContentTypeForPath('/tmp/photo.unknown'), 'image/jpeg');
    expect(imageFileExtension('/tmp/a.folder/photo'), 'jpg');
    expect(imageFileExtension('/tmp/photo.PNG'), 'png');
  });
}
