import 'package:statistics/statistics.dart';

import 'package:buritto/models/log.dart';
import 'package:buritto/logic/network.dart';
import 'package:buritto/logic/filter.dart';

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

  static QuantumLog predict(DateTime date, Log last, Log? prev) {
    final int cycleDay = KalmanFilter().predictCycleDay(date, last);
    final Phase phase = KalmanFilter().predictPhase(cycleDay);

    final List<String> evidence = [
      'PHASE=${phase.name.toUpperCase()}',
      if (prev != null) 'PREV_PHASE=${prev.phase.name.toUpperCase()}',
      if (prev != null) 'PREV_FLOW=${prev.flow.name.toUpperCase()}',
    ];

    return QuantumLog(
      date: date,
      cycleDay: cycleDay,
      phase: phase,
      flow: _query(Flow.values, evidence),
      discharge: _query(Discharge.values, evidence),
      stress: _query(Stress.values, evidence),
      sleep: _query(Sleep.values, evidence),
      sex: _query(Sex.values, evidence),
      symptoms: _query(Symptom.values, evidence),
      moods: _query(Mood.values, evidence),
    );
  }

  static Map<T, double> _query<T extends Enum>(
    List<T> values,
    List<String> evidence,
  ) {
    final String ev = evidence.join(', ');
    final bool isEnum = {Flow, Discharge, Stress, Sleep, Sex}.contains(T);
    final bool isBool = {Symptom, Mood}.contains(T);

    final List<String> questions;
    if (isEnum) {
      questions = [ for (final v in values) 'P(${T.toString().toUpperCase()}=${v.name.toUpperCase()}|$ev)' ];
    } else if (isBool) {
      questions = [ for (final v in values) 'P(${T.toString().toUpperCase()}_${v.name.toUpperCase()}=TRUE|$ev)' ];
    } else {
      throw ArgumentError("Unsupported Type: ${T.toString()}");
    }

    final List<Answer> answers = BayesNetwork().analyser.quiz(questions);
    final Map<String, double> probabilities = { for (final a in answers) a.originalQuery: a.probability };

    final Map<T, double> raw;
    if (isEnum) {
      raw = { for (final v in values) v: probabilities['P(${T.toString().toUpperCase()}=${v.name.toUpperCase()}|$ev)'] ?? 0.0 };
    } else if (isBool) {
      raw = { for (final v in values) v: probabilities['P(${T.toString().toUpperCase()}_${v.name.toUpperCase()}=TRUE|$ev)'] ?? 0.0 };
    } else {
      throw ArgumentError("Unsupported Type: ${T.toString()}");
    }

    final double total = raw.values.sum;
    final Map<T, double> result;
    if (total == 0.0) {
      result = raw;
    } else {
      result = { for (final e in raw.entries) e.key: e.value / total };
    }

    return result;
  }
}
