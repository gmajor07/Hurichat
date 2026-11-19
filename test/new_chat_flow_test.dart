import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/screens/connection/connection_screen.dart';
import 'package:huruchat/screens/home/home_fab.dart';

void main() {
  test('New Chat opens the connected-contacts selector', () {
    final screen = buildNewChatScreen();

    expect(screen, isA<ConnectionScreen>());
    expect((screen as ConnectionScreen).contactsMode, isTrue);
    expect(screen.selectForChat, isTrue);
  });
}
