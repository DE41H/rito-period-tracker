import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:buritto/providers/settings_provider.dart';

class TitleBar extends StatelessWidget implements PreferredSizeWidget {
  const TitleBar({super.key});

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      title: Text(
        'RITO',
        style: TextStyle(
            color: Colors.black,
            fontSize: 30
        ),
      ),
      backgroundColor: Colors.white,
      scrolledUnderElevation: 0,
      actions: [
        SettingsButton(),
      ],
    );
  }
}

class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();

    return Container(
      alignment: Alignment.center,
      margin: EdgeInsets.all(7),
      child: TextButton(
        onPressed: () {
          final nav = Navigator.of(context);
          provider.toggleSettings(nav);
        },
        child: RepaintBoundary(
          child: AnimatedRotation(
            turns: provider.iconAngle,
            duration: Duration(milliseconds: 0),
            curve: Curves.easeOut,
            child: Text(
              '#',
              style: TextStyle(
                fontSize: 20,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
