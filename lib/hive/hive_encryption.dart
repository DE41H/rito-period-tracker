import 'dart:convert';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class HiveEncryption {
  static final HiveEncryption _instance = HiveEncryption._internal();
  factory HiveEncryption() => _instance;
  HiveEncryption._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String> _getKey() async {
    String? key = await _storage.read(key: 'burittoHiveEncryptionKey');
    if (key == null) {
      key = base64.encode(Hive.generateSecureKey());
      await _storage.write(key: 'burittoHiveEncryptionKey', value: key);
    }
    return key;
  }

  Future<HiveAesCipher> _getCipher() async {
    final String key = await _getKey();
    return HiveAesCipher(base64Decode(key));
  }

  Future<HiveAesCipher> get cipher async => await _getCipher();
}
