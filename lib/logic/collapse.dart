// Hsmm: Hidden Semi-Markov Model for menstrual cycle phase prediction.
//
// A menstrual cycle moves through four phases in strict order, then repeats:
//
//   period (0) → follicular (1) → ovulatory (2) → luteal (3) → period → …
//
// Each phase has a typical duration (modelled as a Poisson distribution).
// Days that the user has logged are treated as fixed anchors — the model is
// not allowed to assign them a different phase than the one recorded.
// For every unlogged day the model produces a probability distribution over
// the four phases, and those probabilities are used to predict symptoms,
// flow, mood, etc. via the Bayesian network.
//
// The core algorithm (forward-backward) runs inside a Dart isolate so it
// never blocks the UI thread.

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

// ── Phase index constants ────────────────────────────────────────────────────
// The four phases are encoded as 0-3 so they can be used as array indices.

const int _period = 0;
const int _numPhases = 4;

// ── Data types ───────────────────────────────────────────────────────────────

// The Bayesian network prediction for every field, given a specific
// (previousPhase, currentPhase, previousFlow) context.
typedef _PredictedFields = ({
  Vector flow,
  Vector discharge,
  Vector stress,
  Vector sleep,
  Vector sex,
  Vector symptoms,
  Vector moods,
});

// Everything the isolate needs to run the forward-backward algorithm.
typedef _HsmmInput = ({
  Set<String> allKeys,
  Map<String, Map<String, dynamic>> anchorData,
  int year,
  int month,
  double cycleLength,
  double periodLength,
  int ovulationDay,
});

// Everything the isolate produces and passes back to the main thread.
typedef _HsmmOutput = ({
  // phaseProbs[day * 4 + phase] = P(being in `phase` on `day`)
  Float64List phaseProbs,
  // transitionProbs[day * 4 + phase] = P(phase ends on `day`, next phase starts day+1)
  Float64List transitionProbs,
  // phaseProgress[day * 4 + phase] = how far through `phase` we are on `day` (0=just started, 1=ending)
  Float64List phaseProgress,
  int totalDays,
  DateTime windowStart,
  Map<int, Map<String, dynamic>> logsByDay,
});

class Hsmm {
  static final Hsmm _instance = Hsmm._internal();
  factory Hsmm() => _instance;
  Hsmm._internal();

  // Version counter — incremented whenever logs change so stale cache entries
  // are automatically invalidated on the next access.
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

    // Load logs from two full cycles before and after the month so the
    // algorithm has enough context to anchor the phase probabilities.
    final int windowRadius = (2 * cycleLength).ceil();
    final DateTime loadStart = monthStart.subtract(Duration(days: windowRadius));
    final DateTime loadEnd = monthEnd.add(Duration(days: windowRadius));

    final Set<String> allKeys = HiveDatabase().logs.keys
        .cast<String>()
        .map((k) => DateTime.parse(k).toIso8601String().substring(0, 10))
        .toSet();

    final Map<String, Map<String, dynamic>> anchorData = {};
    await for (final log in LogRepo().range(loadStart, loadEnd)) {
      anchorData[LogRepo().dateToString(log.date).substring(0, 10)] = log.toJson();
    }

    final _HsmmInput input = (
      allKeys: allKeys,
      anchorData: anchorData,
      year: year,
      month: month,
      cycleLength: cycleLength,
      periodLength: periodLength,
      ovulationDay: ovulationDay,
    );

    // Run the heavy forward-backward computation in a separate isolate, and
    // simultaneously build the Bayesian network lookup table on the main thread.
    final Future<_HsmmOutput> hsmmFuture = Isolate.run(() => Hsmm._runHsmm(input));
    final Map<String, _PredictedFields> networkTable =
        _buildNetworkTable(BayesNetwork().analyser);
    final _HsmmOutput output = await hsmmFuture;

    final Map<int, Log> loggedDays = {
      for (final e in output.logsByDay.entries) e.key: Log.fromJson(e.value),
    };

    final List<QuantumLog> logs = _buildPredictions(
      windowStart: output.windowStart,
      monthStart: monthStart,
      monthEnd: monthEnd,
      loggedDays: loggedDays,
      phaseProbs: output.phaseProbs,
      transitionProbs: output.transitionProbs,
      phaseProgress: output.phaseProgress,
      networkTable: networkTable,
      cycleLength: cycleLength,
    );
    _cache[cacheKey] = (logs, _version);
    return logs;
  }

  // ── Isolate entry point ──────────────────────────────────────────────────

  static _HsmmOutput _runHsmm(_HsmmInput input) {
    final int year = input.year;
    final int month = input.month;
    final double cycleLength = input.cycleLength;
    final double periodLength = input.periodLength;
    final int ovulationDay = input.ovulationDay;

    final DateTime monthStart = DateTime(year, month, 1);
    final DateTime monthEnd = DateTime(year, month + 1, 0);
    final int windowRadius = (2 * cycleLength).ceil();

    // Expand the analysis window to the nearest logged days outside the month,
    // so the algorithm has firm anchor points on both sides.
    final DateTime windowStart = _findNearestLog(monthStart, -1, windowRadius, input.allKeys);
    final DateTime windowEnd = _findNearestLog(monthEnd, 1, windowRadius, input.allKeys);

    final int totalDays = windowEnd.difference(windowStart).inDays + 1;

    // Build two maps indexed by day offset from windowStart:
    //   loggedPhaseByDay: the phase the user recorded for that day
    //   logsByDay: the full log data for that day
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
      totalDays: totalDays,
      windowStart: windowStart,
      logsByDay: logsByDay,
    );
  }

  // ── Phase duration distributions ─────────────────────────────────────────
  //
  // How long does each phase typically last?  We model this as a Poisson
  // distribution centred on the Kalman-estimated mean for that phase.
  // Storing log-probabilities avoids underflow when multiplying many small
  // numbers together.

  static ({List<Vector> logPmf, List<int> maxDuration}) _buildPhaseDurations(
      double cycleLength,
      double periodLength,
      int ovulationDay,) {
    final List<double> meanDurations = [
      periodLength,                                         // period
      max(1.0, ovulationDay - periodLength.round() - 2.0), // follicular
      3.0,                                                  // ovulatory (roughly fixed)
      max(1.0, cycleLength - ovulationDay - 1.0),          // luteal
    ];

    final List<Vector> logPmf = [];
    final List<int> maxDuration = [];
    for (int phase = 0; phase < _numPhases; phase++) {
      final double mean = max(1.0, meanDurations[phase]);
      // Cap at 3× the mean; durations beyond that are astronomically unlikely.
      final int maxDur = (3 * mean).ceil().clamp(1, 120);
      final List<double> probs = _poissonDistribution(mean, maxDur);
      logPmf.add(Vector.fromList(
        [for (final p in probs) p > 0 ? log(p) : double.negativeInfinity],
        dtype: DType.float64,
      ));
      maxDuration.add(maxDur);
    }
    return (logPmf: logPmf, maxDuration: maxDuration);
  }

  // Returns the normalised Poisson PMF for values 1..maxDur.
  static List<double> _poissonDistribution(double mean, int maxDur) {
    final List<double> probs = List<double>.filled(maxDur, 0.0);
    double logFactorial = 0.0;
    for (int d = 1; d <= maxDur; d++) {
      logFactorial += log(d);
      probs[d - 1] = exp(-mean + (d * log(mean)) - logFactorial);
    }
    return _normalizeList(probs);
  }

  // ── Compatibility table ───────────────────────────────────────────────────
  //
  // Before assigning a phase to a stretch of days we need to check: does the
  // user's logged data allow it?  A stretch of days is compatible with a
  // given phase only if the user has not logged a *different* phase for any
  // day in that stretch.
  //
  // We use prefix sums so compatibility of any [start, end] range can be
  // checked in O(1): if the count of incompatible days is zero, the stretch
  // is allowed.
  //
  // compatibility[phase][day+1] - compatibility[phase][day] = 1 if day is
  // incompatible with phase (user logged a different phase), 0 otherwise.

  static List<List<int>> _buildCompatibility(Map<int, int> loggedPhaseByDay, int totalDays) {
    final List<List<int>> prefix =
        List.generate(_numPhases, (_) => List.filled(totalDays + 1, 0));
    for (int phase = 0; phase < _numPhases; phase++) {
      for (int day = 0; day < totalDays; day++) {
        prefix[phase][day + 1] = prefix[phase][day];
        final int? logged = loggedPhaseByDay[day];
        if (logged != null && logged != phase) prefix[phase][day + 1]++;
      }
    }
    return prefix;
  }

  // Returns true if every day in [start, end] is compatible with `phase`.
  static bool _stretchCompatible(List<List<int>> compatibility, int phase, int start, int end) =>
      compatibility[phase][end + 1] == compatibility[phase][start];

  // ── Forward pass ─────────────────────────────────────────────────────────
  //
  // We sweep from left (earliest day) to right (latest day).
  // For each day and each phase we ask:
  //   "What is the log-probability of arriving at the END of this day
  //    having just been in `phase` since some earlier day?"
  //
  // logForward[(day+1) * 4 + phase] holds this value.
  // The +1 offset means index 0 is a synthetic "before the window" boundary.

  static Float64List _forwardPass(
      int totalDays,
      Map<int, int> loggedPhaseByDay,
      ({List<Vector> logPmf, List<int> maxDuration}) phaseDurations,
      List<List<int>> compatibility,) {
    final Float64List logForward = Float64List((totalDays + 1) * _numPhases);
    logForward.fillRange(0, logForward.length, double.negativeInfinity);

    // Boundary: before day 0.  If the first day is logged we fix the phase;
    // otherwise we start with equal probability across all phases.
    final int? firstLoggedPhase = loggedPhaseByDay[0];
    if (firstLoggedPhase != null) {
      logForward[firstLoggedPhase] = 0.0; // log(1)
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
        // Consider every possible run of `phase` ending on `day`:
        // the run could have started anywhere from (day - maxDur + 1) to day.
        final int maxDur = min(day + 1, phaseDurations.maxDuration[phase]);
        double logProb = double.negativeInfinity;
        for (int dur = 1; dur <= maxDur; dur++) {
          final int runStart = day - dur + 1;
          if (!_stretchCompatible(compatibility, phase, runStart, day)) continue;
          // The previous phase must have ended at runStart - 1.
          final double logFwd = logForward[runStart * _numPhases + prevPhase[phase]];
          if (logFwd == double.negativeInfinity) continue;
          logProb = _logSumExp(logProb, logFwd + phaseDurations.logPmf[phase][dur - 1]);
        }
        logForward[writeBase + phase] = logProb;
      }
    }

    return logForward;
  }

  // ── Backward pass ────────────────────────────────────────────────────────
  //
  // We sweep from right (latest day) to left (earliest day).
  // For each day and each phase we ask:
  //   "If we just finished being in `phase` on `day`, what is the
  //    log-probability of all the days that come after?"
  //
  // logBackward[day * 4 + phase] holds this value.
  // Index (totalDays * 4) is a synthetic "after the window" boundary.

  static Float64List _backwardPass(
      int totalDays,
      Map<int, int> loggedPhaseByDay,
      ({List<Vector> logPmf, List<int> maxDuration}) phaseDurations,
      List<List<int>> compatibility,) {
    final Float64List logBackward = Float64List((totalDays + 1) * _numPhases);
    logBackward.fillRange(0, logBackward.length, double.negativeInfinity);

    // Boundary: after day (totalDays - 1).  Any phase is equally valid
    // as a terminal phase (or pin to the logged phase if available).
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
        // Consider every possible run of the NEXT phase starting on (day + 1):
        final int following = nextPhase[phase];
        final int maxDur = min(totalDays - day, phaseDurations.maxDuration[following]);
        double logProb = double.negativeInfinity;
        for (int dur = 1; dur <= maxDur; dur++) {
          final int runEnd = day + dur; // inclusive end of the following run
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

  // ── Posterior probabilities ───────────────────────────────────────────────
  //
  // Combining forward and backward gives us three quantities:
  //
  //   phaseProbs[day * 4 + phase]
  //     The posterior probability of being in `phase` on `day`.
  //     (Computed by summing over every possible run that contains `day`.)
  //
  //   transitionProbs[day * 4 + phase]
  //     The posterior probability that `phase` ends on `day` and the next
  //     phase begins on day+1.  Values > 0.15 signal a likely boundary.
  //
  //   phaseProgress[day * 4 + phase]
  //     How far through `phase` we are on `day`, as a fraction in [0, 1].
  //     0 = first day of the phase run, 1 = last day.

  static ({
    Float64List phaseProbs,
    Float64List transitionProbs,
    Float64List phaseProgress,
  }) _posteriorProbabilities(
      int totalDays,
      Float64List logForward,
      Float64List logBackward,
      ({List<Vector> logPmf, List<int> maxDuration}) phaseDurations,
      List<List<int>> compatibility,) {
    final Float64List phaseProbs = Float64List(totalDays * _numPhases);
    final Float64List transitionProbs = Float64List((totalDays + 1) * _numPhases);
    final Float64List phaseProgress = Float64List(totalDays * _numPhases);

    // Phase probabilities and dwell progress.
    //
    // For each day and each phase, we sum over all possible runs of `phase`
    // that could contain `day`.  A run of duration `dur` that ends at `runEnd`
    // starts at `runEnd - dur + 1`.  Day `day` is inside such a run when
    // runEnd >= day and runEnd - dur + 1 <= day, i.e. runEnd in [day, day+dur-1].
    for (int day = 0; day < totalDays; day++) {
      for (int phase = 0; phase < _numPhases; phase++) {
        final int prev = _previousPhase(phase);
        final int maxDur = phaseDurations.maxDuration[phase];
        double logProbSum = double.negativeInfinity;
        double weightSum = 0.0;
        double weightedDurSum = 0.0;

        for (int dur = 1; dur <= maxDur; dur++) {
          // The latest day this run of duration `dur` could end while still
          // containing `day` is day + dur - 1.
          final int latestEnd = day + dur - 1;
          if (latestEnd >= totalDays) break;

          // `runEnd` is the last day of this run; it ranges from `day`
          // (run ends right here) to `latestEnd` (run starts right here).
          for (int runEnd = day; runEnd <= latestEnd; runEnd++) {
            final int runStart = runEnd - dur + 1;
            if (runStart < 0 || !_stretchCompatible(compatibility, phase, runStart, runEnd)) continue;
            final double logFwd = logForward[runStart * _numPhases + prev];
            final double logBwd = logBackward[(runEnd + 1) * _numPhases + phase];
            if (logFwd == double.negativeInfinity || logBwd == double.negativeInfinity) continue;
            final double logDurProb = phaseDurations.logPmf[phase][dur - 1];
            logProbSum = _logSumExp(logProbSum, logFwd + logDurProb + logBwd);
            final double w = exp(logFwd + logDurProb + logBwd);
            weightSum += w;
            weightedDurSum += dur * w;
          }
        }

        phaseProbs[day * _numPhases + phase] = logProbSum;

        // Expected duration position normalised to [0, 1].
        final int durationRange = max(1, maxDur - 1);
        phaseProgress[day * _numPhases + phase] = weightSum > 0.0
            ? ((weightedDurSum / weightSum) - 1.0) / durationRange
            : 0.5;
      }

      // Normalise phaseProbs for this day so they sum to 1.
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

    // Transition probabilities.
    //
    // transitionProbs[day * 4 + phase] = probability that `phase` ends on
    // `day` and the next phase starts on day+1.  This is computed by
    // considering all runs of the NEXT phase that could start on day+1.
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

  // ── Bayesian network table ────────────────────────────────────────────────
  //
  // For every combination of (previousPhase, currentPhase, previousFlow) we
  // ask the Bayesian network: "What distributions do you predict for flow,
  // discharge, stress, sleep, sex, symptoms, and moods?"
  //
  // The results are stored in a map keyed by _networkKey(prevPhase, phase, prevFlow).
  // This table is built once per month() call on the main thread while the
  // isolate runs the forward-backward pass.

  static String _networkKey(int prevPhase, int phase, int prevFlow) =>
      '$prevPhase,$phase,$prevFlow';

  static Map<String, _PredictedFields> _buildNetworkTable(BayesAnalyser analyser) {
    final List<String> questions = [];
    final Map<String, (int, int, int, String)> questionMeta = {};

    for (int prevPhase = 0; prevPhase < _numPhases; prevPhase++) {
      for (int prevFlow = 0; prevFlow < Flow.values.length; prevFlow++) {
        final int phase = _nextPhase(prevPhase);
        final String context = 'PHASE=${Phase.values[phase].name.toUpperCase()}, '
            'PREV_PHASE=${Phase.values[prevPhase].name.toUpperCase()}, '
            'PREV_FLOW=${Flow.values[prevFlow].name.toUpperCase()}';

        void ask(Enum value, String field) {
          final String q = 'P(${field.toUpperCase()}=${value.name.toUpperCase()}|$context)';
          questions.add(q);
          questionMeta[q] = (prevPhase, phase, prevFlow, '${field.toLowerCase()}:${(value as dynamic).index}');
        }
        void askBool(Enum value, String field) {
          final String q = 'P(${field.toUpperCase()}_${value.name.toUpperCase()}=TRUE|$context)';
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

    final Map<String, Map<String, Map<int, double>>> raw = {};
    for (final a in answers) {
      final meta = questionMeta[a.originalQuery];
      if (meta == null) continue;
      final (int prevPhase, int phase, int prevFlow, String tag) = meta;
      final String key = _networkKey(prevPhase, phase, prevFlow);
      raw.putIfAbsent(key, () => {});
      final List<String> parts = tag.split(':');
      raw[key]!.putIfAbsent(parts[0], () => {})[int.parse(parts[1])] = a.probability;
    }

    return {
      for (final entry in raw.entries)
        entry.key: (
          flow: _normalizedVector(entry.value['flow'] ?? {}, Flow.values.length),
          discharge: _normalizedVector(entry.value['discharge'] ?? {}, Discharge.values.length),
          stress: _normalizedVector(entry.value['stress'] ?? {}, Stress.values.length),
          sleep: _normalizedVector(entry.value['sleep'] ?? {}, Sleep.values.length),
          sex: _normalizedVector(entry.value['sex'] ?? {}, Sex.values.length),
          symptoms: _probabilityVector(entry.value['symptom'] ?? {}, Symptom.values.length),
          moods: _probabilityVector(entry.value['mood'] ?? {}, Mood.values.length),
        ),
    };
  }

  // ── Month predictions ─────────────────────────────────────────────────────
  //
  // Build a QuantumLog for each day in the month:
  //   • Logged days are returned as-is (converted to QuantumLog).
  //   • Unlogged days use phaseProbs to weight the Bayesian network
  //     predictions, then apply two refinements:
  //       1. Transition blending: on days where a phase boundary is likely
  //          (transitionProbs > 0.15), blend in the incoming-phase profile.
  //       2. Flow attenuation: as the period phase progresses, heavy-flow
  //          probabilities are gradually reduced.

  static List<QuantumLog> _buildPredictions({
    required DateTime windowStart,
    required DateTime monthStart,
    required DateTime monthEnd,
    required Map<int, Log> loggedDays,
    required Float64List phaseProbs,
    required Float64List transitionProbs,
    required Float64List phaseProgress,
    required Map<String, _PredictedFields> networkTable,
    required double cycleLength,
  }) {
    final List<QuantumLog> result = [];
    final int daysInMonth = monthEnd.difference(monthStart).inDays + 1;
    final int monthStartDay = monthStart.difference(windowStart).inDays;

    // Precompute: for each day offset, the nearest preceding logged day.
    // Used to estimate cycle day for unlogged days in O(1) instead of O(T).
    final int scanEnd = monthStartDay + daysInMonth;
    int? lastLoggedDay;
    final List<int> nearestPrecedingLog = List<int>.filled(scanEnd, -1);
    for (int day = 0; day < scanEnd; day++) {
      if (loggedDays.containsKey(day)) lastLoggedDay = day;
      nearestPrecedingLog[day] = lastLoggedDay ?? -1;
    }

    final int flowCount = Flow.values.length;

    // We track the probability distribution over previous-day flow values
    // instead of committing to a single flow value.  This avoids compounding
    // errors when flow predictions are uncertain.
    // On logged days this collapses to a one-hot vector.
    final Float64List prevFlowDist = Float64List(flowCount)
      ..fillRange(0, flowCount, 1.0 / flowCount);

    for (int mi = 0; mi < daysInMonth; mi++) {
      final int day = monthStartDay + mi;
      final DateTime date = monthStart.add(Duration(days: mi));

      final Log? logged = loggedDays[day];
      if (logged != null) {
        result.add(QuantumLog.fromLog(logged));
        prevFlowDist.fillRange(0, flowCount, 0.0);
        prevFlowDist[logged.flow.index] = 1.0;
        continue;
      }

      final Phase mostLikelyPhase = _mostLikelyPhase(phaseProbs, day);

      // Estimate which day of the cycle this is, counting from the nearest
      // preceding logged day.
      final int prevLogDay = nearestPrecedingLog[day];
      final int cycleDay = prevLogDay >= 0
          ? KalmanFilter().predictCycleDay(date, loggedDays[prevLogDay]!)
          : (day + 1).clamp(1, cycleLength.round());

      // Accumulate weighted field predictions over all phases × all previous
      // flow values.  Each (phase, prevFlow) pair contributes with weight
      // phaseProbs[phase] × prevFlowDist[prevFlow].
      Vector flowDist = Vector.zero(flowCount, dtype: DType.float64);
      Vector dischargeDist = Vector.zero(Discharge.values.length, dtype: DType.float64);
      Vector stressDist = Vector.zero(Stress.values.length, dtype: DType.float64);
      Vector sleepDist = Vector.zero(Sleep.values.length, dtype: DType.float64);
      Vector sexDist = Vector.zero(Sex.values.length, dtype: DType.float64);
      Vector symptomDist = Vector.zero(Symptom.values.length, dtype: DType.float64);
      Vector moodDist = Vector.zero(Mood.values.length, dtype: DType.float64);

      for (int phase = 0; phase < _numPhases; phase++) {
        final double phaseWeight = phaseProbs[day * _numPhases + phase];
        if (phaseWeight < 1e-9) continue;
        final int prev = _previousPhase(phase);
        for (int pf = 0; pf < flowCount; pf++) {
          final double prevFlowWeight = prevFlowDist[pf];
          if (prevFlowWeight < 1e-9) continue;
          final _PredictedFields? prediction = networkTable[_networkKey(prev, phase, pf)];
          if (prediction == null) continue;
          final double weight = phaseWeight * prevFlowWeight;
          flowDist = flowDist + prediction.flow * weight;
          dischargeDist = dischargeDist + prediction.discharge * weight;
          stressDist = stressDist + prediction.stress * weight;
          sleepDist = sleepDist + prediction.sleep * weight;
          sexDist = sexDist + prediction.sex * weight;
          symptomDist = symptomDist + prediction.symptoms * weight;
          moodDist = moodDist + prediction.moods * weight;
        }
      }

      // Refinement 1: if a phase transition is likely today (probability > 15%),
      // blend in the field profile of the incoming phase so the prediction
      // smoothly bridges the two phases rather than switching abruptly.
      for (int phase = 0; phase < _numPhases; phase++) {
        final double transitionWeight = transitionProbs[day * _numPhases + phase];
        if (transitionWeight < 0.15) continue;
        final int following = _nextPhase(phase);
        final _PredictedFields? incoming = networkTable[_networkKey(phase, following, Flow.none.index)];
        if (incoming == null) continue;
        flowDist = flowDist + incoming.flow * transitionWeight;
        dischargeDist = dischargeDist + incoming.discharge * transitionWeight;
        stressDist = stressDist + incoming.stress * transitionWeight;
        sleepDist = sleepDist + incoming.sleep * transitionWeight;
        sexDist = sexDist + incoming.sex * transitionWeight;
        symptomDist = symptomDist + incoming.symptoms * transitionWeight;
        moodDist = moodDist + incoming.moods * transitionWeight;
      }

      // Refinement 2: as the period phase progresses, heavy flow becomes less
      // likely — scale down heavy-flow probabilities proportionally.
      final double periodProb = phaseProbs[day * _numPhases + _period];
      if (periodProb > 1e-9) {
        final double progress = phaseProgress[day * _numPhases + _period].clamp(0.0, 1.0);
        final List<double> attenuated = List<double>.generate(flowCount, (fi) {
          final double heaviness = fi / (flowCount - 1.0);
          return (flowDist[fi] * (1.0 - progress * heaviness * 0.6)).clamp(0.0, double.maxFinite);
        });
        flowDist = Vector.fromList(attenuated, dtype: DType.float64);
      }

      // Roll the flow distribution forward: tomorrow's "previous flow" is
      // today's predicted flow distribution.
      final double flowTotal = flowDist.sum();
      for (int i = 0; i < flowCount; i++) {
        prevFlowDist[i] = flowTotal > 1e-9 ? flowDist[i] / flowTotal : 1.0 / flowCount;
      }

      result.add(QuantumLog(
        date: date,
        cycleDay: cycleDay,
        phase: mostLikelyPhase,
        flow: _toNormalizedMap(flowDist, Flow.values),
        discharge: _toNormalizedMap(dischargeDist, Discharge.values),
        stress: _toNormalizedMap(stressDist, Stress.values),
        sleep: _toNormalizedMap(sleepDist, Sleep.values),
        sex: _toNormalizedMap(sexDist, Sex.values),
        symptoms: _toClampedMap(symptomDist, Symptom.values),
        moods: _toClampedMap(moodDist, Mood.values),
      ));
    }

    return result;
  }

  // ── Small utilities ───────────────────────────────────────────────────────

  // Phases always cycle in order: period → follicular → ovulatory → luteal → period → …
  static int _nextPhase(int phase) => (phase + 1) % _numPhases;
  static int _previousPhase(int phase) => (phase + _numPhases - 1) % _numPhases;

  // Numerically stable log(exp(a) + exp(b)).
  static double _logSumExp(double a, double b) {
    if (a == double.negativeInfinity) return b;
    if (b == double.negativeInfinity) return a;
    return a > b ? a + log(1.0 + exp(b - a)) : b + log(1.0 + exp(a - b));
  }

  // Walk backwards (or forwards) from `anchor` until we hit a logged day or
  // exhaust `maxDays`.  Used to find window boundaries.
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
    final Vector vec = Vector.fromList(v, dtype: DType.float64);
    final double s = vec.sum();
    if (s == 0.0) return List<double>.filled(v.length, 1.0 / v.length);
    return (vec / s).toList();
  }

  static Vector _normalizedVector(Map<int, double> raw, int count) {
    final Vector v = Vector.fromList(
      [for (int i = 0; i < count; i++) raw[i] ?? 0.0],
      dtype: DType.float64,
    );
    final double s = v.sum();
    return s == 0.0 ? Vector.filled(count, 1.0 / count, dtype: DType.float64) : v / s;
  }

  static Vector _probabilityVector(Map<int, double> raw, int count) =>
      Vector.fromList(
        [for (int i = 0; i < count; i++) raw[i] ?? 0.5],
        dtype: DType.float64,
      );

  static Map<T, double> _toNormalizedMap<T extends Enum>(Vector acc, List<T> values) {
    final double s = acc.sum();
    final Vector v = s < 1e-9
        ? Vector.filled(values.length, 1.0 / values.length, dtype: DType.float64)
        : acc / s;
    return {for (final e in values) e: v[e.index]};
  }

  static Map<T, double> _toClampedMap<T extends Enum>(Vector acc, List<T> values) =>
      {for (final e in values) e: acc[e.index].clamp(0.0, 1.0)};
}
