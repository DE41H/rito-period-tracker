import 'dart:async';

import 'package:buritto/hive/hive_database.dart';
import 'package:buritto/logic/security.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/adapters.dart';

class BiometricSwitch extends StatelessWidget {
  const BiometricSwitch({super.key});

  Future<void> onChanged(bool val) async {
    if (val) {
      unawaited(HiveDatabase().settings.put('biometricLock', true));
      final ok = await BiometricAuth().authenticate();
      if (ok) {
        unawaited(HiveDatabase().settings.put('biometricLock', true));
      } else {
        unawaited(HiveDatabase().settings.put('biometricLock', false));
      }
    } else {
      unawaited(HiveDatabase().settings.put('biometricLock', false));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!BiometricAuth().available) return const SizedBox.shrink();
    return ListTile(
      title: const Text(
        'Biometric Lock',
        style: TextStyle(
          fontSize: 20,
          color: Colors.black,
        ),
      ),
      trailing: ValueListenableBuilder(
        valueListenable: HiveDatabase().settings.listenable(keys: ['biometricLock']),
        builder: (context, value, child) {
          return CupertinoSwitch(
            value: value.get('biometricLock', defaultValue: false) as bool,
            onChanged: onChanged,
            activeTrackColor: Colors.black,
          );
        }
      ),
    );
  }
}
