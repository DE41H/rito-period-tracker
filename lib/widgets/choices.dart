import 'package:buritto/providers/home_provider.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Choices extends StatelessWidget {
  const Choices({super.key});
  
  @override
  Widget build(BuildContext context) {
    final int length = context.select<HomeProvider, int>((h) => h.choices.length);
    if (length == 0) return const SizedBox.shrink();

    final Iterable<List<int>> rows = List.generate(length, (i) => i, growable: false).slices(3);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Column(children: rows.map((i) => ChoiceRow(ids: i)).toList(growable: false)),
    );
  }
}

class ChoiceRow extends StatelessWidget {
  const ChoiceRow({super.key, required this.ids});

  final List<int> ids;

  @override
  Widget build(BuildContext context) {
    if (ids.isEmpty || ids.length > 3) return const SizedBox.shrink();

    return Row(
      children: [
        if (ids.length == 3) ...[
          Expanded(flex: 2, child: Choice(id: ids[0])),
          Expanded(flex: 2, child: Choice(id: ids[1])),
          Expanded(flex: 2, child: Choice(id: ids[2])),
        ]
        else if (ids.length == 2) ...[
          const Expanded(flex: 1, child: SizedBox.shrink()),
          Expanded(flex: 2, child: Choice(id: ids[0])),
          Expanded(flex: 2, child: Choice(id: ids[1])),
          const Expanded(flex: 1, child: SizedBox.shrink()),
        ]
        else if (ids.length ==1) ...[
          const Expanded(flex: 2, child: SizedBox.shrink()),
          Expanded(flex: 2, child: Choice(id: ids[0])),
          const Expanded(flex: 2, child: SizedBox.shrink())
        ]
      ]
    );
  }
}

class Choice extends StatelessWidget {
  const Choice({super.key, required this.id});

  final int id;

  void onPressed() => print("button $id pressed");
  
  @override
  Widget build(BuildContext context) {
    final String? choice = context.select<HomeProvider, String?>((h) => id < h.choices.length ? h.choices[id] : null);
    if (choice == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(7),
        color: Colors.white
      ),
      margin: const EdgeInsets.all(7),
      child: TextButton(
        onPressed: onPressed,
        child: Text(
          choice,
          style: const TextStyle(
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
