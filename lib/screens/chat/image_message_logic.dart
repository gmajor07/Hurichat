Map<String, dynamic> buildImageMessageFields({
  required String senderId,
  required String receiverId,
  required String imageUrl,
}) {
  return {
    'senderId': senderId,
    'receiverId': receiverId,
    'text': 'Photo',
    'type': 'image',
    'imageUrl': imageUrl,
    'isRead': false,
  };
}

String imageContentTypeForPath(String path) {
  final extension = imageFileExtension(path);
  return switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    _ => 'image/jpeg',
  };
}

String imageFileExtension(String path) {
  final fileName = path.split(RegExp(r'[/\\]')).last;
  final extensionSeparator = fileName.lastIndexOf('.');
  if (extensionSeparator < 0 || extensionSeparator == fileName.length - 1) {
    return 'jpg';
  }
  final extension = fileName.substring(extensionSeparator + 1).toLowerCase();
  return RegExp(r'^[a-z0-9]+$').hasMatch(extension) ? extension : 'jpg';
}

String imageMessageFailureText({required bool cancelled}) {
  return cancelled
      ? 'Image upload cancelled.'
      : 'Could not send image. Please try again.';
}

Future<T?> uploadImageSafely<T>(
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
