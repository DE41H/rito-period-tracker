import 'package:buritto/widgets/app_bar.dart';
import 'package:buritto/widgets/progress_bar.dart';
import 'package:buritto/widgets/settings_area.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: TitleBar(),
      body: Column(
        children: [
          ProgressBar(),
          SettingsArea(),
        ],
      ),
      bottomNavigationBar: Text(
        'Made with ♥️ for Bhuvi',
        textAlign: TextAlign.center,
      ),
    );
  }
}
