import 'package:statistics/statistics.dart';

import 'package:buritto/models/log.dart';
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

  static QuantumLog predict(DateTime date, Log last, Log? prev, BayesAnalyser analyser) {
    final KalmanFilter kalmanFilter = KalmanFilter();
    final int cycleDay = kalmanFilter.predictCycleDay(date, last);
    final Phase phase = kalmanFilter.predictPhase(cycleDay);

    final List<String> evidence = [
      'PHASE=${phase.name.toUpperCase()}',
      if (prev != null) 'PREV_PHASE=${prev.phase.name.toUpperCase()}',
      if (prev != null) 'PREV_FLOW=${prev.flow.name.toUpperCase()}',
    ];

    return QuantumLog(
      date: date,
      cycleDay: cycleDay,
      phase: phase,
      flow: _queryEnum(Flow.values, 'FLOW', (f) => f.name.toUpperCase(), evidence, analyser),
      discharge: _queryEnum(Discharge.values,'DISCHARGE',(d) => d.name.toUpperCase(), evidence, analyser),
      stress: _queryEnum(Stress.values, 'STRESS', (s) => s.name.toUpperCase(), evidence, analyser),
      sleep: _queryEnum(Sleep.values, 'SLEEP', (s) => s.name.toUpperCase(), evidence, analyser),
      sex: _queryEnum(Sex.values, 'SEX', (s) => s.name.toUpperCase(), evidence, analyser),
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
    final List<String> queries = [ for (final v in values) '$varName=${toName(v)}$suffix' ];
    final List<Answer> answers = analyser.quiz(queries);
    final Map<String, double> probs = { for (final a in answers) a.originalQuery: a.probability };
    final Map<T, double> raw = {
      for (final v in values) v: probs['$varName=${toName(v)}$suffix'] ?? 0.0,
    };
    final double total = raw.values.fold(0.0, (s, p) => s + p);
    if (total == 0.0) return raw;
    return { for (final e in raw.entries) e.key: e.value / total };
  }

  static Map<T, double> _queryBool<T>(
    List<T> values,
    String Function(T) toVarName,
    List<String> evidence,
    BayesAnalyser analyser,
  ) {
    final String ev = evidence.join(',');
    final String suffix = ev.isNotEmpty ? '|$ev' : '';
    final List<String> queries = [ for (final v in values) '${toVarName(v)}=TRUE$suffix' ];
    final List<Answer> answers = analyser.quiz(queries);
    final Map<String, double> probs = { for (final a in answers) a.originalQuery: a.probability };
    final Map<T, double> result = {
      for (final v in values) v: probs['${toVarName(v)}=TRUE$suffix'] ?? 0.0,
    };
    return result;
  }
}
