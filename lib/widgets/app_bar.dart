import 'package:buritto/widgets/progress_bar.dart';
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
      actions: const [
        Text(
          'Made with ♥️ for Bhuvi',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
          ),
        ),
      ],
      actionsPadding: const EdgeInsets.all(8),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: ProgressBar(),
      ),
      scrolledUnderElevation: 0,
    );
  }
}
