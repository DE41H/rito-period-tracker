import 'package:buritto/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});
  
  void _onPressed(BuildContext context) => context.read<SettingsProvider>().toggleSettings(Navigator.of(context));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(7.0),
      child: Center(
        child: TextButton(
          onPressed: () => _onPressed(context),
          child: const RepaintBoundary(
            child: SettingsButtonAnimation(),
          ),
        )
      ),
    );
  }
}

class SettingsButtonAnimation extends StatelessWidget {
  const SettingsButtonAnimation({super.key});

  @override
  Widget build(BuildContext context) {
    final iconAngle = context.select<SettingsProvider, double>((s) => s.iconAngle);

    return AnimatedRotation(
      turns: iconAngle,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: const Text(
        '#',
        style: TextStyle(
          fontSize: 20,
          color: Colors.black,
          fontFamily: 'Hey-Comic',
        ),
      ),
    );
  }
}
