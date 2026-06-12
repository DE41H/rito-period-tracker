import 'dart:async';

import 'package:buritto/extensions/biometric_switch.dart';
import 'package:buritto/hive/hive_database.dart';
import 'package:buritto/logic/security.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/adapters.dart';

class BiometricSwitch extends StatelessWidget {
  const BiometricSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    if (!BiometricAuth().available) return const SizedBox.shrink();
    return ListTile(
      title: Text(
        'Biometric Lock',
        style: context.comicText,
      ),
      trailing: ValueListenableBuilder(
        valueListenable: HiveDatabase().settings.listenable(keys: ['biometricLock']),
        builder: (context, value, child) {
          return CupertinoSwitch(
            value: value.get('biometricLock', defaultValue: false) as bool,
            onChanged: (val) async {
              if (val) {
                final ok = await BiometricAuth().authenticate();
                if (ok) unawaited(value.put('biometricLock', true));
              } else {
                unawaited(value.put('biometricLock', false));
              }
            },
            activeTrackColor: Colors.black,
          );
        }
      ),
    );
  }
}
