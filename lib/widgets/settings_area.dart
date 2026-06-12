import 'package:buritto/widgets/biometric_switch.dart';
import 'package:buritto/widgets/birthday_picker.dart';
import 'package:buritto/widgets/pcos_switch.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SettingsArea extends StatelessWidget {
  const SettingsArea({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.all(7),
        children: const [
          BirthdayPicker(),
          PcosSwitch(),
          BiometricSwitch(),
        ],
      ),
    );
  }
}
