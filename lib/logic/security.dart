import 'dart:async';
import 'dart:io';

import 'package:buritto/hive/hive_database.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAuth {
  static final BiometricAuth _instance = BiometricAuth._internal();
  factory BiometricAuth() => _instance;
  BiometricAuth._internal();

  final LocalAuthentication _auth = LocalAuthentication();
  late final bool available;

  Future<void> init() async {
    if (Platform.isLinux) {
      available = false;
      return;
    }
    final (canCheck, isSupported) = await (
      _auth.canCheckBiometrics,
      _auth.isDeviceSupported(),
    ).wait;
    available = canCheck && isSupported;
  }

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Authenticate to access Rito',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: true,
      );
    } catch (e) {
      return false;
    }
  }

  Future<void> lock() async {
    final bool lockable = HiveDatabase().settings.get('biometricLock') as bool? ?? false;
    if (!lockable) return;
    final authenticated = await authenticate();
    if (!authenticated) unawaited(SystemNavigator.pop());
  }
}
