import 'package:buritto/models/phase.dart';
import 'package:buritto/models/quantum.dart';
import 'package:flutter/material.dart';

class CalendarCell extends StatelessWidget {
  const CalendarCell({super.key, this.q});

  final QuantumLog? q;

  @override
  Widget build(BuildContext context) {
    late final double progress;
    switch (q?.phase) {
      case null:
        progress = 0.0;
      case Phase.menstrual:
        progress = 0.25;
      case Phase.follicular:
        progress = 0.50;
      case Phase.ovulatory:
        progress = 0.75;
      case Phase.luteal:
        progress = 1.00;
    }

    return Card(
      elevation: 0,
      child: Stack(
        children: [
          Center(
            child: Text(
              '${(progress == 0) ? '' : q!.date.day }'
            ),
          ),
          if (progress != 0) Center(
            child: CircularProgressIndicator(
              value: progress,
              color: Colors.black,
            ),
          )
        ],
      ),
    );
  }
}
