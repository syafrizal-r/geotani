import 'dart:convert';

import 'package:crypto/crypto.dart';

class PasswordHasher {
  PasswordHasher._();

  static String hash(String plainText) {
    return sha256.convert(utf8.encode(plainText)).toString();
  }

  static bool verify(String plainText, String hash) {
    return PasswordHasher.hash(plainText) == hash;
  }
}
