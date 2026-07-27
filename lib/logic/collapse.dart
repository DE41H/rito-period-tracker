import 'dart:typed_data';

import 'package:buritto/logic/filter.dart';
import 'package:buritto/models/discharge.dart';
import 'package:buritto/models/flow.dart';
import 'package:buritto/models/log.dart';
import 'package:buritto/models/mood.dart';
import 'package:buritto/models/phase.dart';
import 'package:buritto/models/quantum.dart';
import 'package:buritto/models/sex.dart';
import 'package:buritto/models/sleep.dart';
import 'package:buritto/models/stress.dart';
import 'package:buritto/models/symptom.dart';
import 'package:statistics/statistics.dart';

const int _numPhases = 4;
const int _horizon = 35;

typedef _Fields = ({
  Float64List flow,
  Float64List discharge,
  Float64List stress,
  Float64List sleep,
  Float64List sex,
  Float64List symptoms,
  Float64List moods,
});

class Predictor {
  static final Predictor _instance = Predictor._internal();
  factory Predictor() => _instance;
  Predictor._internal();

  List<QuantumLog> run(final Log anchor, final BayesAnalyser analyser, final KalmanFilter kf) {
    final List<_Fields?> networkTable = _buildNetworkTable(analyser);

    final List<QuantumLog> results = [];
    for (int step = 0; step < _horizon; step++) {
      final DateTime date = anchor.date.add(Duration(days: step));
      final int cycleDay = kf.predictCycleDay(date, anchor);
      final Phase phase = kf.predictPhase(cycleDay);
      final Float64List weights = _phaseWeights(cycleDay, kf.periodLength, kf.ovulationDay, kf.cycleLength);
      final _Fields acc = _blendFields(weights, networkTable);

      results.add(QuantumLog(
        date: date,
        cycleDay: cycleDay,
        phase: phase,
        flow: _toNormalizedMap(acc.flow, Flow.values),
        discharge: _toNormalizedMap(acc.discharge, Discharge.values),
        stress: _toNormalizedMap(acc.stress, Stress.values),
        sleep: _toNormalizedMap(acc.sleep, Sleep.values),
        sex: _toNormalizedMap(acc.sex, Sex.values),
        symptoms: _toClampedMap(acc.symptoms, Symptom.values),
        moods: _toClampedMap(acc.moods, Mood.values),
      ));
    }
    return results;
  }

  static Float64List _phaseWeights(int cycleDay, double periodLength, int ovulationDay, double cycleLength) {
    const double blend = 2.0;
    final double d = cycleDay.toDouble();

    double alpha(double b) => ((d - b) / blend + 0.5).clamp(0.0, 1.0);

    final double a1 = alpha(periodLength);
    final double a2 = alpha(ovulationDay - 1.5);
    final double a3 = alpha(ovulationDay + 1.5);

    return Float64List.fromList([1 - a1, a1 - a2, a2 - a3, a3]);
  }

  static _Fields _blendFields(Float64List weights, List<_Fields?> networkTable) {
    final _Fields acc = (
      flow: Float64List(Flow.values.length),
      discharge: Float64List(Discharge.values.length),
      stress: Float64List(Stress.values.length),
      sleep: Float64List(Sleep.values.length),
      sex: Float64List(Sex.values.length),
      symptoms: Float64List(Symptom.values.length),
      moods: Float64List(Mood.values.length),
    );
    for (int phase = 0; phase < _numPhases; phase++) {
      final double w = weights[phase];
      if (w < 1e-9) continue;
      final _Fields? f = networkTable[phase];
      if (f == null) continue;
      _accumulate(acc.flow, f.flow, w);
      _accumulate(acc.discharge, f.discharge, w);
      _accumulate(acc.stress, f.stress, w);
      _accumulate(acc.sleep, f.sleep, w);
      _accumulate(acc.sex, f.sex, w);
      _accumulate(acc.symptoms, f.symptoms, w);
      _accumulate(acc.moods, f.moods, w);
    }
    return acc;
  }

  static void _accumulate(Float64List dst, Float64List src, double w) {
    for (int i = 0; i < dst.length; i++) {
      dst[i] += src[i] * w;
    }
  }

  static List<_Fields?> _buildNetworkTable(BayesAnalyser analyser) {
    final List<String> questions = [];
    final Map<String, (int, String, int)> meta = {};

    for (int ph = 0; ph < _numPhases; ph++) {
      final String ctx = 'PHASE=${Phase.values[ph].name.toUpperCase()}';
      void addField<T extends Enum>(List<T> values, String field, String Function(T) prefix) {
        for (final v in values) {
          final String question = '${prefix(v)} | $ctx';
          questions.add(question);
          meta[question] = (ph, field, v.index);
        }
      }
      addField(Flow.values, 'flow', (v) => 'FLOW=${v.name.toUpperCase()}');
      addField(Discharge.values, 'discharge', (v) => 'DISCHARGE=${v.name.toUpperCase()}');
      addField(Stress.values, 'stress', (v) => 'STRESS=${v.name.toUpperCase()}');
      addField(Sleep.values, 'sleep', (v) => 'SLEEP=${v.name.toUpperCase()}');
      addField(Sex.values, 'sex', (v) => 'SEX=${v.name.toUpperCase()}');
      addField(Symptom.values, 'symptom', (v) => 'SYMPTOM_${v.name.toUpperCase()}=TRUE');
      addField(Mood.values, 'mood', (v) => 'MOOD_${v.name.toUpperCase()}=TRUE');
    }

    final Map<int, Map<String, Map<int, double>>> raw = {};
    for (final a in analyser.quiz(questions)) {
      final (int ph, String field, int idx) = meta[a.originalQuery]!;
      raw.putIfAbsent(ph, () => {}).putIfAbsent(field, () => {})[idx] = a.probability;
    }

    return List.generate(_numPhases, (ph) {
      final v = raw[ph];
      if (v == null) return null;
      return (
        flow: _normalizedVector(v['flow'] ?? {}, Flow.values.length),
        discharge: _normalizedVector(v['discharge'] ?? {}, Discharge.values.length),
        stress: _normalizedVector(v['stress'] ?? {}, Stress.values.length),
        sleep: _normalizedVector(v['sleep'] ?? {}, Sleep.values.length),
        sex: _normalizedVector(v['sex'] ?? {}, Sex.values.length),
        symptoms: _probabilityVector(v['symptom'] ?? {}, Symptom.values.length),
        moods: _probabilityVector(v['mood'] ?? {}, Mood.values.length),
      );
    });
  }

  static Float64List _normalizedVector(Map<int, double> raw, int count) {
    final Float64List v = Float64List(count);
    for (int i = 0; i < count; i++) {
      v[i] = raw[i] ?? 0.0;
    }
    final double s = v.sum;
    if (s == 0.0) {
      v.fillRange(0, count, 1.0 / count);
      return v;
    }
    for (int i = 0; i < count; i++) {
      v[i] /= s;
    }
    return v;
  }

  static Float64List _probabilityVector(Map<int, double> raw, int count) {
    final Float64List v = Float64List(count);
    for (int i = 0; i < count; i++) {
      v[i] = raw[i] ?? 0.5;
    }
    return v;
  }

  static Map<T, double> _toNormalizedMap<T extends Enum>(Float64List acc, List<T> values) {
    final double s = acc.sum;
    if (s < 1e-9) return {for (final e in values) e: 0.0};
    return {for (final e in values) e: acc[e.index] / s};
  }

  static Map<T, double> _toClampedMap<T extends Enum>(Float64List acc, List<T> values) =>
      {for (final e in values) e: acc[e.index].clamp(0.0, 1.0)};
}
