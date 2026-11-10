import 'package:flutter/foundation.dart';

class MessageSendGuard extends ChangeNotifier {
  bool isSending = false;
  bool _disposed = false;

  Future<bool> run(Future<void> Function() send) async {
    if (_disposed || isSending) return false;

    isSending = true;
    notifyListeners();
    try {
      await send();
      return true;
    } finally {
      isSending = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
