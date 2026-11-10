import 'dart:io';

import 'package:flutter/widgets.dart';

enum VoiceRecordingStatus {
  idle,
  requestingPermission,
  recording,
  finalizing,
  uploading,
}

String microphonePermissionDeniedMessage() {
  return 'Microphone access is unavailable. Allow microphone access in '
      'device settings, then try again.';
}

bool shouldCancelVoiceRecordingForLifecycle(AppLifecycleState state) {
  return state == AppLifecycleState.hidden ||
      state == AppLifecycleState.paused ||
      state == AppLifecycleState.detached;
}

class VoiceRecordingState extends ChangeNotifier {
  VoiceRecordingStatus _status = VoiceRecordingStatus.idle;
  Duration _duration = Duration.zero;
  bool _disposed = false;

  VoiceRecordingStatus get status => _status;
  Duration get duration => _duration;
  bool get isRecording => _status == VoiceRecordingStatus.recording;

  bool requestPermission() {
    if (_status != VoiceRecordingStatus.idle || _disposed) return false;
    _duration = Duration.zero;
    _setStatus(VoiceRecordingStatus.requestingPermission);
    return true;
  }

  bool start() {
    if (_status != VoiceRecordingStatus.requestingPermission || _disposed) {
      return false;
    }
    _setStatus(VoiceRecordingStatus.recording);
    return true;
  }

  void updateDuration(Duration duration) {
    if (!isRecording || _disposed) return;
    _duration = duration;
    notifyListeners();
  }

  bool beginFinalizing() {
    if (!isRecording || _disposed) return false;
    _setStatus(VoiceRecordingStatus.finalizing);
    return true;
  }

  bool beginUpload() {
    if (_status != VoiceRecordingStatus.finalizing || _disposed) return false;
    _setStatus(VoiceRecordingStatus.uploading);
    return true;
  }

  void cancel() {
    if (_status == VoiceRecordingStatus.idle || _disposed) return;
    _duration = Duration.zero;
    _setStatus(VoiceRecordingStatus.idle);
  }

  void complete() => cancel();

  void _setStatus(VoiceRecordingStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

Map<String, dynamic> buildVoiceMessageFields({
  required String senderId,
  required String receiverId,
  required String audioUrl,
  required int durationMillis,
}) {
  return {
    'senderId': senderId,
    'receiverId': receiverId,
    'text': 'Voice message',
    'type': 'voice',
    'audioUrl': audioUrl,
    'durationMillis': durationMillis,
    'isRead': false,
  };
}

String formatVoiceDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final minutes = (totalSeconds ~/ 60).toString();
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

Future<T?> uploadVoiceSafely<T>(
  Future<T> Function() upload, {
  required void Function(Object error, StackTrace stackTrace) onError,
}) async {
  try {
    return await upload();
  } catch (error, stackTrace) {
    onError(error, stackTrace);
    return null;
  }
}

Future<void> deleteTemporaryVoiceRecording(
  File? recordingFile, {
  required void Function(Object error, StackTrace stackTrace) onError,
}) async {
  if (recordingFile == null) return;
  try {
    if (await recordingFile.exists()) await recordingFile.delete();
  } catch (error, stackTrace) {
    onError(error, stackTrace);
  }
}
