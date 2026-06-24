import 'dart:math';
import 'dart:typed_data';

import 'package:buritto/logic/filter.dart';
import 'package:buritto/logic/network.dart';
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
const List<int> _next = [1, 2, 3, 0];
const int _horizon = 90;

typedef _Fields = ({
  Float64List flow,
  Float64List discharge,
  Float64List stress,
  Float64List sleep,
  Float64List sex,
  Float64List symptoms,
  Float64List moods,
});

typedef _PhaseDurations = ({
  List<Float64List> hazard,
  List<int> maxDuration,
  int stride,
});

class Hsmm {
  static final Hsmm _instance = Hsmm._internal();
  factory Hsmm() => _instance;
  Hsmm._internal();

  List<QuantumLog> run(Log anchor, double cycleLength, double periodLength, int ovulationDay) {
    final _PhaseDurations durations = _buildPhaseDurations(cycleLength, periodLength, ovulationDay);
    final List<_Fields?> networkTable = _buildNetworkTable(BayesNetwork().analyser);

    Float64List state = _initState(anchor, durations, periodLength, ovulationDay);
    final List<QuantumLog> results = [];

    for (int step = 0; step < _horizon; step++) {
      if (step > 0) state = _propagate(state, durations);

      final DateTime date = anchor.date.add(Duration(days: step));
      final Float64List probs = _phaseProbs(state, durations);
      final _Fields acc = _blendFields(probs, networkTable);
      final int cycleDay = KalmanFilter().predictCycleDay(date, anchor);

      results.add(QuantumLog(
        date: date,
        cycleDay: cycleDay,
        phase: KalmanFilter().predictPhase(cycleDay),
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

  static _PhaseDurations _buildPhaseDurations(
      double cycleLength, double periodLength, int ovulationDay) {
    final List<double> means = [
      periodLength,
      max(1.0, ovulationDay - periodLength.round() - 2.0),
      3.0,
      max(1.0, cycleLength - ovulationDay - 1.0),
    ];

    final List<Float64List> hazard = [];
    final List<int> maxDuration = [];

    for (int phase = 0; phase < _numPhases; phase++) {
      final double mean = max(1.0, means[phase]);
      final int maxDur = (3 * mean).ceil().clamp(1, 120);

      final Float64List pmf = Float64List(maxDur);
      double logFactorial = 0.0;
      double total = 0.0;
      for (int d = 1; d <= maxDur; d++) {
        logFactorial += log(d);
        pmf[d - 1] = exp(-mean + d * log(mean) - logFactorial);
        total += pmf[d - 1];
      }
      for (int i = 0; i < maxDur; i++) {
        pmf[i] /= total;
      }

      final Float64List h = Float64List(maxDur);
      double survival = 1.0;
      for (int d = 0; d < maxDur; d++) {
        h[d] = survival > 1e-12 ? (pmf[d] / survival).clamp(0.0, 1.0) : 1.0;
        survival = (survival - pmf[d]).clamp(0.0, 1.0);
      }
      h[maxDur - 1] = 1.0;

      hazard.add(h);
      maxDuration.add(maxDur);
    }

    final int stride = maxDuration.reduce(max);
    return (hazard: hazard, maxDuration: maxDuration, stride: stride);
  }

  static Float64List _initState(
      Log anchor, _PhaseDurations durations, double periodLength, int ovulationDay) {
    final int stride = durations.stride;
    final Float64List state = Float64List(_numPhases * stride);
    final int phase = anchor.phase.index;
    final int dip = _dayInPhase(anchor.phase, anchor.cycleDay, periodLength, ovulationDay)
        .clamp(0, durations.maxDuration[phase] - 1);
    state[phase * stride + dip] = 1.0;
    return state;
  }

  static int _dayInPhase(Phase phase, int cycleDay, double periodLength, int ovulationDay) =>
      (switch (phase) {
        Phase.menstrual => cycleDay - 1,
        Phase.follicular => cycleDay - periodLength.round() - 1,
        Phase.ovulatory => cycleDay - (ovulationDay - 1),
        Phase.luteal => cycleDay - (ovulationDay + 2),
      }).clamp(0, 119);

  static Float64List _propagate(Float64List state, _PhaseDurations durations) {
    final int stride = durations.stride;
    final Float64List next = Float64List(state.length);
    for (int phase = 0; phase < _numPhases; phase++) {
      final int maxD = durations.maxDuration[phase];
      final int following = _next[phase];
      for (int d = 0; d < maxD; d++) {
        final double p = state[phase * stride + d];
        if (p < 1e-15) continue;
        final double h = durations.hazard[phase][d];
        if (d + 1 < maxD) next[phase * stride + d + 1] += p * (1.0 - h);
        next[following * stride] += p * h;
      }
    }
    return next;
  }

  static Float64List _phaseProbs(Float64List state, _PhaseDurations durations) {
    final Float64List probs = Float64List(_numPhases);
    final int stride = durations.stride;
    for (int phase = 0; phase < _numPhases; phase++) {
      double sum = 0.0;
      for (int d = 0; d < durations.maxDuration[phase]; d++) {
        sum += state[phase * stride + d];
      }
      probs[phase] = sum;
    }
    return probs;
  }

  static _Fields _blendFields(Float64List probs, List<_Fields?> networkTable) {
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
      final double w = probs[phase];
      if (w < 1e-9) continue;
      final _Fields? f = networkTable[phase];
      if (f == null) continue;
      for (int i = 0; i < acc.flow.length; i++) {
        acc.flow[i] += f.flow[i] * w;
      }
      for (int i = 0; i < acc.discharge.length; i++) {
        acc.discharge[i] += f.discharge[i] * w;
      }
      for (int i = 0; i < acc.stress.length; i++) {
        acc.stress[i] += f.stress[i] * w;
      }
      for (int i = 0; i < acc.sleep.length; i++) {
        acc.sleep[i] += f.sleep[i] * w;
      }
      for (int i = 0; i < acc.sex.length; i++) {
        acc.sex[i] += f.sex[i] * w;
      }
      for (int i = 0; i < acc.symptoms.length; i++) {
        acc.symptoms[i] += f.symptoms[i] * w;
      }
      for (int i = 0; i < acc.moods.length; i++) {
        acc.moods[i] += f.moods[i] * w;
      }
    }
    return acc;
  }

  static List<_Fields?> _buildNetworkTable(BayesAnalyser analyser) {
    final List<String> questions = [];
    final Map<String, (int, String, int)> meta = {};

    for (int ph = 0; ph < _numPhases; ph++) {
      final String ctx = 'PHASE=${Phase.values[ph].name.toUpperCase()}';
      void q(String prefix, String field, int index) {
        final String question = '$prefix | $ctx';
        questions.add(question);
        meta[question] = (ph, field, index);
      }
      for (final v in Flow.values) {
        q('FLOW=${v.name.toUpperCase()}', 'flow', v.index);
      }
      for (final v in Discharge.values) {
        q('DISCHARGE=${v.name.toUpperCase()}', 'discharge', v.index);
      }
      for (final v in Stress.values) {
        q('STRESS=${v.name.toUpperCase()}', 'stress', v.index);
      }
      for (final v in Sleep.values) {
        q('SLEEP=${v.name.toUpperCase()}', 'sleep', v.index);
      }
      for (final v in Sex.values) {
        q('SEX=${v.name.toUpperCase()}', 'sex', v.index);
      }
      for (final v in Symptom.values) {
        q('SYMPTOM_${v.name.toUpperCase()}=TRUE', 'symptom', v.index);
      }
      for (final v in Mood.values) {
        q('MOOD_${v.name.toUpperCase()}=TRUE', 'mood', v.index);
      }
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
    double s = 0.0;
    for (int i = 0; i < count; i++) {
      v[i] = raw[i] ?? 0.0;
      s += v[i];
    }
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
    double s = 0.0;
    for (final x in acc) {
      s += x;
    }
    if (s < 1e-9) return {for (final e in values) e: 1.0 / values.length};
    return {for (final e in values) e: acc[e.index] / s};
  }

  static Map<T, double> _toClampedMap<T extends Enum>(Float64List acc, List<T> values) =>
      {for (final e in values) e: acc[e.index].clamp(0.0, 1.0)};
}
