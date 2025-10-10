import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

class PresenceService with WidgetsBindingObserver {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  void init() {
    WidgetsBinding.instance.addObserver(this);
    _setOnline(); // set user online when app starts
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _setOnline();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _setOffline();
        break;
      case AppLifecycleState.hidden:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  Future<void> _setOnline() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'status': 'online',
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _setOffline() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'status': 'offline',
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
