import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/home_provider.dart';

class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeProvider>();

    return Container(
      margin: EdgeInsets.all(7),
      alignment: Alignment.topCenter,
      child: LinearProgressIndicator(
        value: provider.progress,
        minHeight: 4,
        backgroundColor: Colors.white,
        color: Colors.black,
        borderRadius: BorderRadius.circular(7),
      ),
    );

  }
}