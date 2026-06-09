import 'package:buritto/models/log.dart';

class QuantumLog {
  final DateTime date;
  final int cycleDay;
  final Phase phase;
  final Map<Flow, double> flow;
  final Map<Symptom, double> symptoms;
  final Map<Mood, double> moods;
  final Map<Discharge, double> discharge;
  final Map<Stress, double> stress;
  final Map<Sleep, double> sleep;
  final Map<Sex, double> sex;

  const QuantumLog({
    required this.date,
    required this.cycleDay,
    required this.phase,
    required this.flow,
    required this.symptoms,
    required this.moods,
    required this.discharge,
    required this.stress,
    required this.sleep,
    required this.sex,
  });
}
