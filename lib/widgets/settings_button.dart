import 'package:buritto/extensions/settings_button.dart';
import 'package:buritto/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SettingsProvider>();
    final iconAngle = context.select<SettingsProvider, double>((s) => s.iconAngle);

    return TextButton(
      onPressed: () => provider.toggleSettings(Navigator.of(context)),
      child: RepaintBoundary(
        child: AnimatedRotation(
          turns: iconAngle,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: Text(
            '#',
            style: context.comicMessageText,
          ),
        ),
      ),
    )
    .center()
    .paddingAll(7);
  }
}
