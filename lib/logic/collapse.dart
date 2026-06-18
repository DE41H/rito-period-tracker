import 'dart:isolate';
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

const int _period = 0;
const int _numPhases = 4;

typedef _PredictedFields = ({
  Float64List flow,
  Float64List discharge,
  Float64List stress,
  Float64List sleep,
  Float64List sex,
  Float64List symptoms,
  Float64List moods,
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

  Future<List<QuantumLog>> month(int year, int month) async {
    final List<QuantumLog>? cached = await QuantumRepo().getMonth(year, month);
    if (cached != null) return cached;

    final int versionAtStart = QuantumRepo().version;
    final KalmanFilter kalman = KalmanFilter();
    final double cycleLength = kalman.cycleLength;
    final double periodLength = kalman.periodLength;
    final int ovulationDay = kalman.ovulationDay;

    final DateTime triStart = DateTime(year, month - 1, 1);
    final DateTime triEnd = DateTime(year, month + 2, 0);
    final DateTime monthStart = DateTime(year, month, 1);
    final DateTime monthEnd = DateTime(year, month + 1, 0);

    final int windowRadius = (2 * cycleLength).ceil();
    final DateTime loadStart = triStart.subtract(Duration(days: windowRadius));
    final DateTime loadEnd = triEnd.add(Duration(days: windowRadius));

    final Set<String> allKeys = HiveDatabase().logs.keys
        .cast<String>()
        .map((k) => DateTime.parse(k).toIso8601String().substring(0, 10))
        .toSet();

    if (allKeys.isEmpty) return [];

    final Map<String, Map<String, dynamic>> anchorData = {};
    await for (final log in LogRepo().range(loadStart, loadEnd)) {
      anchorData[LogRepo().dateToString(log.date).substring(0, 10)] = log.toJson();
    }

    final _HsmmInput input = (
      allKeys: allKeys,
      anchorData: anchorData,
      rangeStart: triStart,
      rangeEnd: triEnd,
      cycleLength: cycleLength,
      periodLength: periodLength,
      ovulationDay: ovulationDay,
    );

    final Future<_HsmmOutput> hsmmFuture = Isolate.run(() => Hsmm._runHsmm(input));
    final List<_PredictedFields?> networkTable =
        _buildNetworkTable(BayesNetwork().analyser);
    final _HsmmOutput output = await hsmmFuture;

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
    final double cycleLength = input.cycleLength;
    final double periodLength = input.periodLength;
    final int ovulationDay = input.ovulationDay;
    final int windowRadius = (2 * cycleLength).ceil();

    final DateTime windowStart = _findNearestLog(input.rangeStart, -1, windowRadius, input.allKeys);
    final DateTime windowEnd = _findNearestLog(input.rangeEnd, 1, windowRadius, input.allKeys);
    final int totalDays = windowEnd.difference(windowStart).inDays + 1;

    final Map<int, int> loggedPhaseByDay = {};
    final Map<int, Map<String, dynamic>> logsByDay = {};
    for (int day = 0; day < totalDays; day++) {
      final DateTime date = windowStart.add(Duration(days: day));
      final String key = date.toIso8601String().substring(0, 10);
      final Map<String, dynamic>? data = input.anchorData[key];
      if (data != null) {
        loggedPhaseByDay[day] = data['phase'] as int;
        logsByDay[day] = data;
      }
    }

    final phaseDurations = _buildPhaseDurations(cycleLength, periodLength, ovulationDay);
    final compatibility = _buildCompatibility(loggedPhaseByDay, totalDays);
    final logForward = _forwardPass(totalDays, loggedPhaseByDay, phaseDurations, compatibility);
    final logBackward = _backwardPass(totalDays, loggedPhaseByDay, phaseDurations, compatibility);
    final posteriors = _posteriorProbabilities(totalDays, logForward, logBackward, phaseDurations, compatibility);

    return (
      phaseProbs: posteriors.phaseProbs,
      transitionProbs: posteriors.transitionProbs,
      phaseProgress: posteriors.phaseProgress,
      windowStart: windowStart,
      logsByDay: logsByDay,
    );
  }

  static ({List<Float64List> logPmf, List<int> maxDuration}) _buildPhaseDurations(
      double cycleLength, double periodLength, int ovulationDay) {
    final List<double> meanDurations = [
      periodLength,
      max(1.0, ovulationDay - periodLength.round() - 2.0),
      3.0,
      max(1.0, cycleLength - ovulationDay - 1.0),
    ];

    final List<Float64List> logPmf = [];
    final List<int> maxDuration = [];
    for (int phase = 0; phase < _numPhases; phase++) {
      final double mean = max(1.0, meanDurations[phase]);
      final int maxDur = (3 * mean).ceil().clamp(1, 120);
      final List<double> probs = _poissonDistribution(mean, maxDur);
      final Float64List entry = Float64List(maxDur);
      for (int i = 0; i < maxDur; i++) {
        entry[i] = probs[i] > 0 ? log(probs[i]) : double.negativeInfinity;
      }
      logPmf.add(entry);
      maxDuration.add(maxDur);
    }
    return (logPmf: logPmf, maxDuration: maxDuration);
  }

  static List<double> _poissonDistribution(double mean, int maxDur) {
    final List<double> probs = List<double>.filled(maxDur, 0.0);
    double logFactorial = 0.0;
    for (int d = 1; d <= maxDur; d++) {
      logFactorial += log(d);
      probs[d - 1] = exp(-mean + (d * log(mean)) - logFactorial);
    }
    return _normalizeList(probs);
  }

  static List<List<int>> _buildCompatibility(Map<int, int> loggedPhaseByDay, int totalDays) {
    final List<List<int>> prefix =
        List.generate(_numPhases, (_) => List.filled(totalDays + 2, 0));
    for (int day = 0; day < totalDays; day++) {
      final int? logged = loggedPhaseByDay[day];
      for (int phase = 0; phase < _numPhases; phase++) {
        prefix[phase][day + 1] = prefix[phase][day];
        if (logged != null && logged != phase) prefix[phase][day + 1]++;
      }
    }
    return prefix;
  }

  static bool _stretchCompatible(List<List<int>> compatibility, int phase, int start, int end) =>
      compatibility[phase][end + 1] == compatibility[phase][start];

  static Float64List _forwardPass(
      int totalDays,
      Map<int, int> loggedPhaseByDay,
      ({List<Float64List> logPmf, List<int> maxDuration}) phaseDurations,
      List<List<int>> compatibility) {
    final Float64List logForward = Float64List((totalDays + 1) * _numPhases);
    logForward.fillRange(0, logForward.length, double.negativeInfinity);

    final int? firstLoggedPhase = loggedPhaseByDay[0];
    if (firstLoggedPhase != null) {
      logForward[firstLoggedPhase] = 0.0;
    } else {
      final double logUniform = log(1.0 / _numPhases);
      for (int phase = 0; phase < _numPhases; phase++) {
        logForward[phase] = logUniform;
      }
    }

    final List<int> prevPhase = List.generate(_numPhases, _previousPhase);

    for (int day = 0; day < totalDays; day++) {
      final int writeBase = (day + 1) * _numPhases;
      for (int phase = 0; phase < _numPhases; phase++) {
        final int maxDur = min(day + 1, phaseDurations.maxDuration[phase]);
        double logProb = double.negativeInfinity;
        for (int dur = 1; dur <= maxDur; dur++) {
          final int runStart = day - dur + 1;
          if (!_stretchCompatible(compatibility, phase, runStart, day)) continue;
          final double logFwd = logForward[runStart * _numPhases + prevPhase[phase]];
          if (logFwd == double.negativeInfinity) continue;
          logProb = _logSumExp(logProb, logFwd + phaseDurations.logPmf[phase][dur - 1]);
        }
        logForward[writeBase + phase] = logProb;
      }
    }

    return logForward;
  }

  static Float64List _backwardPass(
      int totalDays,
      Map<int, int> loggedPhaseByDay,
      ({List<Float64List> logPmf, List<int> maxDuration}) phaseDurations,
      List<List<int>> compatibility) {
    final Float64List logBackward = Float64List((totalDays + 1) * _numPhases);
    logBackward.fillRange(0, logBackward.length, double.negativeInfinity);

    final int? lastLoggedPhase = loggedPhaseByDay[totalDays - 1];
    final int boundaryBase = totalDays * _numPhases;
    if (lastLoggedPhase != null) {
      logBackward[boundaryBase + lastLoggedPhase] = 0.0;
    } else {
      for (int phase = 0; phase < _numPhases; phase++) {
        logBackward[boundaryBase + phase] = 0.0;
      }
    }

    final List<int> nextPhase = List.generate(_numPhases, _nextPhase);

    for (int day = totalDays - 1; day >= 0; day--) {
      final int readBase = day * _numPhases;
      for (int phase = 0; phase < _numPhases; phase++) {
        final int following = nextPhase[phase];
        final int maxDur = min(totalDays - day, phaseDurations.maxDuration[following]);
        double logProb = double.negativeInfinity;
        for (int dur = 1; dur <= maxDur; dur++) {
          final int runEnd = day + dur;
          if (runEnd > totalDays) break;
          if (!_stretchCompatible(compatibility, following, day + 1, runEnd)) continue;
          final double logBwd = logBackward[runEnd * _numPhases + following];
          if (logBwd == double.negativeInfinity) continue;
          logProb = _logSumExp(logProb, phaseDurations.logPmf[following][dur - 1] + logBwd);
        }
        logBackward[readBase + phase] = logProb;
      }
    }

    return logBackward;
  }

  static ({Float64List phaseProbs, Float64List transitionProbs, Float64List phaseProgress})
      _posteriorProbabilities(
          int totalDays,
          Float64List logForward,
          Float64List logBackward,
          ({List<Float64List> logPmf, List<int> maxDuration}) phaseDurations,
          List<List<int>> compatibility) {
    final Float64List phaseProbs = Float64List(totalDays * _numPhases);
    final Float64List transitionProbs = Float64List((totalDays + 1) * _numPhases);
    final Float64List phaseProgress = Float64List(totalDays * _numPhases);

    for (int day = 0; day < totalDays; day++) {
      for (int phase = 0; phase < _numPhases; phase++) {
        final int prev = _previousPhase(phase);
        final int maxDur = phaseDurations.maxDuration[phase];
        double logProbSum = double.negativeInfinity;
        double weightSum = 0.0;
        double weightedDurSum = 0.0;

        for (int dur = 1; dur <= maxDur; dur++) {
          final int latestEnd = day + dur - 1;
          if (latestEnd >= totalDays) break;
          for (int runEnd = day; runEnd <= latestEnd; runEnd++) {
            final int runStart = runEnd - dur + 1;
            if (runStart < 0 || !_stretchCompatible(compatibility, phase, runStart, runEnd)) continue;
            final double logFwd = logForward[runStart * _numPhases + prev];
            final double logBwd = logBackward[(runEnd + 1) * _numPhases + phase];
            if (logFwd == double.negativeInfinity || logBwd == double.negativeInfinity) continue;
            final double logJoint = logFwd + phaseDurations.logPmf[phase][dur - 1] + logBwd;
            logProbSum = _logSumExp(logProbSum, logJoint);
            final double w = exp(logJoint);
            weightSum += w;
            weightedDurSum += dur * w;
          }
        }

        phaseProbs[day * _numPhases + phase] = logProbSum;
        final int durationRange = max(1, maxDur - 1);
        phaseProgress[day * _numPhases + phase] = weightSum > 0.0
            ? ((weightedDurSum / weightSum) - 1.0) / durationRange
            : 0.5;
      }

      double logNorm = double.negativeInfinity;
      for (int phase = 0; phase < _numPhases; phase++) {
        logNorm = _logSumExp(logNorm, phaseProbs[day * _numPhases + phase]);
      }
      for (int phase = 0; phase < _numPhases; phase++) {
        phaseProbs[day * _numPhases + phase] = logNorm == double.negativeInfinity
            ? 1.0 / _numPhases
            : exp(phaseProbs[day * _numPhases + phase] - logNorm);
      }
    }

    for (int day = 1; day < totalDays; day++) {
      for (int phase = 0; phase < _numPhases; phase++) {
        final int following = _nextPhase(phase);
        final int maxDur = phaseDurations.maxDuration[following];
        double logProb = double.negativeInfinity;
        for (int dur = 1; dur <= maxDur; dur++) {
          final int runEnd = day + dur - 1;
          if (runEnd >= totalDays) break;
          if (!_stretchCompatible(compatibility, following, day, runEnd)) continue;
          final double logFwd = logForward[day * _numPhases + phase];
          final double logBwd = logBackward[(runEnd + 1) * _numPhases + following];
          if (logFwd == double.negativeInfinity || logBwd == double.negativeInfinity) continue;
          logProb = _logSumExp(logProb, logFwd + phaseDurations.logPmf[following][dur - 1] + logBwd);
        }
        transitionProbs[day * _numPhases + phase] = logProb;
      }

      double logTransNorm = double.negativeInfinity;
      for (int phase = 0; phase < _numPhases; phase++) {
        logTransNorm = _logSumExp(logTransNorm, transitionProbs[day * _numPhases + phase]);
      }
      for (int phase = 0; phase < _numPhases; phase++) {
        transitionProbs[day * _numPhases + phase] = logTransNorm == double.negativeInfinity
            ? 0.0
            : exp(transitionProbs[day * _numPhases + phase] - logTransNorm);
      }
    }

    return (phaseProbs: phaseProbs, transitionProbs: transitionProbs, phaseProgress: phaseProgress);
  }

  // Table indexed by prevPhase * flowCount + prevFlow; phase = _nextPhase(prevPhase) is implicit.
  static List<_PredictedFields?> _buildNetworkTable(BayesAnalyser analyser) {
    final int flowCount = Flow.values.length;
    final List<String> questions = [];
    final Map<String, (int, int, int, String)> questionMeta = {};

    for (int prevPhase = 0; prevPhase < _numPhases; prevPhase++) {
      for (int prevFlow = 0; prevFlow < flowCount; prevFlow++) {
        final int phase = _nextPhase(prevPhase);
        final String context = 'PHASE=${Phase.values[phase].name.toUpperCase()}, '
            'PREV_PHASE=${Phase.values[prevPhase].name.toUpperCase()}, '
            'PREV_FLOW=${Flow.values[prevFlow].name.toUpperCase()}';

        void ask(Enum value, String field) {
          final String q = '${field.toUpperCase()}=${value.name.toUpperCase()} | $context';
          questions.add(q);
          questionMeta[q] = (prevPhase, phase, prevFlow, '${field.toLowerCase()}:${(value as dynamic).index}');
        }
        void askBool(Enum value, String field) {
          final String q = '${field.toUpperCase()}_${value.name.toUpperCase()}=TRUE | $context';
          questions.add(q);
          questionMeta[q] = (prevPhase, phase, prevFlow, '${field.toLowerCase()}:${(value as dynamic).index}');
        }

        for (final v in Flow.values) { ask(v, 'FLOW'); }
        for (final v in Discharge.values) { ask(v, 'DISCHARGE'); }
        for (final v in Stress.values) { ask(v, 'STRESS'); }
        for (final v in Sleep.values) { ask(v, 'SLEEP'); }
        for (final v in Sex.values) { ask(v, 'SEX'); }
        for (final v in Symptom.values) { askBool(v, 'SYMPTOM'); }
        for (final v in Mood.values) { askBool(v, 'MOOD'); }
      }
    }

    final List<Answer> answers = analyser.quiz(questions);

    final Map<int, Map<String, Map<int, double>>> raw = {};
    for (final a in answers) {
      final meta = questionMeta[a.originalQuery];
      if (meta == null) continue;
      final (int prevPhase, int phase, int prevFlow, String tag) = meta;
      final int key = prevPhase * flowCount + prevFlow;
      raw.putIfAbsent(key, () => {});
      final List<String> parts = tag.split(':');
      raw[key]!.putIfAbsent(parts[0], () => {})[int.parse(parts[1])] = a.probability;
    }

    final List<_PredictedFields?> table = List.filled(_numPhases * flowCount, null);
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
    required List<_PredictedFields?> networkTable,
    required double cycleLength,
  }) {
    final List<QuantumLog> result = [];
    final int daysInRange = rangeEnd.difference(rangeStart).inDays + 1;
    final int rangeStartDay = rangeStart.difference(windowStart).inDays;
    final int flowCount = Flow.values.length;

    final int scanEnd = rangeStartDay + daysInRange;
    int? lastLoggedDay;
    final List<int> nearestPrecedingLog = List<int>.filled(scanEnd, -1);
    for (int day = 0; day < scanEnd; day++) {
      if (loggedDays.containsKey(day)) lastLoggedDay = day;
      nearestPrecedingLog[day] = lastLoggedDay ?? -1;
    }

    final Float64List prevFlowDist = Float64List(flowCount)
      ..fillRange(0, flowCount, 1.0 / flowCount);

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

      final Phase mostLikelyPhase = _mostLikelyPhase(phaseProbs, day);

      final int prevLogDay = nearestPrecedingLog[day];
      final int cycleDay = prevLogDay >= 0
          ? KalmanFilter().predictCycleDay(date, loggedDays[prevLogDay]!)
          : (day + 1).clamp(1, cycleLength.round());

      final Float64List flowAcc = Float64List(flowCount);
      final Float64List dischargeAcc = Float64List(Discharge.values.length);
      final Float64List stressAcc = Float64List(Stress.values.length);
      final Float64List sleepAcc = Float64List(Sleep.values.length);
      final Float64List sexAcc = Float64List(Sex.values.length);
      final Float64List symptomAcc = Float64List(Symptom.values.length);
      final Float64List moodAcc = Float64List(Mood.values.length);

      for (int phase = 0; phase < _numPhases; phase++) {
        final double phaseWeight = phaseProbs[day * _numPhases + phase];
        if (phaseWeight < 1e-9) continue;
        final int prev = _previousPhase(phase);
        for (int pf = 0; pf < flowCount; pf++) {
          final double prevFlowWeight = prevFlowDist[pf];
          if (prevFlowWeight < 1e-9) continue;
          final _PredictedFields? prediction = networkTable[prev * flowCount + pf];
          if (prediction == null) continue;
          final double weight = phaseWeight * prevFlowWeight;
          for (int i = 0; i < flowCount; i++) {
            flowAcc[i] += prediction.flow[i] * weight;
          }
          for (int i = 0; i < dischargeAcc.length; i++) {
            dischargeAcc[i] += prediction.discharge[i] * weight;
          }
          for (int i = 0; i < stressAcc.length; i++) {
            stressAcc[i] += prediction.stress[i] * weight;
          }
          for (int i = 0; i < sleepAcc.length; i++) {
            sleepAcc[i] += prediction.sleep[i] * weight;
          }
          for (int i = 0; i < sexAcc.length; i++) {
            sexAcc[i] += prediction.sex[i] * weight;
          }
          for (int i = 0; i < symptomAcc.length; i++) {
            symptomAcc[i] += prediction.symptoms[i] * weight;
          }
          for (int i = 0; i < moodAcc.length; i++) {
            moodAcc[i] += prediction.moods[i] * weight;
          }
        }
      }

      for (int phase = 0; phase < _numPhases; phase++) {
        final double transitionWeight = transitionProbs[day * _numPhases + phase];
        if (transitionWeight < 0.15) continue;
        final _PredictedFields? incoming = networkTable[phase * flowCount + Flow.none.index];
        if (incoming == null) continue;
        for (int i = 0; i < flowCount; i++) {
          flowAcc[i] += incoming.flow[i] * transitionWeight;
        }
        for (int i = 0; i < dischargeAcc.length; i++) {
          dischargeAcc[i] += incoming.discharge[i] * transitionWeight;
        }
        for (int i = 0; i < stressAcc.length; i++) {
          stressAcc[i] += incoming.stress[i] * transitionWeight;
        }
        for (int i = 0; i < sleepAcc.length; i++) {
          sleepAcc[i] += incoming.sleep[i] * transitionWeight;
        }
        for (int i = 0; i < sexAcc.length; i++) {
          sexAcc[i] += incoming.sex[i] * transitionWeight;
        }
        for (int i = 0; i < symptomAcc.length; i++) {
          symptomAcc[i] += incoming.symptoms[i] * transitionWeight;
        }
        for (int i = 0; i < moodAcc.length; i++) {
          moodAcc[i] += incoming.moods[i] * transitionWeight;
        }
      }

      final double periodProb = phaseProbs[day * _numPhases + _period];
      if (periodProb > 1e-9) {
        final double progress = phaseProgress[day * _numPhases + _period].clamp(0.0, 1.0);
        for (int fi = 0; fi < flowCount; fi++) {
          final double heaviness = fi / (flowCount - 1.0);
          flowAcc[fi] = (flowAcc[fi] * (1.0 - progress * heaviness * 0.6)).clamp(0.0, double.maxFinite);
        }
      }

      double flowTotal = 0.0;
      for (final x in flowAcc) {
        flowTotal += x;
      }
      for (int i = 0; i < flowCount; i++) {
        prevFlowDist[i] = flowTotal > 1e-9 ? flowAcc[i] / flowTotal : 1.0 / flowCount;
      }

      result.add(QuantumLog(
        date: date,
        cycleDay: cycleDay,
        phase: mostLikelyPhase,
        flow: _toNormalizedMap(flowAcc, Flow.values),
        discharge: _toNormalizedMap(dischargeAcc, Discharge.values),
        stress: _toNormalizedMap(stressAcc, Stress.values),
        sleep: _toNormalizedMap(sleepAcc, Sleep.values),
        sex: _toNormalizedMap(sexAcc, Sex.values),
        symptoms: _toClampedMap(symptomAcc, Symptom.values),
        moods: _toClampedMap(moodAcc, Mood.values),
      ));
    }

    return result;
  }

  static int _nextPhase(int phase) => (phase + 1) % _numPhases;
  static int _previousPhase(int phase) => (phase + _numPhases - 1) % _numPhases;

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
    for (int phase = 1; phase < _numPhases; phase++) {
      final double p = phaseProbs[day * _numPhases + phase];
      if (p > bestProb) { bestProb = p; best = phase; }
    }
    return Phase.values[best];
  }

  static List<double> _normalizeList(List<double> v) {
    double s = 0.0;
    for (final x in v) {
      s += x;
    }
    if (s == 0.0) return List<double>.filled(v.length, 1.0 / v.length);
    return [for (final x in v) x / s];
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
