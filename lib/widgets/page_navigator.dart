import 'package:buritto/pages/home.dart';
import 'package:buritto/pages/settings.dart';
import 'package:flutter/material.dart';

class PageNavigator extends StatelessWidget {
  const PageNavigator({super.key});

  static final PageController _controller = PageController(initialPage: 1);
  static const int _limit = 100000000;
  static const _pages = [SettingsPage(), HomePage()];

  Widget _itemBuilder(BuildContext context, final int index) => _pages[index % _pages.length];

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      itemCount: _limit,
      physics: const BouncingScrollPhysics(),
      itemBuilder: _itemBuilder,
    );
  }
}
