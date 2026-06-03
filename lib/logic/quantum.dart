import 'package:statistics/statistics.dart';

import 'package:buritto/models/log.dart';
import 'package:buritto/logic/filter.dart';

class QuantumLog {
  final DateTime date;
  final int cycleDay;
  final Map<Phase, double> phase;
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

  static QuantumLog predict(DateTime date, Log? last, BayesAnalyser analyser) {
    final int cycleDay;
    final Phase predictedPhase;

    if (last == null) {
      cycleDay = 1;
      predictedPhase = Phase.menstrual;
    } else {
      final int elapsed = date.difference(last.date).inDays;
      final filter = KalmanFilter();
      cycleDay = ((last.cycleDay + elapsed - 1) % filter.cycleLength).floor() + 1;
      predictedPhase = filter.predictPhase(cycleDay);
    }

    final List<String> evidence = [
      'PHASE=${predictedPhase.name}',
      if (last != null) 'PREV_PHASE=${last.phase.name}',
      if (last != null) 'PREV_FLOW=${last.flow.name}',
    ];

    return QuantumLog(
      date: date,
      cycleDay: cycleDay,
      phase: _queryEnum(Phase.values, 'PHASE', (p) => p.name, evidence, analyser),
      flow: _queryEnum(Flow.values, 'FLOW', (f) => f.name, evidence, analyser),
      discharge: _queryEnum(Discharge.values,'DISCHARGE',(d) => d.name, evidence, analyser),
      stress: _queryEnum(Stress.values, 'STRESS', (s) => s.name, evidence, analyser),
      sleep: _queryEnum(Sleep.values, 'SLEEP', (s) => s.name, evidence, analyser),
      sex: _queryEnum(Sex.values, 'SEX', (s) => s.name, evidence, analyser),
      symptoms: _queryBool(Symptom.values, (s) => 'SYMPTOM_${s.name}', evidence, analyser),
      moods: _queryBool(Mood.values, (m) => 'MOOD_${m.name}', evidence, analyser),
    );
  }

  static Map<T, double> _queryEnum<T>(
    List<T> values,
    String varName,
    String Function(T) toName,
    List<String> evidence,
    BayesAnalyser analyser,
  ) {
    final String ev = evidence.where((e) => !e.startsWith('$varName=')).join(',');
    final String suffix = ev.isNotEmpty ? '|$ev' : '';
    return { for (final v in values) v: analyser.ask('$varName=${toName(v)}$suffix').probability };
  }

  static Map<T, double> _queryBool<T>(
    List<T> values,
    String Function(T) toVarName,
    List<String> evidence,
    BayesAnalyser analyser,
  ) {
    final result = <T, double>{};
    for (final v in values) {
      final String varName = toVarName(v);
      final String ev = evidence.where((e) => !e.startsWith('$varName=')).join(',');
      final String suffix = ev.isNotEmpty ? '|$ev' : '';
      result[v] = analyser.ask('$varName=true$suffix').probability;
    }
    return result;
  }
}