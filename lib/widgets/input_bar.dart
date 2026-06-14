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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(5)),
        border: Border.fromBorderSide(BorderSide(color: Colors.black, width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: provider.inputController,
              style: const TextStyle(
                fontFamily: 'Hey-Comic',
                fontSize: 16,
                color: Colors.black,
              ),
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
            child: const Text(
              '->',
              style: TextStyle(
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
