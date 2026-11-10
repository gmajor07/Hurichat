import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/screens/chat/chat_widgets.dart';
import 'package:huruchat/screens/chat/message_send_guard.dart';
import 'package:huruchat/screens/chat/voice_message_logic.dart';

void main() {
  test('recording state moves through recording, finalizing and upload', () {
    final state = VoiceRecordingState();
    addTearDown(state.dispose);

    expect(state.status, VoiceRecordingStatus.idle);
    expect(state.requestPermission(), isTrue);
    expect(state.status, VoiceRecordingStatus.requestingPermission);
    expect(state.start(), isTrue);
    expect(state.status, VoiceRecordingStatus.recording);
    state.updateDuration(const Duration(seconds: 4));
    expect(state.duration, const Duration(seconds: 4));
    expect(state.beginFinalizing(), isTrue);
    expect(state.status, VoiceRecordingStatus.finalizing);
    expect(state.beginUpload(), isTrue);
    expect(state.status, VoiceRecordingStatus.uploading);
    state.complete();
    expect(state.status, VoiceRecordingStatus.idle);
    expect(state.duration, Duration.zero);
  });

  test('permission denial guidance covers device settings recovery', () {
    expect(microphonePermissionDeniedMessage(), contains('device settings'));
    expect(microphonePermissionDeniedMessage(), contains('try again'));
  });

  test(
    'lifecycle interruption cancels without treating permission UI as exit',
    () {
      expect(
        shouldCancelVoiceRecordingForLifecycle(AppLifecycleState.inactive),
        isFalse,
      );
      expect(
        shouldCancelVoiceRecordingForLifecycle(AppLifecycleState.paused),
        isTrue,
      );
      expect(
        shouldCancelVoiceRecordingForLifecycle(AppLifecycleState.hidden),
        isTrue,
      );
    },
  );

  test('cancelling a recording resets state and rejects duplicate starts', () {
    final state = VoiceRecordingState();
    addTearDown(state.dispose);

    expect(state.requestPermission(), isTrue);
    expect(state.start(), isTrue);
    state.updateDuration(const Duration(seconds: 2));
    expect(state.start(), isFalse);
    state.cancel();

    expect(state.status, VoiceRecordingStatus.idle);
    expect(state.duration, Duration.zero);
    expect(state.beginFinalizing(), isFalse);
  });

  test('cancelled recordings remove their temporary file', () async {
    final directory = await Directory.systemTemp.createTemp('voice-test-');
    addTearDown(() => directory.delete(recursive: true));
    final recording = File('${directory.path}/voice.m4a');
    await recording.writeAsString('temporary audio');
    Object? reportedError;

    await deleteTemporaryVoiceRecording(
      recording,
      onError: (error, _) => reportedError = error,
    );

    expect(await recording.exists(), isFalse);
    expect(reportedError, isNull);
  });

  test('voice message fields preserve chat participants and read state', () {
    expect(
      buildVoiceMessageFields(
        senderId: 'sender',
        receiverId: 'receiver',
        audioUrl: 'https://storage.example/voice.m4a',
        durationMillis: 4321,
      ),
      {
        'senderId': 'sender',
        'receiverId': 'receiver',
        'text': 'Voice message',
        'type': 'voice',
        'audioUrl': 'https://storage.example/voice.m4a',
        'durationMillis': 4321,
        'isRead': false,
      },
    );
  });

  test(
    'duplicate voice submissions are rejected while the first is active',
    () async {
      final guard = MessageSendGuard();
      final completer = Completer<void>();
      var sendCount = 0;
      addTearDown(guard.dispose);

      final first = guard.run(() async {
        sendCount++;
        await completer.future;
      });
      final duplicate = await guard.run(() async {
        sendCount++;
      });

      expect(duplicate, isFalse);
      expect(sendCount, 1);
      completer.complete();
      expect(await first, isTrue);
    },
  );

  test('voice upload failure is reported and does not return a URL', () async {
    Object? reportedError;
    final result = await uploadVoiceSafely(
      () async => throw StateError('storage unavailable'),
      onError: (error, _) => reportedError = error,
    );

    expect(result, isNull);
    expect(reportedError, isA<StateError>());
  });

  testWidgets('voice message renders playback control and recorded duration', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: MessageTile(
                message: {
                  'firestoreId': 'voice-from-firestore-history',
                  'senderId': 'me',
                  'type': 'voice',
                  'audioUrl': 'https://storage.example/voice.m4a',
                  'durationMillis': 4321,
                  'isRead': true,
                },
                currentUserId: 'me',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Play voice message'), findsOneWidget);
    expect(find.text('0:04'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
