import 'dart:io';
import 'package:flutter/services.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAuth {
  static final _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    if (Platform.isLinux) return false;
    final canCheck = await _auth.canCheckBiometrics;
    final isSupported = await _auth.isDeviceSupported();
    return canCheck && isSupported;
  }

  static Future<bool> authenticate() async {
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

  static Future<void> lock() async {
    final locked = Hive.box('settings').get('biometricLock', defaultValue: false);
    if (!locked) return;
    final authenticated = await authenticate();
    if (!authenticated) SystemNavigator.pop();
  }
}
