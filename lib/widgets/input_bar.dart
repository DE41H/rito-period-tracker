import 'package:buritto/extensions/input_bar.dart';
import 'package:buritto/providers/home_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class InputBar extends StatelessWidget {
  const InputBar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<HomeProvider>();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: provider.inputController,
              style: context.comicInputText,
              maxLines: null,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '...',
                isDense: true,
              ),
            ),
          ),
          TextButton(
            onPressed: provider.sendMessage,
            child: Text(
              '->',
              style: context.comicButtonText,
            ),
          ),
        ],
      ),
    );
  }
}