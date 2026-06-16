import 'dart:math';

import 'package:buritto/hive/hive_database.dart';
import 'package:buritto/models/flow.dart';
import 'package:buritto/models/log.dart';
import 'package:buritto/models/phase.dart';
import 'package:statistics/statistics.dart';

class KalmanFilter {
  static final KalmanFilter _instance = KalmanFilter._internal();
  factory KalmanFilter() => _instance;
  KalmanFilter._internal();

  late double _cycleLength;
  double get cycleLength => _cycleLength;
  int get ovulationDay => (_cycleLength - 14).round();

  late double _periodLength;
  double get periodLength => _periodLength;

  late double _cycleError;
  late double _cycleProcessNoise;
  late double _cycleMeasurementNoise;

  late double _periodError;
  late double _periodProcessNoise;
  late double _periodMeasurementNoise;

  double? _pendingPeriod;

  void stagePeriodEnd(final double day, [final bool overwrite = true]) {
    if (overwrite) {
      _pendingPeriod = day;
    } else {
      _pendingPeriod ??= day;
    }
  }
  void flushPeriodEnd() {
    if (_pendingPeriod != null) {
      updatePeriod(_pendingPeriod!);
      _pendingPeriod = null;
    }
  }

  Future<void> init() async {
    final double? cycleLength = HiveDatabase().statistics.get('kalmanEstimate') as double?;
    final double? cycleError = HiveDatabase().statistics.get('kalmanError') as double?;
    final double? cycleProcessNoise = HiveDatabase().statistics.get('kalmanProcessNoise') as double?;
    final double? cycleMeasurementNoise = HiveDatabase().statistics.get('kalmanMeasurementNoise') as double?;
    final double? periodLength = HiveDatabase().statistics.get('kalmanPeriodEstimate') as double?;
    final double? periodError = HiveDatabase().statistics.get('kalmanPeriodError') as double?;
    final double? periodProcessNoise = HiveDatabase().statistics.get('kalmanPeriodProcessNoise') as double?;
    final double? periodMeasurementNoise = HiveDatabase().statistics.get('kalmanPeriodMeasurementNoise') as double?;
    if (cycleLength == null || cycleError == null || cycleProcessNoise == null || cycleMeasurementNoise == null || periodLength == null || periodError == null || periodProcessNoise == null || periodMeasurementNoise == null) {
      final bool pcos = HiveDatabase().settings.get('hasPcos', defaultValue: false) as bool;
      return _reset(pcos);
    }
    _cycleLength = cycleLength;
    _cycleError = cycleError;
    _cycleProcessNoise = cycleProcessNoise;
    _cycleMeasurementNoise = cycleMeasurementNoise;
    _periodLength = periodLength;
    _periodError = periodError;
    _periodProcessNoise = periodProcessNoise;
    _periodMeasurementNoise = periodMeasurementNoise;
  }

  void _reset([bool? pcos, int? year, int? month]) {
    pcos ??= HiveDatabase().settings.get('hasPcos', defaultValue: false) as bool;
    year ??= HiveDatabase().settings.get('birthYear', defaultValue: 2000) as int;
    month ??= HiveDatabase().settings.get('birthMonth', defaultValue: 1) as int;

    if (pcos) {
      _cycleLength = 35.0;
      _cycleError = 4.0;
      _cycleProcessNoise = 4.50;
      _cycleMeasurementNoise = 2.00;
      _periodLength = 6.00;
      _periodError = 2.00;
      _periodProcessNoise = 0.75;
      _periodMeasurementNoise = 1.00;
      _save();
      return;
    }

    final double age = DateTime.now().difference(DateTime(year, month)).inYearsAsDouble;
    _cycleLength = (31.0 - (0.25 * (age - 15.0))).clamp(26.8, 31.0);
    _cycleProcessNoise = (0.015 * pow(age - 30, 2) + 0.15).clamp(0.15, 4.0);
    _cycleError = (0.010 * pow(age - 30, 2) + 1.5).clamp(1.5, 4.5);
    _cycleMeasurementNoise = 1.50;
    _periodLength = (5.5 - 0.04 * (age - 15.0)).clamp(3.0, 5.5);
    _periodProcessNoise = (0.008 * pow(age - 30, 2) + 0.10).clamp(0.10, 1.50);
    _periodError = (0.006 * pow(age - 30, 2) + 0.75).clamp(0.75, 2.00);
    _periodMeasurementNoise = 0.75;
    _save();
  }

  void _save() {
    HiveDatabase().statistics.putAll({
      'kalmanEstimate': _cycleLength,
      'kalmanError': _cycleError,
      'kalmanProcessNoise': _cycleProcessNoise,
      'kalmanMeasurementNoise': _cycleMeasurementNoise,
      'kalmanPeriodEstimate': _periodLength,
      'kalmanPeriodError': _periodError,
      'kalmanPeriodProcessNoise': _periodProcessNoise,
      'kalmanPeriodMeasurementNoise': _periodMeasurementNoise,
    });
  }

  Future<void> rebuild([final bool? pcos, final int? year, final int? month]) async {
    _reset(pcos, year, month);
    _pendingPeriod = null;
    Log? last;
    await for (final log in LogRepo().all) {
      if (last != null) {
        final int elapsed = log.date.difference(last.date).inDays;
        if (last.phase == Phase.menstrual && last.flow != Flow.none) {
          if (elapsed > _periodLength * 1.5) {
            stagePeriodEnd(last.cycleDay.toDouble());
            flushPeriodEnd();
          } else if (log.flow == Flow.none) {
            stagePeriodEnd(last.cycleDay.toDouble());
          }
        }
        if (log.cycleDay == 1 && log.phase == Phase.menstrual && log.flow != Flow.none) {
          if (elapsed <= _periodLength * 1.5 && last.flow != Flow.none) {
            stagePeriodEnd(last.cycleDay.toDouble(), false);
          }
          flushPeriodEnd();
          final int rawDay = last.cycleDay + elapsed - 1;
          if (rawDay > cycleLength * 0.5 && rawDay < cycleLength * 1.5) updateCycle(rawDay);
        }
      }
      last = log;
    }
    flushPeriodEnd();
  }

  void updateCycle(int cycleLength) {
    _cycleError = _cycleError + _cycleProcessNoise;
    final double gain = _cycleError  / (_cycleError + _cycleMeasurementNoise);
    _cycleLength = _cycleLength + gain * (cycleLength - _cycleLength);
    _cycleError = _cycleError * (1.0 - gain);
    _save();
  }

  void updatePeriod(double periodLength) {
    _periodError = _periodError + _periodProcessNoise;
    final double gain = _periodError / (_periodError + _periodMeasurementNoise);
    _periodLength = _periodLength + gain * (periodLength - _periodLength);
    _periodError = _periodError * (1.0 - gain);
    _save();
  }

  Phase predictPhase(int cycleDay, [Flow flow = Flow.none]) {
    if ((flow != Flow.none && cycleDay <= (_periodLength * 1.5).ceil()) || cycleDay <= _periodLength.round()) return Phase.menstrual;
    if (cycleDay < ovulationDay - 1) return Phase.follicular;
    if (cycleDay <= ovulationDay + 1) return Phase.ovulatory;
    return Phase.luteal;
  }

  int predictCycleDay(DateTime date, Log last) {
    final int elapsed = date.difference(last.date).inDays;
    return ((last.cycleDay + elapsed - 1) % _cycleLength).floor() + 1;
  }
}
