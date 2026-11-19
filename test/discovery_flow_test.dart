import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/screens/connection/discovery_flow.dart';

void main() {
  test('builds a safe list of other discoverable users', () {
    final users = buildDiscoverableUserEntries(
      users: [
        {
          'uid': 'me',
          'name': 'My Name',
          'phone': '+123',
          'email': 'me@example.com',
        },
        {'uid': 'connected', 'name': 'Connected Person'},
        {
          'uid': 'peer',
          'name': 'Firebase Person',
          'photoUrl': 'https://example.com/photo.jpg',
          'phone': '+456',
          'email': 'peer@example.com',
          'fcmTokens': ['private-token'],
        },
        {'uid': 'peer', 'name': 'Duplicate'},
      ],
      currentUserId: 'me',
      connectedOrPendingIds: {'connected'},
    );

    expect(users, [
      {
        'uid': 'peer',
        'name': 'Firebase Person',
        'photoUrl': 'https://example.com/photo.jpg',
        'phone': '',
        'gender': '',
        'age': '',
        'isRegistered': true,
      },
    ]);
  });
}
