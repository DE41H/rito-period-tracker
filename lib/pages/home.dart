import 'package:buritto/widgets/app_bar.dart';
import 'package:buritto/widgets/chat_box.dart';
import 'package:buritto/widgets/choices.dart';
import 'package:buritto/widgets/input_bar.dart';
import 'package:buritto/widgets/progress_bar.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: TitleBar(),
      body: Column(
        children: [
          ProgressBar(),
          ChatBox(),
          InputBar(),
          Choices(),
        ],
      ),
    );
  }
}
