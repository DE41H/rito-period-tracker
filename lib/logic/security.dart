import 'dart:io';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'package:buritto/hive/hive_database.dart';

class BiometricAuth {
  static final BiometricAuth _instance = BiometricAuth._internal();
  factory BiometricAuth() => _instance;
  BiometricAuth._internal();

  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isAvailable() async {
    if (Platform.isLinux) return false;
    final canCheck = await _auth.canCheckBiometrics;
    final isSupported = await _auth.isDeviceSupported();
    return canCheck && isSupported;
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
    if (!authenticated) SystemNavigator.pop();
  }
}
