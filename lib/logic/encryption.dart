import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/adapters.dart';

class HiveEncryption {
  static const _storage = FlutterSecureStorage();

  static Future<String> getOrCreateKey() async {
    final key = await _storage.read(key: 'hiveEncryptionKey') ?? base64.encode(Hive.generateSecureKey());
    await _storage.write(key: 'hiveEncryptionKey', value: key);
    return key;
  }

  static HiveAesCipher getCipher(String key) {
    return HiveAesCipher(base64Decode(key));
  }
}
