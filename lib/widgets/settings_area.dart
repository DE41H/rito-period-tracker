import 'package:buritto/logic/security.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';

class SettingsArea extends StatelessWidget {
  const SettingsArea({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ListView(
        padding: EdgeInsets.all(7),
        children: [
          BirthdayPicker(),
          SettingsSlider(text: 'Weight', unit: 'Kg', variable: 'weight', min: 30, max: 150, divisions: 24),
          SettingsSlider(text: 'Height', unit: 'cm', variable: 'height', min: 120, max: 200, divisions: 16),
          MinimalSettingsSwitch(variable: 'hormonalBirthControl', text: 'On Birth Control'),
          MinimalSettingsSwitch(variable: 'tryingForPregnancy', text: 'Trying For Pregnancy'),
          MinimalSettingsSwitch(variable: 'hasPcos', text: 'Having PCOS'),
          MinimalSettingsSwitch(variable: 'smokes', text: 'Smoking Regularly'),
          MinimalSettingsSwitch(variable: 'drinks', text: 'Drinking Regularly'),
          MinimalBiometricSwitch(),
        ],
      ),
    );
  }
}

class MinimalSettingsSwitch extends StatelessWidget {
  final String variable;
  final String text;

  const MinimalSettingsSwitch({super.key, required this.variable, required this.text});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        text,
        style: TextStyle(
          fontSize: 20,
          color: Colors.black,
        ),
      ),
      trailing: ValueListenableBuilder(
        valueListenable: Hive.box('settings').listenable(keys: [variable]),
        builder: (context, value, child) {
          return CupertinoSwitch(
            value: value.get(variable, defaultValue: false),
            onChanged: (val) {
              value.put(variable, val);
            },
            activeTrackColor: Colors.black,
          );
        }
      ),
    );
  }
}

class MinimalBiometricSwitch extends StatelessWidget {
  const MinimalBiometricSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: BiometricAuth.isAvailable(),
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
              valueListenable: Hive.box('settings').listenable(keys: ['biometricLock']),
              builder: (context, value, child) {
                return CupertinoSwitch(
                  value: value.get('biometricLock', defaultValue: false),
                  onChanged: (val) async {
                    if (val) {
                      final ok = await BiometricAuth.authenticate();
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
          MinimalCupertinoSettingsPicker(variable: 'birthMonth', children: ['Jan','Feb','Mar','Apr','May','Jun', 'Jul','Aug','Sep','Oct','Nov','Dec']),
          MinimalCupertinoSettingsPicker(
            variable: 'birthYear',
            children: List.generate(
              DateTime.now().year - 1950,
              (i) => (i + 1950).toString(),
            )
          )
        ],
      ),
    );
  }
}

class MinimalCupertinoSettingsPicker extends StatelessWidget {
  final String variable;
  final List<String> children;

  const MinimalCupertinoSettingsPicker({super.key, required this.variable,required this.children});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 90,
      child: ValueListenableBuilder(
        valueListenable: Hive.box('settings').listenable(keys: [variable]),
        builder: (context, value, child) {
          return CupertinoPicker(
            itemExtent: 50,
            diameterRatio: 100,
            scrollController: FixedExtentScrollController(
              initialItem: value.get(variable, defaultValue: 1) - 1,
            ),
            onSelectedItemChanged: (i) => value.put(variable, i + 1),
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

class SettingsSlider extends StatelessWidget {
  final String text;
  final String unit;
  final String variable;
  final double min;
  final double max;
  final int divisions;

  const SettingsSlider({super.key, required this.text, required this.unit, required this.variable, required this.min, required this.max, required this.divisions});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: ValueListenableBuilder(
        valueListenable: Hive.box('settings').listenable(keys: [variable]),
        builder: (context, value, child) {
          return Row(
            children: [
              Text(
                '$text  ${value.get(variable, defaultValue: (min + max) / 2).toInt().toString()}$unit',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                ),
              ),
              Expanded(
                child: Slider(
                  value: value.get(variable, defaultValue: (min + max) / 2),
                  min: min,
                  max: max,
                  divisions: divisions,
                  onChanged: (val) => value.put(variable, val),
                ),
              ),
            ],
          );
        }
      ),
    );
  }
}