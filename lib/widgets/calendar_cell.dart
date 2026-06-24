import 'package:buritto/hive/hive_database.dart';
import 'package:buritto/logic/filter.dart';
import 'package:buritto/models/log.dart';
import 'package:buritto/models/phase.dart';
import 'package:buritto/models/quantum.dart';
import 'package:buritto/sheets/quantum_log.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/adapters.dart';

class CalendarCell extends StatelessWidget {
  const CalendarCell({super.key, required this.date});

  final DateTime date;
  
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: HiveDatabase().predictions.listenable(keys: [LogRepo().dateToString(date)]),
      builder: (context, value, child) {
        return FutureBuilder(
          future: value.get(LogRepo().dateToString(date)),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const EmptyCell();
            }
            final QuantumLog? q = snapshot.data;
            final double progress = q == null ? 0.0 : (q.cycleDay / KalmanFilter().cycleLength).clamp(0.0, 1.0);
            return InkWell(
              onTap: () => (q == null) ? null : QuantumLogModal().show(context, q),
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
                        color: q!.phase == Phase.menstrual ? Colors.red : Colors.black,
                      ),
                    )
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }
}

class EmptyCell extends StatelessWidget {
  const EmptyCell({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      elevation: 0,
    );
  }
}
