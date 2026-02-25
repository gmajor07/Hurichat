import 'dart:convert';

import 'package:crypto/crypto.dart';

String normalizePhoneNumber(String input) {
  final digitsOnly = input.replaceAll(RegExp(r'[^0-9+]'), '');
  if (digitsOnly.startsWith('00')) {
    return '+${digitsOnly.substring(2)}';
  }
  return digitsOnly;
}

String hashPhoneNumber(String normalizedPhoneNumber) {
  final bytes = utf8.encode(normalizedPhoneNumber.trim());
  return sha256.convert(bytes).toString();
}
