import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

void dispatchPresenceLifecycleState(
  AppLifecycleState state, {
  required VoidCallback onResumed,
  required VoidCallback onOffline,
}) {
  switch (state) {
    case AppLifecycleState.resumed:
      onResumed();
      break;
    case AppLifecycleState.inactive:
    case AppLifecycleState.paused:
    case AppLifecycleState.detached:
    case AppLifecycleState.hidden:
      onOffline();
      break;
  }
}

Future<void> runPresenceUpdateSafely(
  Future<void> Function() update, {
  required void Function(Object error, StackTrace stackTrace) onError,
}) async {
  try {
    await update();
  } catch (error, stackTrace) {
    onError(error, stackTrace);
  }
}

class PresenceService with WidgetsBindingObserver {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  void init() {
    WidgetsBinding.instance.addObserver(this);
    _setOnline(); // set user online when app starts
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    dispatchPresenceLifecycleState(
      state,
      onResumed: () => _setOnline(),
      onOffline: () => _setOffline(),
    );
  }

  Future<void> _setOnline() async {
    final user = _auth.currentUser;
    if (user != null) {
      await runPresenceUpdateSafely(
        () => _firestore.collection('users').doc(user.uid).update({
          'status': 'online',
          'lastSeen': FieldValue.serverTimestamp(),
        }),
        onError: (error, stackTrace) {
          debugPrint('Failed to set presence online: $error\n$stackTrace');
        },
      );
    }
  }

  Future<void> _setOffline() async {
    final user = _auth.currentUser;
    if (user != null) {
      await runPresenceUpdateSafely(
        () => _firestore.collection('users').doc(user.uid).update({
          'status': 'offline',
          'lastSeen': FieldValue.serverTimestamp(),
        }),
        onError: (error, stackTrace) {
          debugPrint('Failed to set presence offline: $error\n$stackTrace');
        },
      );
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
