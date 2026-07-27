import 'package:buritto/models/discharge.dart';
import 'package:buritto/models/flow.dart';
import 'package:buritto/models/mood.dart';
import 'package:buritto/models/quantum.dart';
import 'package:buritto/models/sex.dart';
import 'package:buritto/models/sleep.dart';
import 'package:buritto/models/stress.dart';
import 'package:buritto/models/symptom.dart';
import 'package:flutter/material.dart' hide Flow;

class QuantumLogModal {
  static final QuantumLogModal _instance = QuantumLogModal._internal();
  factory QuantumLogModal() => _instance;
  QuantumLogModal._internal();

  void show(BuildContext context, final QuantumLog q) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => QuantumLogSheet(q: q),
    );
  }
}

class QuantumLogSheet extends StatelessWidget {
  const QuantumLogSheet({super.key, required this.q});

  final QuantumLog q;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${q.date.day}/${q.date.month}/${q.date.year}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Cycle day ${q.cycleDay} · ${q.phase.title}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            _Distribution<Flow>(label: 'Flow', map: q.flow),
            const SizedBox(height: 12),
            _Distribution<Discharge>(label: 'Discharge', map: q.discharge),
            const SizedBox(height: 12),
            _Distribution<Stress>(label: 'Stress', map: q.stress),
            const SizedBox(height: 12),
            _Distribution<Sleep>(label: 'Sleep', map: q.sleep),
            const SizedBox(height: 12),
            _Distribution<Sex>(label: 'Sex', map: q.sex),
            const SizedBox(height: 12),
            _Distribution<Symptom>(label: 'Symptoms', map: q.symptoms),
            const SizedBox(height: 12),
            _Distribution<Mood>(label: 'Mood', map: q.moods),
          ],
        ),
      ),
    );
  }
}

class _Distribution<T extends Enum> extends StatelessWidget {
  const _Distribution({required this.label, required this.map});

  final String label;
  final Map<T, double> map;

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<T, double>> entries = map.entries
        .where((e) => e.value >= 0.01)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(entry.key.name, overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: entry.value,
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${(entry.value * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
