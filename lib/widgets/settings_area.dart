import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:provider/provider.dart';

import 'package:buritto/hive/hive_database.dart';
import 'package:buritto/logic/security.dart';
import 'package:buritto/providers/settings_provider.dart';

class SettingsArea extends StatelessWidget {
  const SettingsArea({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ListView(
        padding: EdgeInsets.all(7),
        children: [
          BirthdayPicker(),
          MinimalPcosSwitch(),
          MinimalBiometricSwitch(),
        ],
      ),
    );
  }
}

class MinimalPcosSwitch extends StatelessWidget {
  const MinimalPcosSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SettingsProvider>();
    final isReseeding = context.select<SettingsProvider, bool>((s) => s.isReseeding);

    return ListTile(
      title: Text(
        'Having Pcos',
        style: TextStyle(
          fontSize: 20,
          color: Colors.black,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (provider.isReseeding) CupertinoActivityIndicator(),
          ValueListenableBuilder(
            valueListenable: HiveDatabase().settings.listenable(keys: ['hasPcos']),
            builder: (context, value, child) {
              return CupertinoSwitch(
                value: value.get('hasPcos', defaultValue: false),
                onChanged: isReseeding ? null : (val) {
                  value.put('hasPcos', val);
                  provider.reseed(val);
                },
                activeTrackColor: Colors.black,
              );
            }
          ),
        ],
      ),
    );
  }
}

class MinimalBiometricSwitch extends StatelessWidget {
  const MinimalBiometricSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: BiometricAuth().isAvailable(),
      builder: (context, asyncSnapshot) {
        if (!asyncSnapshot.hasData || !asyncSnapshot.data!) return SizedBox();
        return ListTile(
          title: Text(
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
                  value: value.get('biometricLock', defaultValue: false),
                  onChanged: (val) async {
                    if (val) {
                      final ok = await BiometricAuth().authenticate();
                      if (ok) value.put('biometricLock', true);
                    } else {
                      value.put('biometricLock', false);
                    }
                  },
                  activeTrackColor: Colors.black,
                );
              }
          ),
        );
      }
    );
  }
}

class BirthdayPicker extends StatelessWidget {
  const BirthdayPicker({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        'Birthday',
        style: TextStyle(
          fontSize: 20,
          color: Colors.black,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MinimalCupertinoSettingsPicker(
            variable: 'birthMonth',
            children: ['Jan','Feb','Mar','Apr','May','Jun', 'Jul','Aug','Sep','Oct','Nov','Dec'],
            defaultValue: 1,
          ),
          MinimalCupertinoSettingsPicker(
            variable: 'birthYear',
            children: List.generate(
              DateTime.now().year - 1950,
              (i) => (i + 1950).toString(),
            ),
            defaultValue: 2000,
            offset: 1950,
          ),
        ],
      ),
    );
  }
}

class MinimalCupertinoSettingsPicker extends StatelessWidget {
  final String variable;
  final List<String> children;
  final int defaultValue;
  final int offset;

  const MinimalCupertinoSettingsPicker({super.key, required this.variable,required this.children, required this.defaultValue, this.offset = 1});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 100,
      child: ValueListenableBuilder(
        valueListenable: HiveDatabase().settings.listenable(keys: [variable]),
        builder: (context, value, child) {
          return CupertinoPicker(
            itemExtent: 50,
            diameterRatio: 100,
            scrollController: FixedExtentScrollController(
              initialItem: value.get(variable, defaultValue: defaultValue) - offset,
            ),
            onSelectedItemChanged: (i) => value.put(variable, i + offset),
            children: children
              .map((m) => Center(
              child: Text(
                m,
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.black,
                  fontFamily: 'Shifa-Rame',
                ),
              )
            )).toList(),
          );
        }
      ),
    );
  }
}
