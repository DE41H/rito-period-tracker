import 'package:buritto/widgets/app_bar.dart';
import 'package:buritto/widgets/page_navigator.dart';
import 'package:flutter/material.dart';

class DefaultPage extends StatelessWidget {
  const DefaultPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: TitleBar(),
      body: Expanded(child: PageNavigator()),
    );
  }
}
