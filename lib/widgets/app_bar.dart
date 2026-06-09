import 'package:buritto/extensions/app_bar.dart';
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
      title: Text(
        'RITO',
        style: context.comicTitleText,
      ),
      backgroundColor: Colors.white,
      scrolledUnderElevation: 0,
      actions: const [
        SettingsButton(),
      ],
    );
  }
}
