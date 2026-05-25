import 'package:buritto/widgets/settings_area.dart';
import 'package:flutter/material.dart';

import '../widgets/app_bar.dart';
import '../widgets/progress_bar.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleBar(),
      body: Column(
        children: [
          ProgressBar(),
          SettingsArea(),
        ],
      ),
      bottomNavigationBar: Text(
        'Made with ♥️ for Bhuvi by Sreyash',
        textAlign: TextAlign.center,
      ),
    );
  }
}
