import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/screens/chat/presence_service.dart';

void main() {
  test('resumed marks online and background lifecycle states mark offline', () {
    var onlineCalls = 0;
    var offlineCalls = 0;
    void dispatch(AppLifecycleState state) {
      dispatchPresenceLifecycleState(
        state,
        onResumed: () => onlineCalls++,
        onOffline: () => offlineCalls++,
      );
    }

    dispatch(AppLifecycleState.resumed);
    dispatch(AppLifecycleState.inactive);
    dispatch(AppLifecycleState.paused);
    dispatch(AppLifecycleState.hidden);
    dispatch(AppLifecycleState.detached);

    expect(onlineCalls, 1);
    expect(offlineCalls, 4);
  });

  test('presence update failures are reported without escaping', () async {
    Object? reportedError;

    await expectLater(
      runPresenceUpdateSafely(
        () async => throw StateError('network unavailable'),
        onError: (error, _) => reportedError = error,
      ),
      completes,
    );

    expect(reportedError, isA<StateError>());
  });
}
