import 'package:buritto/widgets/progress_bar.dart';
import 'package:buritto/widgets/settings_button.dart';
import 'package:flutter/material.dart';

class TitleBar extends StatelessWidget implements PreferredSizeWidget {
  const TitleBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      title: const Text(
        'RITO',
        style: TextStyle(
          color: Colors.black,
          fontSize: 30,
        ),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(18),
        child: ProgressBar(),
      ),
      backgroundColor: Colors.white,
      scrolledUnderElevation: 0,
      actions: const [
        SettingsButton(),
      ],
    );
  }
}
