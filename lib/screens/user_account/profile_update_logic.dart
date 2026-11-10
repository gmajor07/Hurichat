typedef ProfileUpdateErrorHandler =
    void Function(Object error, StackTrace stackTrace);

Map<String, Object?> buildProfileUpdateFields({
  required String name,
  required String age,
  required String gender,
  String? photoUrl,
}) {
  final trimmedAge = age.trim();
  final trimmedGender = gender.trim();
  return {
    'name': name.trim(),
    'age': trimmedAge.isEmpty ? null : int.tryParse(trimmedAge),
    'gender': trimmedGender.isEmpty ? null : trimmedGender,
    if (photoUrl != null) 'photoUrl': photoUrl,
  };
}

Future<String?> uploadProfilePhotoSafely(
  Future<String?> Function() upload, {
  required ProfileUpdateErrorHandler onError,
}) async {
  try {
    return await upload();
  } catch (error, stackTrace) {
    onError(error, stackTrace);
    return null;
  }
}

String profileStringValue(dynamic value, {required String fallback}) {
  if (value is String && value.trim().isNotEmpty) return value;
  return fallback;
}
