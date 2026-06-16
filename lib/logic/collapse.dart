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
import 'package:ml_linalg/linalg.dart';
import 'package:statistics/statistics.dart';

typedef _FieldDists = ({
  Vector flow,
  Vector discharge,
  Vector stress,
  Vector sleep,
  Vector sex,
  Vector symptoms,
  Vector moods,
});

typedef _IsolatePayload = ({
  Set<String> allKeys,
  Map<String, Map<String, dynamic>> anchorData,
  int year,
  int month,
  double cycleLength,
  double periodLength,
  int ovulationDay,
});

typedef _IsolateResult = ({
  Float64List gamma,
  Float64List xi,
  Float64List dwellProgress,
  int T,
  DateTime rangeStart,
  Map<int, Map<String, dynamic>> anchorsByT,
});

class Hsmm {
  static final Hsmm _instance = Hsmm._internal();
  factory Hsmm() => _instance;
  Hsmm._internal();

  final Map<(int, int), (List<QuantumLog>, int)> _cache = {};
  int _version = 0;

  void invalidate() => _version++;

  Future<List<QuantumLog>> month(int year, int month) async {
    final (int, int) cacheKey = (year, month);
    final existing = _cache[cacheKey];
    if (existing != null && existing.$2 == _version) return existing.$1;

    final KalmanFilter kalman = KalmanFilter();
    final double cycleLength = kalman.cycleLength;
    final double periodLength = kalman.periodLength;
    final int ovulationDay = kalman.ovulationDay;

    final DateTime monthStart = DateTime(year, month, 1);
    final DateTime monthEnd = DateTime(year, month + 1, 0);
    final int cap = (2 * cycleLength).ceil();
    final DateTime loadStart = monthStart.subtract(Duration(days: cap));
    final DateTime loadEnd = monthEnd.add(Duration(days: cap));

    final Set<String> allKeys = HiveDatabase().logs.keys
        .cast<String>()
        .map((k) => DateTime.parse(k).toIso8601String().substring(0, 10))
        .toSet();

    final Map<String, Map<String, dynamic>> anchorData = {};
    await for (final log in LogRepo().range(loadStart, loadEnd)) {
      anchorData[LogRepo().dateToString(log.date).substring(0, 10)] = log.toJson();
    }

    final _IsolatePayload payload = (
      allKeys: allKeys,
      anchorData: anchorData,
      year: year,
      month: month,
      cycleLength: cycleLength,
      periodLength: periodLength,
      ovulationDay: ovulationDay,
    );

    final Future<_IsolateResult> hsmmFuture =
        Isolate.run(() => Hsmm._runHsmm(payload));
    final Map<String, _FieldDists> queryTable =
        _buildQueryTable(BayesNetwork().analyser);
    final _IsolateResult result = await hsmmFuture;

    final Map<int, Log> anchors = {
      for (final e in result.anchorsByT.entries) e.key: Log.fromJson(e.value),
    };

    final List<QuantumLog> logs = _buildMonth(
      rangeStart: result.rangeStart,
      monthStart: monthStart,
      monthEnd: monthEnd,
      anchors: anchors,
      gamma: result.gamma,
      xi: result.xi,
      dwellProgress: result.dwellProgress,
      queryTable: queryTable,
      cycleLength: cycleLength,
    );
    _cache[cacheKey] = (logs, _version);
    return logs;
  }

  // ── Isolate entry point ──────────────────────────────────────────────────

  static _IsolateResult _runHsmm(_IsolatePayload payload) {
    final int year = payload.year;
    final int month = payload.month;
    final double cycleLength = payload.cycleLength;
    final double periodLength = payload.periodLength;
    final int ovulationDay = payload.ovulationDay;

    final DateTime monthStart = DateTime(year, month, 1);
    final DateTime monthEnd = DateTime(year, month + 1, 0);
    final int cap = (2 * cycleLength).ceil();

    final DateTime rangeStart = _findBoundary(monthStart, -1, cap, payload.allKeys);
    final DateTime rangeEnd = _findBoundary(monthEnd, 1, cap, payload.allKeys);

    final int T = rangeEnd.difference(rangeStart).inDays + 1;

    final Map<int, int> anchorPhase = {};
    final Map<int, Map<String, dynamic>> anchorsByT = {};
    for (int t = 0; t < T; t++) {
      final DateTime date = rangeStart.add(Duration(days: t));
      final String key = date.toIso8601String().substring(0, 10);
      final Map<String, dynamic>? data = payload.anchorData[key];
      if (data != null) {
        anchorPhase[t] = data['phase'] as int;
        anchorsByT[t] = data;
      }
    }

    final dwell = _buildDwell(cycleLength, periodLength, ovulationDay);
    final emit = _buildEmit(anchorPhase, T);
    final logAlpha = _forward(T, anchorPhase, dwell, emit);
    final logBeta = _backward(T, anchorPhase, dwell, emit);
    final marg = _marginals(T, logAlpha, logBeta, dwell, emit);

    return (
      gamma: marg.gamma,
      xi: marg.xi,
      dwellProgress: marg.dwellProgress,
      T: T,
      rangeStart: rangeStart,
      anchorsByT: anchorsByT,
    );
  }

  // ── HSMM math ────────────────────────────────────────────────────────────

  static List<double> _poissonPmf(double lambda, int maxD) {
    final List<double> pmf = List<double>.filled(maxD, 0.0);
    double logFactorial = 0.0;
    for (int d = 1; d <= maxD; d++) {
      logFactorial += log(d);
      pmf[d - 1] = exp(-lambda + (d * log(lambda)) - logFactorial);
    }
    return _normalize(pmf);
  }

  static List<double> _normalize(List<double> v) {
    final Vector vec = Vector.fromList(v, dtype: DType.float64);
    final double s = vec.sum();
    if (s == 0.0) return List<double>.filled(v.length, 1.0 / v.length);
    return (vec / s).toList();
  }

  static double _logAddExp(double a, double b) {
    if (a == double.negativeInfinity) return b;
    if (b == double.negativeInfinity) return a;
    return a > b ? a + log(1.0 + exp(b - a)) : b + log(1.0 + exp(a - b));
  }

  static int _next(int s) => (s + 1) % 4;

  static int _prev(int s) => (s + 3) % 4;

  static DateTime _findBoundary(DateTime anchor, int direction, int cap, Set<String> allKeys) =>
      Iterable.generate(cap, (i) => anchor.add(Duration(days: (i + 1) * direction)))
          .firstWhere(
            (d) => allKeys.contains(d.toIso8601String().substring(0, 10)),
            orElse: () => anchor,
          );

  static ({List<Vector> logPmf, List<int> maxDwell}) _buildDwell(
      double cycleLength,
      double periodLength,
      int ovulationDay,) {
    final List<double> means = [
      periodLength,
      max(1.0, ovulationDay - periodLength.round() - 2.0),
      3.0,
      max(1.0, cycleLength - ovulationDay - 1.0),
    ];
    final List<Vector> logPmf = [];
    final List<int> maxDwell = [];
    for (int s = 0; s < 4; s++) {
      final double lambda = max(1.0, means[s]);
      final int md = (3 * lambda).ceil().clamp(1, 120);
      final List<double> p = _poissonPmf(lambda, md);
      logPmf.add(Vector.fromList(
        [for (final x in p) x > 0 ? log(x) : double.negativeInfinity],
        dtype: DType.float64,
      ));
      maxDwell.add(md);
    }
    return (logPmf: logPmf, maxDwell: maxDwell);
  }

  static List<List<int>> _buildEmit(Map<int, int> anchorPhase, int T) {
    final List<List<int>> prefix =
        List.generate(4, (_) => List.filled(T + 1, 0));
    for (int s = 0; s < 4; s++) {
      for (int t = 0; t < T; t++) {
        prefix[s][t + 1] = prefix[s][t];
        final int? ph = anchorPhase[t];
        if (ph != null && ph != s) prefix[s][t + 1]++;
      }
    }
    return prefix;
  }

  static bool _segmentValid(List<List<int>> emit, int s, int start, int end) =>
      emit[s][end + 1] == emit[s][start];

  static Float64List _forward(
      int T,
      Map<int, int> anchorPhase,
      ({List<Vector> logPmf, List<int> maxDwell}) dwell,
      List<List<int>> emit,) {
    final Float64List logAlpha = Float64List((T + 1) * 4);
    for (int i = 0; i < logAlpha.length; i++) {
      logAlpha[i] = double.negativeInfinity;
    }

    final int? startAnchor = anchorPhase[0];
    if (startAnchor != null) {
      logAlpha[startAnchor] = 0.0;
    } else {
      final double logQuarter = log(0.25);
      for (int s = 0; s < 4; s++) {
        logAlpha[s] = logQuarter;
      }
    }

    final List<int> prevState = List.generate(4, _prev);

    for (int t = 0; t < T; t++) {
      final int base = (t + 1) * 4;
      for (int s = 0; s < 4; s++) {
        final int prev = prevState[s];
        final int maxD = min(t + 1, dwell.maxDwell[s]);
        double logSum = double.negativeInfinity;
        for (int d = 1; d <= maxD; d++) {
          if (!_segmentValid(emit, s, t - d + 1, t)) continue;
          final double la = logAlpha[(t - d + 1) * 4 + prev];
          if (la == double.negativeInfinity) continue;
          logSum = _logAddExp(logSum, la + dwell.logPmf[s][d - 1]);
        }
        logAlpha[base + s] = logSum;
      }
    }

    return logAlpha;
  }

  static Float64List _backward(
      int T,
      Map<int, int> anchorPhase,
      ({List<Vector> logPmf, List<int> maxDwell}) dwell,
      List<List<int>> emit,) {
    final Float64List logBeta = Float64List((T + 1) * 4);
    for (int i = 0; i < logBeta.length; i++) {
      logBeta[i] = double.negativeInfinity;
    }

    final int? endAnchor = anchorPhase[T - 1];
    final int endBase = T * 4;
    if (endAnchor != null) {
      logBeta[endBase + endAnchor] = 0.0;
    } else {
      for (int s = 0; s < 4; s++) {
        logBeta[endBase + s] = 0.0;
      }
    }

    final List<int> nextState = List.generate(4, _next);

    for (int t = T - 1; t >= 0; t--) {
      final int base = t * 4;
      for (int s = 0; s < 4; s++) {
        final int nextS = nextState[s];
        final int maxD = min(T - t, dwell.maxDwell[nextS]);
        double logSum = double.negativeInfinity;
        for (int d = 1; d <= maxD; d++) {
          final int segEnd = t + d;
          if (segEnd > T) break;
          if (!_segmentValid(emit, nextS, t + 1, t + d)) continue;
          final double lb = logBeta[segEnd * 4 + nextS];
          if (lb == double.negativeInfinity) continue;
          logSum = _logAddExp(logSum, dwell.logPmf[nextS][d - 1] + lb);
        }
        logBeta[base + s] = logSum;
      }
    }

    return logBeta;
  }

  static ({Float64List gamma, Float64List xi, Float64List dwellProgress}) _marginals(
      int T,
      Float64List logAlpha,
      Float64List logBeta,
      ({List<Vector> logPmf, List<int> maxDwell}) dwell,
      List<List<int>> emit,) {
    final Float64List gamma = Float64List(T * 4);
    final Float64List xi = Float64List((T + 1) * 4);
    final Float64List dwellProgress = Float64List(T * 4);

    for (int t = 0; t < T; t++) {
      for (int s = 0; s < 4; s++) {
        final int prev = _prev(s);
        final int maxD = dwell.maxDwell[s];
        double logSum = double.negativeInfinity;
        double sumWeight = 0.0;
        double sumWeightedD = 0.0;
        for (int d = 1; d <= maxD; d++) {
          final int tauMax = t + d - 1;
          if (tauMax >= T) break;
          for (int tau = t; tau <= tauMax; tau++) {
            final int segStart = tau - d + 1;
            if (segStart < 0 || !_segmentValid(emit, s, segStart, tau)) continue;
            final double la = logAlpha[segStart * 4 + prev];
            final double lb = logBeta[(tau + 1) * 4 + s];
            if (la == double.negativeInfinity || lb == double.negativeInfinity) continue;
            logSum = _logAddExp(logSum, la + dwell.logPmf[s][d - 1] + lb);
            final double w = exp(la + dwell.logPmf[s][d - 1] + lb);
            sumWeight += w;
            sumWeightedD += d * w;
          }
        }
        gamma[t * 4 + s] = logSum;
        final int range = max(1, maxD - 1);
        dwellProgress[t * 4 + s] = sumWeight > 0.0
            ? ((sumWeightedD / sumWeight) - 1.0) / range
            : 0.5;
      }

      double logZ = double.negativeInfinity;
      for (int s = 0; s < 4; s++) {
        logZ = _logAddExp(logZ, gamma[t * 4 + s]);
      }
      for (int s = 0; s < 4; s++) {
        gamma[t * 4 + s] = logZ == double.negativeInfinity
            ? 0.25
            : exp(gamma[t * 4 + s] - logZ);
      }
    }

    for (int t = 1; t < T; t++) {
      for (int s = 0; s < 4; s++) {
        final int nextS = _next(s);
        final int maxD = dwell.maxDwell[nextS];
        double logSum = double.negativeInfinity;
        for (int d = 1; d <= maxD; d++) {
          final int segEnd = t + d - 1;
          if (segEnd >= T) break;
          if (!_segmentValid(emit, nextS, t, segEnd)) continue;
          final double la = logAlpha[t * 4 + s];
          final double lb = logBeta[(segEnd + 1) * 4 + nextS];
          if (la == double.negativeInfinity || lb == double.negativeInfinity) continue;
          logSum = _logAddExp(logSum, la + dwell.logPmf[nextS][d - 1] + lb);
        }
        xi[t * 4 + s] = logSum;
      }

      double logXiZ = double.negativeInfinity;
      for (int s = 0; s < 4; s++) {
        logXiZ = _logAddExp(logXiZ, xi[t * 4 + s]);
      }
      for (int s = 0; s < 4; s++) {
        xi[t * 4 + s] = logXiZ == double.negativeInfinity
            ? 0.0
            : exp(xi[t * 4 + s] - logXiZ);
      }
    }

    return (gamma: gamma, xi: xi, dwellProgress: dwellProgress);
  }

  // ── Query table ──────────────────────────────────────────────────────────

  static String _tripleKey(int s, int sNext, int pf) => '$s,$sNext,$pf';

  static Vector _normVec(Map<int, double> raw, int count) {
    final Vector v = Vector.fromList(
      [for (int i = 0; i < count; i++) raw[i] ?? 0.0],
      dtype: DType.float64,
    );
    final double s = v.sum();
    return s == 0.0
        ? Vector.filled(count, 1.0 / count, dtype: DType.float64)
        : v / s;
  }

  static Vector _probVec(Map<int, double> raw, int count) =>
      Vector.fromList(
        [for (int i = 0; i < count; i++) raw[i] ?? 0.5],
        dtype: DType.float64,
      );

  static Map<String, _FieldDists> _buildQueryTable(BayesAnalyser analyser) {
    final List<String> allQuestions = [];
    final Map<String, (int, int, int, String)> questionMeta = {};

    for (int s = 0; s < 4; s++) {
      for (int pf = 0; pf < Flow.values.length; pf++) {
        final int sNext = _next(s);
        final String phaseStr = Phase.values[sNext].name.toUpperCase();
        final String prevPhaseStr = Phase.values[s].name.toUpperCase();
        final String prevFlowStr = Flow.values[pf].name.toUpperCase();
        final String ev =
            'PHASE=$phaseStr, PREV_PHASE=$prevPhaseStr, PREV_FLOW=$prevFlowStr';

        for (final v in Flow.values) {
          final String q = 'P(FLOW=${v.name.toUpperCase()}|$ev)';
          allQuestions.add(q);
          questionMeta[q] = (s, sNext, pf, 'flow:${v.index}');
        }
        for (final v in Discharge.values) {
          final String q = 'P(DISCHARGE=${v.name.toUpperCase()}|$ev)';
          allQuestions.add(q);
          questionMeta[q] = (s, sNext, pf, 'discharge:${v.index}');
        }
        for (final v in Stress.values) {
          final String q = 'P(STRESS=${v.name.toUpperCase()}|$ev)';
          allQuestions.add(q);
          questionMeta[q] = (s, sNext, pf, 'stress:${v.index}');
        }
        for (final v in Sleep.values) {
          final String q = 'P(SLEEP=${v.name.toUpperCase()}|$ev)';
          allQuestions.add(q);
          questionMeta[q] = (s, sNext, pf, 'sleep:${v.index}');
        }
        for (final v in Sex.values) {
          final String q = 'P(SEX=${v.name.toUpperCase()}|$ev)';
          allQuestions.add(q);
          questionMeta[q] = (s, sNext, pf, 'sex:${v.index}');
        }
        for (final v in Symptom.values) {
          final String q = 'P(SYMPTOM_${v.name.toUpperCase()}=TRUE|$ev)';
          allQuestions.add(q);
          questionMeta[q] = (s, sNext, pf, 'symptom:${v.index}');
        }
        for (final v in Mood.values) {
          final String q = 'P(MOOD_${v.name.toUpperCase()}=TRUE|$ev)';
          allQuestions.add(q);
          questionMeta[q] = (s, sNext, pf, 'mood:${v.index}');
        }
      }
    }

    final List<Answer> answers = analyser.quiz(allQuestions);

    final Map<String, Map<String, Map<int, double>>> raw = {};
    for (final a in answers) {
      final meta = questionMeta[a.originalQuery];
      if (meta == null) continue;
      final (int s, int sNext, int pf, String fieldTag) = meta;
      final String key = _tripleKey(s, sNext, pf);
      raw.putIfAbsent(key, () => {});
      final List<String> parts = fieldTag.split(':');
      final String field = parts[0];
      final int valIdx = int.parse(parts[1]);
      raw[key]!.putIfAbsent(field, () => {})[valIdx] = a.probability;
    }

    return {
      for (final entry in raw.entries)
        entry.key: (
          flow: _normVec(entry.value['flow'] ?? {}, Flow.values.length),
          discharge: _normVec(entry.value['discharge'] ?? {}, Discharge.values.length),
          stress: _normVec(entry.value['stress'] ?? {}, Stress.values.length),
          sleep: _normVec(entry.value['sleep'] ?? {}, Sleep.values.length),
          sex: _normVec(entry.value['sex'] ?? {}, Sex.values.length),
          symptoms: _probVec(entry.value['symptom'] ?? {}, Symptom.values.length),
          moods: _probVec(entry.value['mood'] ?? {}, Mood.values.length),
        ),
    };
  }

  // ── Month building ────────────────────────────────────────────────────────

  static List<QuantumLog> _buildMonth({
    required DateTime rangeStart,
    required DateTime monthStart,
    required DateTime monthEnd,
    required Map<int, Log> anchors,
    required Float64List gamma,
    required Float64List xi,
    required Float64List dwellProgress,
    required Map<String, _FieldDists> queryTable,
    required double cycleLength,
  }) {
    final List<QuantumLog> result = [];
    final int daysInMonth = monthEnd.difference(monthStart).inDays + 1;
    final int monthOffset = monthStart.difference(rangeStart).inDays;

    // Precompute nearest preceding anchor index for each t — O(T) vs O(T²).
    final int scanEnd = monthOffset + daysInMonth;
    int? lastAnchorT;
    final List<int> prevAnchorIdx = List<int>.filled(scanEnd, -1);
    for (int t = 0; t < scanEnd; t++) {
      if (anchors.containsKey(t)) lastAnchorT = t;
      prevAnchorIdx[t] = lastAnchorT ?? -1;
    }

    final int flowCount = Flow.values.length;
    final Float64List prevFlowProbs = Float64List(flowCount)
      ..fillRange(0, flowCount, 1.0 / flowCount);

    for (int mi = 0; mi < daysInMonth; mi++) {
      final int t = monthOffset + mi;
      final DateTime date = monthStart.add(Duration(days: mi));

      final Log? anchor = anchors[t];
      if (anchor != null) {
        result.add(QuantumLog.fromLog(anchor));
        prevFlowProbs.fillRange(0, flowCount, 0.0);
        prevFlowProbs[anchor.flow.index] = 1.0;
        continue;
      }

      final Phase phase = _argmaxPhase(gamma, t);

      final int prevT = prevAnchorIdx[t];
      final int cycleDay = prevT >= 0
          ? KalmanFilter().predictCycleDay(date, anchors[prevT]!)
          : (t + 1).clamp(1, cycleLength.round());

      Vector flowAcc = Vector.zero(flowCount, dtype: DType.float64);
      Vector dischargeAcc = Vector.zero(Discharge.values.length, dtype: DType.float64);
      Vector stressAcc = Vector.zero(Stress.values.length, dtype: DType.float64);
      Vector sleepAcc = Vector.zero(Sleep.values.length, dtype: DType.float64);
      Vector sexAcc = Vector.zero(Sex.values.length, dtype: DType.float64);
      Vector symptomsAcc = Vector.zero(Symptom.values.length, dtype: DType.float64);
      Vector moodsAcc = Vector.zero(Mood.values.length, dtype: DType.float64);

      // Accumulate field distributions, marginalising over prevFlow uncertainty.
      for (int s = 0; s < 4; s++) {
        final double w = gamma[t * 4 + s];
        if (w < 1e-9) continue;
        final int prevS = _prev(s);
        for (int pf = 0; pf < flowCount; pf++) {
          final double pfW = prevFlowProbs[pf];
          if (pfW < 1e-9) continue;
          final _FieldDists? fd = queryTable[_tripleKey(prevS, s, pf)];
          if (fd == null) continue;
          final double combined = w * pfW;
          flowAcc = flowAcc + fd.flow * combined;
          dischargeAcc = dischargeAcc + fd.discharge * combined;
          stressAcc = stressAcc + fd.stress * combined;
          sleepAcc = sleepAcc + fd.sleep * combined;
          sexAcc = sexAcc + fd.sex * combined;
          symptomsAcc = symptomsAcc + fd.symptoms * combined;
          moodsAcc = moodsAcc + fd.moods * combined;
        }
      }

      // Blend in incoming-phase characteristics on likely transition days.
      for (int s = 0; s < 4; s++) {
        final double transW = xi[t * 4 + s];
        if (transW < 0.15) continue;
        final int nextS = _next(s);
        final _FieldDists? fd = queryTable[_tripleKey(s, nextS, Flow.none.index)];
        if (fd == null) continue;
        flowAcc = flowAcc + fd.flow * transW;
        dischargeAcc = dischargeAcc + fd.discharge * transW;
        stressAcc = stressAcc + fd.stress * transW;
        sleepAcc = sleepAcc + fd.sleep * transW;
        sexAcc = sexAcc + fd.sex * transW;
        symptomsAcc = symptomsAcc + fd.symptoms * transW;
        moodsAcc = moodsAcc + fd.moods * transW;
      }

      // Attenuate heavy flow as the menstrual phase progresses.
      final double menstrualGamma = gamma[t * 4 + 0];
      if (menstrualGamma > 1e-9) {
        final double dp = dwellProgress[t * 4 + 0].clamp(0.0, 1.0);
        final List<double> attenuated = List<double>.generate(flowCount, (fi) {
          final double heaviness = fi / (flowCount - 1.0);
          return (flowAcc[fi] * (1.0 - dp * heaviness * 0.6)).clamp(0.0, double.maxFinite);
        });
        flowAcc = Vector.fromList(attenuated, dtype: DType.float64);
      }

      // Update prevFlow probability from the current day's flow distribution.
      final double flowSum = flowAcc.sum();
      for (int i = 0; i < flowCount; i++) {
        prevFlowProbs[i] = flowSum > 1e-9
            ? flowAcc[i] / flowSum
            : 1.0 / flowCount;
      }

      result.add(QuantumLog(
        date: date,
        cycleDay: cycleDay,
        phase: phase,
        flow: _normVecToMap(flowAcc, Flow.values),
        discharge: _normVecToMap(dischargeAcc, Discharge.values),
        stress: _normVecToMap(stressAcc, Stress.values),
        sleep: _normVecToMap(sleepAcc, Sleep.values),
        sex: _normVecToMap(sexAcc, Sex.values),
        symptoms: _clampVecToMap(symptomsAcc, Symptom.values),
        moods: _clampVecToMap(moodsAcc, Mood.values),
      ));
    }

    return result;
  }

  static Phase _argmaxPhase(Float64List gamma, int t) {
    int best = 0;
    double bestVal = gamma[t * 4];
    for (int s = 1; s < 4; s++) {
      final double v = gamma[t * 4 + s];
      if (v > bestVal) {
        bestVal = v;
        best = s;
      }
    }
    return Phase.values[best];
  }

  static Map<T, double> _normVecToMap<T extends Enum>(Vector acc, List<T> values) {
    final double s = acc.sum();
    final Vector v = s < 1e-9
        ? Vector.filled(values.length, 1.0 / values.length, dtype: DType.float64)
        : acc / s;
    return {for (final e in values) e: v[e.index]};
  }

  static Map<T, double> _clampVecToMap<T extends Enum>(Vector acc, List<T> values) =>
      {for (final e in values) e: acc[e.index].clamp(0.0, 1.0)};
}
