import 'dart:math';
import 'dart:typed_data';

import 'package:buritto/hive/hive_database.dart';
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
import 'package:worker_manager/worker_manager.dart';

const int _period = 0;
const int _numPhases = 4;
const List<int> _prev = [3, 0, 1, 2];
const List<int> _next = [1, 2, 3, 0];

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
  List<Float64List> logPmf,
  List<int> maxDuration,
});

typedef _HsmmInput = ({
  Set<String> allKeys,
  Map<String, Map<String, dynamic>> anchorData,
  DateTime rangeStart,
  DateTime rangeEnd,
  double cycleLength,
  double periodLength,
  int ovulationDay,
});

typedef _HsmmOutput = ({
  Float64List phaseProbs,
  Float64List transitionProbs,
  Float64List phaseProgress,
  DateTime windowStart,
  Map<int, Map<String, dynamic>> logsByDay,
});

class Hsmm {
  static final Hsmm _instance = Hsmm._internal();
  factory Hsmm() => _instance;
  Hsmm._internal();

  Cancelable<_HsmmOutput>? _running;

  Future<List<QuantumLog>> month(int year, int month) async {
    final List<QuantumLog>? cached = await QuantumRepo().getMonth(year, month);
    if (cached != null) return cached;
    if (HiveDatabase().logs.isEmpty) return [];

    final int versionAtStart = QuantumRepo().version;

    final DateTime triStart = DateTime(year, month - 1, 1);
    final DateTime triEnd = DateTime(year, month + 2, 0);
    final DateTime monthStart = DateTime(year, month, 1);
    final DateTime monthEnd = DateTime(year, month + 1, 0);

    final double cycleLength = KalmanFilter().cycleLength;
    final int windowRadius = (2 * cycleLength).ceil();

    final Set<String> allKeys =
        HiveDatabase().logs.keys.cast<String>().map((k) => k.substring(0, 10)).toSet();

    final Map<String, Map<String, dynamic>> anchorData = {};
    await for (final log in LogRepo().range(
      triStart.subtract(Duration(days: windowRadius)),
      triEnd.add(Duration(days: windowRadius)),
    )) {
      anchorData[LogRepo().dateToString(log.date).substring(0, 10)] = log.toJson();
    }

    final _HsmmInput input = (
      allKeys: allKeys,
      anchorData: anchorData,
      rangeStart: triStart,
      rangeEnd: triEnd,
      cycleLength: cycleLength,
      periodLength: KalmanFilter().periodLength,
      ovulationDay: KalmanFilter().ovulationDay,
    );

    _running?.cancel();
    _running = workerManager.execute(() => Hsmm._runHsmm(input));
    final List<_Fields?> networkTable = _buildNetworkTable(BayesNetwork().analyser);
    final _HsmmOutput output = await _running!;

    final Map<int, Log> loggedDays = {
      for (final e in output.logsByDay.entries) e.key: Log.fromJson(e.value),
    };

    final List<QuantumLog> triLogs = _buildPredictions(
      windowStart: output.windowStart,
      rangeStart: triStart,
      rangeEnd: triEnd,
      loggedDays: loggedDays,
      phaseProbs: output.phaseProbs,
      transitionProbs: output.transitionProbs,
      phaseProgress: output.phaseProgress,
      networkTable: networkTable,
      cycleLength: cycleLength,
    );

    final int startIdx = monthStart.difference(triStart).inDays;
    final int endIdx = monthEnd.difference(triStart).inDays;
    final List<QuantumLog> monthLogs = triLogs.sublist(startIdx, endIdx + 1);
    if (QuantumRepo().version == versionAtStart) await QuantumRepo().saveMonth(monthLogs);
    return monthLogs;
  }

  static _HsmmOutput _runHsmm(_HsmmInput input) {
    final int windowRadius = (2 * input.cycleLength).ceil();
    final DateTime windowStart = _findNearestLog(input.rangeStart, -1, windowRadius, input.allKeys);
    final DateTime windowEnd = _findNearestLog(input.rangeEnd, 1, windowRadius, input.allKeys);
    final int totalDays = windowEnd.difference(windowStart).inDays + 1;

    final Map<int, int> loggedPhaseByDay = {};
    final Map<int, Map<String, dynamic>> logsByDay = {};
    for (int day = 0; day < totalDays; day++) {
      final String key = windowStart.add(Duration(days: day)).toIso8601String().substring(0, 10);
      final Map<String, dynamic>? data = input.anchorData[key];
      if (data != null) {
        loggedPhaseByDay[day] = data['phase'] as int;
        logsByDay[day] = data;
      }
    }

    final _PhaseDurations durations =
        _buildPhaseDurations(input.cycleLength, input.periodLength, input.ovulationDay);
    final List<Int32List> compat = _buildCompatibility(loggedPhaseByDay, totalDays);
    final Float64List fwd = _forwardPass(totalDays, loggedPhaseByDay, durations, compat);
    final Float64List bwd = _backwardPass(totalDays, loggedPhaseByDay, durations, compat);
    final posteriors = _posteriorProbabilities(totalDays, fwd, bwd, durations, compat);

    return (
      phaseProbs: posteriors.phaseProbs,
      transitionProbs: posteriors.transitionProbs,
      phaseProgress: posteriors.phaseProgress,
      windowStart: windowStart,
      logsByDay: logsByDay,
    );
  }

  static _PhaseDurations _buildPhaseDurations(
      double cycleLength, double periodLength, int ovulationDay) {
    final List<double> means = [
      periodLength,
      max(1.0, ovulationDay - periodLength.round() - 2.0),
      3.0,
      max(1.0, cycleLength - ovulationDay - 1.0),
    ];

    final List<Float64List> logPmf = [];
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

      final Float64List entry = Float64List(maxDur);
      for (int i = 0; i < maxDur; i++) {
        final double p = total > 0 ? pmf[i] / total : 1.0 / maxDur;
        entry[i] = p > 0 ? log(p) : double.negativeInfinity;
      }

      logPmf.add(entry);
      maxDuration.add(maxDur);
    }

    return (logPmf: logPmf, maxDuration: maxDuration);
  }

  static List<Int32List> _buildCompatibility(Map<int, int> loggedPhaseByDay, int totalDays) {
    final List<Int32List> prefix = List.generate(_numPhases, (_) => Int32List(totalDays + 2));
    for (int day = 0; day < totalDays; day++) {
      final int? logged = loggedPhaseByDay[day];
      for (int phase = 0; phase < _numPhases; phase++) {
        prefix[phase][day + 1] = prefix[phase][day];
        if (logged != null && logged != phase) prefix[phase][day + 1]++;
      }
    }
    return prefix;
  }

  static bool _stretchCompatible(List<Int32List> compat, int phase, int start, int end) =>
      compat[phase][end + 1] == compat[phase][start];

  static Float64List _forwardPass(int totalDays, Map<int, int> loggedPhaseByDay,
      _PhaseDurations durations, List<Int32List> compat) {
    final Float64List fwd = Float64List((totalDays + 1) * _numPhases)
      ..fillRange(0, (totalDays + 1) * _numPhases, double.negativeInfinity);

    final int? first = loggedPhaseByDay[0];
    if (first != null) {
      fwd[first] = 0.0;
    } else {
      final double logUniform = log(1.0 / _numPhases);
      for (int p = 0; p < _numPhases; p++) {
        fwd[p] = logUniform;
      }
    }

    for (int day = 0; day < totalDays; day++) {
      final int writeBase = (day + 1) * _numPhases;
      for (int phase = 0; phase < _numPhases; phase++) {
        final int maxDur = min(day + 1, durations.maxDuration[phase]);
        double logProb = double.negativeInfinity;
        for (int dur = 1; dur <= maxDur; dur++) {
          final int runStart = day - dur + 1;
          if (!_stretchCompatible(compat, phase, runStart, day)) continue;
          final double logFwd = fwd[runStart * _numPhases + _prev[phase]];
          if (logFwd == double.negativeInfinity) continue;
          logProb = _logSumExp(logProb, logFwd + durations.logPmf[phase][dur - 1]);
        }
        fwd[writeBase + phase] = logProb;
      }
    }

    return fwd;
  }

  static Float64List _backwardPass(int totalDays, Map<int, int> loggedPhaseByDay,
      _PhaseDurations durations, List<Int32List> compat) {
    final Float64List bwd = Float64List((totalDays + 1) * _numPhases)
      ..fillRange(0, (totalDays + 1) * _numPhases, double.negativeInfinity);

    final int boundaryBase = totalDays * _numPhases;
    final int? last = loggedPhaseByDay[totalDays - 1];
    if (last != null) {
      bwd[boundaryBase + last] = 0.0;
    } else {
      for (int p = 0; p < _numPhases; p++) {
        bwd[boundaryBase + p] = 0.0;
      }
    }

    for (int day = totalDays - 1; day >= 0; day--) {
      final int readBase = day * _numPhases;
      for (int phase = 0; phase < _numPhases; phase++) {
        final int following = _next[phase];
        final int maxDur = min(totalDays - day, durations.maxDuration[following]);
        double logProb = double.negativeInfinity;
        for (int dur = 1; dur <= maxDur; dur++) {
          final int runEnd = day + dur;
          if (runEnd > totalDays) break;
          if (!_stretchCompatible(compat, following, day + 1, runEnd)) continue;
          final double logBwd = bwd[runEnd * _numPhases + following];
          if (logBwd == double.negativeInfinity) continue;
          logProb = _logSumExp(logProb, durations.logPmf[following][dur - 1] + logBwd);
        }
        bwd[readBase + phase] = logProb;
      }
    }

    return bwd;
  }

  static ({Float64List phaseProbs, Float64List transitionProbs, Float64List phaseProgress})
      _posteriorProbabilities(int totalDays, Float64List fwd, Float64List bwd,
          _PhaseDurations durations, List<Int32List> compat) {
    final Float64List phaseProbs = Float64List(totalDays * _numPhases);
    final Float64List transitionProbs = Float64List((totalDays + 1) * _numPhases);
    final Float64List phaseProgress = Float64List(totalDays * _numPhases);

    for (int day = 0; day < totalDays; day++) {
      for (int phase = 0; phase < _numPhases; phase++) {
        final int maxDur = durations.maxDuration[phase];
        double logProbSum = double.negativeInfinity;
        double weightSum = 0.0;
        double weightedDurSum = 0.0;

        for (int dur = 1; dur <= maxDur; dur++) {
          if (day + dur - 1 >= totalDays) break;
          for (int runEnd = day; runEnd <= day + dur - 1; runEnd++) {
            final int runStart = runEnd - dur + 1;
            if (runStart < 0 || !_stretchCompatible(compat, phase, runStart, runEnd)) continue;
            final double logF = fwd[runStart * _numPhases + _prev[phase]];
            final double logB = bwd[(runEnd + 1) * _numPhases + phase];
            if (logF == double.negativeInfinity || logB == double.negativeInfinity) continue;
            final double logJoint = logF + durations.logPmf[phase][dur - 1] + logB;
            logProbSum = _logSumExp(logProbSum, logJoint);
            final double w = exp(logJoint);
            weightSum += w;
            weightedDurSum += dur * w;
          }
        }

        phaseProbs[day * _numPhases + phase] = logProbSum;
        phaseProgress[day * _numPhases + phase] = weightSum > 0.0
            ? ((weightedDurSum / weightSum) - 1.0) / max(1, maxDur - 1)
            : 0.5;
      }

      double logNorm = double.negativeInfinity;
      for (int p = 0; p < _numPhases; p++) {
        logNorm = _logSumExp(logNorm, phaseProbs[day * _numPhases + p]);
      }
      for (int p = 0; p < _numPhases; p++) {
        phaseProbs[day * _numPhases + p] = logNorm == double.negativeInfinity
            ? 1.0 / _numPhases
            : exp(phaseProbs[day * _numPhases + p] - logNorm);
      }
    }

    for (int day = 1; day < totalDays; day++) {
      for (int phase = 0; phase < _numPhases; phase++) {
        final int following = _next[phase];
        final int maxDur = durations.maxDuration[following];
        double logProb = double.negativeInfinity;
        for (int dur = 1; dur <= maxDur; dur++) {
          if (day + dur - 1 >= totalDays) break;
          if (!_stretchCompatible(compat, following, day, day + dur - 1)) continue;
          final double logF = fwd[day * _numPhases + phase];
          final double logB = bwd[(day + dur) * _numPhases + following];
          if (logF == double.negativeInfinity || logB == double.negativeInfinity) continue;
          logProb = _logSumExp(logProb, logF + durations.logPmf[following][dur - 1] + logB);
        }
        transitionProbs[day * _numPhases + phase] = logProb;
      }

      double logTransNorm = double.negativeInfinity;
      for (int p = 0; p < _numPhases; p++) {
        logTransNorm = _logSumExp(logTransNorm, transitionProbs[day * _numPhases + p]);
      }
      for (int p = 0; p < _numPhases; p++) {
        transitionProbs[day * _numPhases + p] = logTransNorm == double.negativeInfinity
            ? 0.0
            : exp(transitionProbs[day * _numPhases + p] - logTransNorm);
      }
    }

    return (phaseProbs: phaseProbs, transitionProbs: transitionProbs, phaseProgress: phaseProgress);
  }

  // Table indexed by prevPhase * flowCount + prevFlow; next phase is _next[prevPhase].
  static List<_Fields?> _buildNetworkTable(BayesAnalyser analyser) {
    final int flowCount = Flow.values.length;
    final List<String> questions = [];
    final Map<String, (int, int, String, int)> questionMeta = {};

    for (int prevPhase = 0; prevPhase < _numPhases; prevPhase++) {
      for (int prevFlow = 0; prevFlow < flowCount; prevFlow++) {
        final int phase = _next[prevPhase];
        final String context = 'PHASE=${Phase.values[phase].name.toUpperCase()}, '
            'PREV_PHASE=${Phase.values[prevPhase].name.toUpperCase()}, '
            'PREV_FLOW=${Flow.values[prevFlow].name.toUpperCase()}';

        void ask(Enum value, String field) {
          final String q = '${field.toUpperCase()}=${value.name.toUpperCase()} | $context';
          questions.add(q);
          questionMeta[q] = (prevPhase, prevFlow, field.toLowerCase(), (value as dynamic).index);
        }

        void askBool(Enum value, String field) {
          final String q = '${field.toUpperCase()}_${value.name.toUpperCase()}=TRUE | $context';
          questions.add(q);
          questionMeta[q] = (prevPhase, prevFlow, field.toLowerCase(), (value as dynamic).index);
        }

        for (final v in Flow.values) {
          ask(v, 'FLOW');
        }
        for (final v in Discharge.values) {
          ask(v, 'DISCHARGE');
        }
        for (final v in Stress.values) {
          ask(v, 'STRESS');
        }
        for (final v in Sleep.values) {
          ask(v, 'SLEEP');
        }
        for (final v in Sex.values) {
          ask(v, 'SEX');
        }
        for (final v in Symptom.values) {
          askBool(v, 'SYMPTOM');
        }
        for (final v in Mood.values) {
          askBool(v, 'MOOD');
        }
      }
    }

    final List<Answer> answers = analyser.quiz(questions);

    final Map<int, Map<String, Map<int, double>>> raw = {};
    for (final a in answers) {
      final meta = questionMeta[a.originalQuery];
      if (meta == null) continue;
      final (int prevPhase, int prevFlow, String field, int index) = meta;
      raw
          .putIfAbsent(prevPhase * flowCount + prevFlow, () => {})
          .putIfAbsent(field, () => {})[index] = a.probability;
    }

    final List<_Fields?> table = List.filled(_numPhases * flowCount, null);
    for (final entry in raw.entries) {
      final v = entry.value;
      table[entry.key] = (
        flow: _normalizedVector(v['flow'] ?? {}, flowCount),
        discharge: _normalizedVector(v['discharge'] ?? {}, Discharge.values.length),
        stress: _normalizedVector(v['stress'] ?? {}, Stress.values.length),
        sleep: _normalizedVector(v['sleep'] ?? {}, Sleep.values.length),
        sex: _normalizedVector(v['sex'] ?? {}, Sex.values.length),
        symptoms: _probabilityVector(v['symptom'] ?? {}, Symptom.values.length),
        moods: _probabilityVector(v['mood'] ?? {}, Mood.values.length),
      );
    }
    return table;
  }

  static List<QuantumLog> _buildPredictions({
    required DateTime windowStart,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required Map<int, Log> loggedDays,
    required Float64List phaseProbs,
    required Float64List transitionProbs,
    required Float64List phaseProgress,
    required List<_Fields?> networkTable,
    required double cycleLength,
  }) {
    final int daysInRange = rangeEnd.difference(rangeStart).inDays + 1;
    final int rangeStartDay = rangeStart.difference(windowStart).inDays;
    final int flowCount = Flow.values.length;

    final Int32List precedingLog = Int32List(rangeStartDay + daysInRange);
    int lastLogDay = -1;
    for (int day = 0; day < rangeStartDay + daysInRange; day++) {
      if (loggedDays.containsKey(day)) lastLogDay = day;
      precedingLog[day] = lastLogDay;
    }

    final _Fields acc = (
      flow: Float64List(flowCount),
      discharge: Float64List(Discharge.values.length),
      stress: Float64List(Stress.values.length),
      sleep: Float64List(Sleep.values.length),
      sex: Float64List(Sex.values.length),
      symptoms: Float64List(Symptom.values.length),
      moods: Float64List(Mood.values.length),
    );

    final Float64List prevFlowDist = Float64List(flowCount)
      ..fillRange(0, flowCount, 1.0 / flowCount);
    final List<QuantumLog> result = [];

    for (int mi = 0; mi < daysInRange; mi++) {
      final int day = rangeStartDay + mi;
      final DateTime date = rangeStart.add(Duration(days: mi));

      final Log? logged = loggedDays[day];
      if (logged != null) {
        result.add(QuantumLog.fromLog(logged));
        prevFlowDist.fillRange(0, flowCount, 0.0);
        prevFlowDist[logged.flow.index] = 1.0;
        continue;
      }

      final int prevLog = precedingLog[day];
      final int cycleDay = prevLog >= 0
          ? KalmanFilter().predictCycleDay(date, loggedDays[prevLog]!)
          : (day + 1).clamp(1, cycleLength.round());

      _clearFields(acc);

      for (int phase = 0; phase < _numPhases; phase++) {
        final double phaseWeight = phaseProbs[day * _numPhases + phase];
        if (phaseWeight < 1e-9) continue;
        for (int pf = 0; pf < flowCount; pf++) {
          final double pfWeight = prevFlowDist[pf];
          if (pfWeight < 1e-9) continue;
          final _Fields? p = networkTable[_prev[phase] * flowCount + pf];
          if (p == null) continue;
          _addWeighted(acc, p, phaseWeight * pfWeight);
        }
      }

      for (int phase = 0; phase < _numPhases; phase++) {
        final double tw = transitionProbs[day * _numPhases + phase];
        if (tw < 0.15) continue;
        final _Fields? p = networkTable[phase * flowCount + Flow.none.index];
        if (p == null) continue;
        _addWeighted(acc, p, tw);
      }

      final double periodProb = phaseProbs[day * _numPhases + _period];
      if (periodProb > 1e-9) {
        final double progress = phaseProgress[day * _numPhases + _period].clamp(0.0, 1.0);
        for (int fi = 0; fi < flowCount; fi++) {
          acc.flow[fi] = (acc.flow[fi] * (1.0 - progress * (fi / (flowCount - 1.0)) * 0.6))
              .clamp(0.0, double.maxFinite);
        }
      }

      double flowTotal = 0.0;
      for (final x in acc.flow) {
        flowTotal += x;
      }
      for (int i = 0; i < flowCount; i++) {
        prevFlowDist[i] = flowTotal > 1e-9 ? acc.flow[i] / flowTotal : 1.0 / flowCount;
      }

      result.add(QuantumLog(
        date: date,
        cycleDay: cycleDay,
        phase: _mostLikelyPhase(phaseProbs, day),
        flow: _toNormalizedMap(acc.flow, Flow.values),
        discharge: _toNormalizedMap(acc.discharge, Discharge.values),
        stress: _toNormalizedMap(acc.stress, Stress.values),
        sleep: _toNormalizedMap(acc.sleep, Sleep.values),
        sex: _toNormalizedMap(acc.sex, Sex.values),
        symptoms: _toClampedMap(acc.symptoms, Symptom.values),
        moods: _toClampedMap(acc.moods, Mood.values),
      ));
    }

    return result;
  }

  static void _clearFields(_Fields f) {
    f.flow.fillRange(0, f.flow.length, 0.0);
    f.discharge.fillRange(0, f.discharge.length, 0.0);
    f.stress.fillRange(0, f.stress.length, 0.0);
    f.sleep.fillRange(0, f.sleep.length, 0.0);
    f.sex.fillRange(0, f.sex.length, 0.0);
    f.symptoms.fillRange(0, f.symptoms.length, 0.0);
    f.moods.fillRange(0, f.moods.length, 0.0);
  }

  static void _addWeighted(_Fields acc, _Fields p, double w) {
    for (int i = 0; i < acc.flow.length; i++) {
      acc.flow[i] += p.flow[i] * w;
    }
    for (int i = 0; i < acc.discharge.length; i++) {
      acc.discharge[i] += p.discharge[i] * w;
    }
    for (int i = 0; i < acc.stress.length; i++) {
      acc.stress[i] += p.stress[i] * w;
    }
    for (int i = 0; i < acc.sleep.length; i++) {
      acc.sleep[i] += p.sleep[i] * w;
    }
    for (int i = 0; i < acc.sex.length; i++) {
      acc.sex[i] += p.sex[i] * w;
    }
    for (int i = 0; i < acc.symptoms.length; i++) {
      acc.symptoms[i] += p.symptoms[i] * w;
    }
    for (int i = 0; i < acc.moods.length; i++) {
      acc.moods[i] += p.moods[i] * w;
    }
  }

  static double _logSumExp(double a, double b) {
    if (a == double.negativeInfinity) return b;
    if (b == double.negativeInfinity) return a;
    return a > b ? a + log(1.0 + exp(b - a)) : b + log(1.0 + exp(a - b));
  }

  static DateTime _findNearestLog(DateTime anchor, int direction, int maxDays, Set<String> allKeys) =>
      Iterable.generate(maxDays, (i) => anchor.add(Duration(days: (i + 1) * direction)))
          .firstWhere(
            (d) => allKeys.contains(d.toIso8601String().substring(0, 10)),
            orElse: () => anchor,
          );

  static Phase _mostLikelyPhase(Float64List phaseProbs, int day) {
    int best = 0;
    double bestProb = phaseProbs[day * _numPhases];
    for (int p = 1; p < _numPhases; p++) {
      final double prob = phaseProbs[day * _numPhases + p];
      if (prob > bestProb) {
        bestProb = prob;
        best = p;
      }
    }
    return Phase.values[best];
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
