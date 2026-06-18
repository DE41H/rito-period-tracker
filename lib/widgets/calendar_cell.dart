import 'package:buritto/logic/filter.dart';
import 'package:buritto/models/quantum.dart';
import 'package:flutter/material.dart';

class CalendarCell extends StatelessWidget {
  const CalendarCell({super.key, this.q});

  final QuantumLog? q;

  void _onTap(BuildContext context, QuantumLog? q) {
    showModalBottomSheet<void>(
      showDragHandle: true,
      context: context,
      constraints: const BoxConstraints(
        maxWidth: double.infinity,
      ),
      builder: (BuildContext context) {
        return SizedBox(
          width: double.infinity,
          child: Text(
            q.hashCode.toString(),
          ),
        );
      }
    );
  }  
  
  @override
  Widget build(BuildContext context) {
    final double progress = q == null ? 0.0 : (q!.cycleDay / KalmanFilter().cycleLength).clamp(0.0, 1.0);

    return InkWell(
      onTap: () => _onTap(context, q),
      child: Card(
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
      ),
    );
  }
}
