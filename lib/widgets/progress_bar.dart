import 'package:buritto/providers/home_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.select<HomeProvider, double>((s) => s.progress);

    return Padding(
      padding: const EdgeInsets.all(7.0),
      child: Align(
        alignment: Alignment.topCenter,
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 4,
          backgroundColor: Colors.white,
          color: Colors.black,
          borderRadius: BorderRadius.circular(7),
        )
      ),
    );
  }
}
