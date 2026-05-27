import 'package:flutter/material.dart';

import 'package:buritto/widgets/app_bar.dart';
import 'package:buritto/widgets/chat.dart';
import 'package:buritto/widgets/progress_bar.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleBar(),
      body: Column(
        children: [
          ProgressBar(),
          ChatArea(),
          InputBar(),
          ChoicesArea(),
        ],
      ),
    );
  }
}
