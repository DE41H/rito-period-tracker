import 'package:buritto/pages/calendar.dart';
import 'package:buritto/pages/home.dart';
import 'package:buritto/pages/settings.dart';
import 'package:flutter/material.dart';

class PageNavigator extends StatelessWidget {
  const PageNavigator({super.key});

  static final PageController _controller = PageController(initialPage: 1);

  @override
  Widget build(BuildContext context) {
    return PageView(
      allowImplicitScrolling: true,
      controller: _controller,
      physics: const BouncingScrollPhysics(),
      children: const [
        SettingsPage(),
        HomePage(),
        CalendarPage()
      ],
    );
  }
}
