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
const List<int> _deterministicNext = [1, 2, 3, 0];
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

  static const int _filterWindow = 14;

  Future<List<QuantumLog>> run(
    Log anchor,
    Stream<Log> logStream,
    double cycleLength,
    double periodLength,
    int ovulationDay,
    double cycleError,
  ) async {
    final Float64List transitionCounts = Float64List(_numPhases * _numPhases);
    final List<Log> recentLogs = [];
    Log? prev;

    await for (final log in logStream) {
      if (prev != null) {
        final int gap = log.date.difference(prev.date).inDays;
        if (gap == 1) transitionCounts[prev.phase.index * _numPhases + log.phase.index] += 1.0;
      }
      prev = log;
      recentLogs.add(log);
      if (recentLogs.length > _filterWindow) recentLogs.removeAt(0);
    }

    final _PhaseDurations durations = _buildPhaseDurations(cycleLength, periodLength, ovulationDay, cycleError);
    final List<_Fields?> networkTable = _buildNetworkTable(BayesNetwork().analyser);
    final Float64List transitionMatrix = _buildTransitionMatrix(transitionCounts);

    Float64List state = _filterState(
      anchor, recentLogs, durations, periodLength, ovulationDay, cycleError, transitionMatrix, networkTable,
    );

    final List<QuantumLog> results = [];
    final DateTime today = DateTime.now();
    final DateTime todayDate = DateTime(today.year, today.month, today.day);

    for (int step = 0; step < _horizon; step++) {
      if (step > 0) state = _propagate(state, durations, transitionMatrix);

      final DateTime date = anchor.date.add(Duration(days: step));
      if (date.isBefore(todayDate)) continue;

      final Float64List probs = _phaseProbs(state, durations);
      final _Fields acc = _blendFields(probs, networkTable);
      final int cycleDay = KalmanFilter().predictCycleDay(date, anchor);

      int maxPhase = 0;
      for (int i = 1; i < _numPhases; i++) {
        if (probs[i] > probs[maxPhase]) maxPhase = i;
      }

      results.add(QuantumLog(
        date: date,
        cycleDay: cycleDay,
        phase: Phase.values[maxPhase],
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

  // --- Duration model ---

  static _PhaseDurations _buildPhaseDurations(
      double cycleLength, double periodLength, int ovulationDay, double cycleError) {
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
      // NB dispersion: r = mean²/cycleError². Large r ≈ Poisson (tight cycle),
      // small r gives heavy tails (irregular cycle).
      final int dispersion = (mean * mean / max(cycleError * cycleError, 1.0))
          .round()
          .clamp(1, 200);

      final Float64List pmf = _negativeBinomialPmf(mean, dispersion, maxDur);

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

  // NB(mean=μ, size=r): P(X=k) = C(k+r-1,k) * (r/(r+μ))^r * (μ/(r+μ))^k
  // Uses integer r so log C(k+r-1,k) = lf[k+r-1] - lf[k] - lf[r-1] exactly.
  static Float64List _negativeBinomialPmf(double mean, int r, int maxDur) {
    final Float64List pmf = Float64List(maxDur);
    final int lfSize = maxDur + r;
    final List<double> lf = List.filled(lfSize + 1, 0.0);
    for (int i = 2; i <= lfSize; i++) {
      lf[i] = lf[i - 1] + log(i.toDouble());
    }

    final double logPr = r * log(r / (r + mean));
    final double logPmu = log(mean / (r + mean));
    double total = 0.0;

    for (int k = 1; k <= maxDur; k++) {
      final double logBinom = lf[k + r - 1] - lf[k] - lf[r - 1];
      pmf[k - 1] = exp(logBinom + logPr + k * logPmu);
      total += pmf[k - 1];
    }
    if (total > 0) {
      for (int i = 0; i < maxDur; i++) {
        pmf[i] /= total;
      }
    }
    return pmf;
  }

  // --- Transition matrix ---

  // Normalises pre-accumulated transition counts into a row-stochastic matrix.
  // Rows with no observed transitions fall back to the deterministic ring.
  static Float64List _buildTransitionMatrix(Float64List counts) {
    final Float64List matrix = Float64List(_numPhases * _numPhases);
    for (int from = 0; from < _numPhases; from++) {
      double rowSum = 0.0;
      for (int to = 0; to < _numPhases; to++) rowSum += counts[from * _numPhases + to];
      if (rowSum > 0) {
        for (int to = 0; to < _numPhases; to++) {
          matrix[from * _numPhases + to] = counts[from * _numPhases + to] / rowSum;
        }
      } else {
        matrix[from * _numPhases + _deterministicNext[from]] = 1.0;
      }
    }
    return matrix;
  }

  // --- State initialisation ---

  static Float64List _initState(
      Log anchor, _PhaseDurations durations, double periodLength, int ovulationDay, double cycleError) {
    final int stride = durations.stride;
    final Float64List state = Float64List(_numPhases * stride);
    final int phase = anchor.phase.index;
    final int centerDip = _dayInPhase(anchor.phase, anchor.cycleDay, periodLength, ovulationDay)
        .clamp(0, durations.maxDuration[phase] - 1);

    // Gaussian spread proportional to cycleError instead of a point mass.
    final double sigma = max(0.5, cycleError / 2.0);
    double total = 0.0;
    final int maxD = durations.maxDuration[phase];
    for (int d = 0; d < maxD; d++) {
      final double dx = (d - centerDip).toDouble();
      final double w = exp(-0.5 * dx * dx / (sigma * sigma));
      state[phase * stride + d] = w;
      total += w;
    }
    if (total > 0) {
      for (int d = 0; d < maxD; d++) {
        state[phase * stride + d] /= total;
      }
    }
    return state;
  }

  static int _dayInPhase(Phase phase, int cycleDay, double periodLength, int ovulationDay) =>
      (switch (phase) {
        Phase.menstrual => cycleDay - 1,
        Phase.follicular => cycleDay - periodLength.round() - 1,
        Phase.ovulatory => cycleDay - (ovulationDay - 1),
        Phase.luteal => cycleDay - (ovulationDay + 2),
      }).clamp(0, 119);

  // --- HMM filtering ---

  // Runs a forward pass through recentLogs, updating state with emission
  // likelihoods at each logged day, to produce a filtered starting state.
  static Float64List _filterState(
    Log anchor,
    List<Log> recentLogs,
    _PhaseDurations durations,
    double periodLength,
    int ovulationDay,
    double cycleError,
    Float64List transitionMatrix,
    List<_Fields?> networkTable,
  ) {
    final Log oldest = recentLogs.isEmpty ? anchor : recentLogs.first;
    Float64List state = _initState(oldest, durations, periodLength, ovulationDay, cycleError);
    state = _applyEmission(state, oldest, durations, networkTable);

    DateTime current = oldest.date;
    final Iterable<Log> rest = recentLogs.isEmpty ? const <Log>[] : recentLogs.skip(1);

    for (final log in rest) {
      final int days = log.date.difference(current).inDays;
      for (int d = 0; d < days; d++) {
        state = _propagate(state, durations, transitionMatrix);
      }
      state = _applyEmission(state, log, durations, networkTable);
      current = log.date;
    }

    final int remaining = anchor.date.difference(current).inDays;
    for (int d = 0; d < remaining; d++) {
      state = _propagate(state, durations, transitionMatrix);
    }

    return state;
  }

  // Multiplies each phase's probability mass by P(observation | phase),
  // then renormalises. Only the phase identity matters for emissions;
  // the day-in-phase slots within a phase all receive the same scale factor.
  static Float64List _applyEmission(
      Float64List state, Log log, _PhaseDurations durations, List<_Fields?> networkTable) {
    final int stride = durations.stride;
    for (int phase = 0; phase < _numPhases; phase++) {
      final _Fields? f = networkTable[phase];
      final double l = f != null ? _likelihood(log, f) : 1e-6;
      for (int d = 0; d < durations.maxDuration[phase]; d++) {
        state[phase * stride + d] *= l;
      }
    }
    double total = 0.0;
    for (int i = 0; i < state.length; i++) {
      total += state[i];
    }
    if (total > 1e-15) {
      for (int i = 0; i < state.length; i++) {
        state[i] /= total;
      }
    }
    return state;
  }

  // Product of per-field likelihoods given phase emissions.
  // Floored at 1e-6 so no single observation can zero out a phase.
  static double _likelihood(Log log, _Fields f) {
    double l = max(1e-6, f.flow[log.flow.index]);
    if (log.discharge != null) l *= max(1e-6, f.discharge[log.discharge!.index]);
    if (log.stress != null) l *= max(1e-6, f.stress[log.stress!.index]);
    if (log.sleep != null) l *= max(1e-6, f.sleep[log.sleep!.index]);
    if (log.sex != null) l *= max(1e-6, f.sex[log.sex!.index]);
    for (final s in Symptom.values) {
      final double p = f.symptoms[s.index];
      l *= log.symptoms.contains(s) ? max(1e-6, p) : max(1e-6, 1.0 - p);
    }
    for (final m in Mood.values) {
      final double p = f.moods[m.index];
      l *= log.moods.contains(m) ? max(1e-6, p) : max(1e-6, 1.0 - p);
    }
    return l;
  }

  // --- Propagation ---

  static Float64List _propagate(
      Float64List state, _PhaseDurations durations, Float64List transitionMatrix) {
    final int stride = durations.stride;
    final Float64List next = Float64List(state.length);
    for (int phase = 0; phase < _numPhases; phase++) {
      final int maxD = durations.maxDuration[phase];
      for (int d = 0; d < maxD; d++) {
        final double p = state[phase * stride + d];
        if (p < 1e-15) continue;
        final double h = durations.hazard[phase][d];
        if (d + 1 < maxD) next[phase * stride + d + 1] += p * (1.0 - h);
        final double ph = p * h;
        for (int to = 0; to < _numPhases; to++) {
          next[to * stride] += ph * transitionMatrix[phase * _numPhases + to];
        }
      }
    }
    return next;
  }

  // --- Readout ---

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

  // --- Network table ---

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
