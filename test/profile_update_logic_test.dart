import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/screens/user_account/profile_update_logic.dart';

void main() {
  test(
    'profile patch contains only editable fields and optional photo URL',
    () {
      final update = buildProfileUpdateFields(
        name: '  Asha  ',
        age: '29',
        gender: '  Woman ',
      );

      expect(update, {'name': 'Asha', 'age': 29, 'gender': 'Woman'});
      expect(update.containsKey('photoUrl'), isFalse);
      expect(update.containsKey('status'), isFalse);
      expect(update.containsKey('lastSeen'), isFalse);
    },
  );

  test('empty optional fields clear values and uploaded photo is included', () {
    final update = buildProfileUpdateFields(
      name: 'Asha',
      age: '',
      gender: ' ',
      photoUrl: 'https://example.test/asha.jpg',
    );

    expect(update['age'], isNull);
    expect(update['gender'], isNull);
    expect(update['photoUrl'], 'https://example.test/asha.jpg');
  });

  test(
    'photo upload failure is reported and returns no replacement URL',
    () async {
      Object? reportedError;
      final result = await uploadProfilePhotoSafely(
        () async => throw StateError('upload failed'),
        onError: (error, _) => reportedError = error,
      );

      expect(result, isNull);
      expect(reportedError, isA<StateError>());
    },
  );

  test(
    'profile values fall back safely for unavailable or malformed values',
    () {
      expect(profileStringValue(null, fallback: 'Unavailable'), 'Unavailable');
      expect(profileStringValue(42, fallback: 'Unavailable'), 'Unavailable');
      expect(profileStringValue('  ', fallback: 'Unavailable'), 'Unavailable');
      expect(profileStringValue('Asha', fallback: 'Unavailable'), 'Asha');
    },
  );
}
