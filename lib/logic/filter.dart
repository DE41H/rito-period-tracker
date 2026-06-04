import 'dart:math';
import 'package:statistics/statistics.dart';

import 'package:buritto/models/log.dart';
import 'package:buritto/hive/hive_database.dart';

class KalmanFilter {
  static final KalmanFilter _instance = KalmanFilter._internal();
  factory KalmanFilter() => _instance;
  KalmanFilter._internal();

  late double _cycleLength;
  late double _cycleError;
  late double _cycleProcessNoise;
  late double _cycleMeasurementNoise;
  // TODO: period length should be estimated and refined like cycle length

  Future<void> init() async {
    final double? cycleLength = HiveDatabase().statistics.get('kalmanEstimate');
    final double? cycleError = HiveDatabase().statistics.get('kalmanError');
    final double? cycleProcessNoise = HiveDatabase().statistics.get('kalmanProcessNoise');
    final double? cycleMeasurementNoise = HiveDatabase().statistics.get('kalmanMeasurementNoise');
    if (cycleLength == null || cycleError == null || cycleProcessNoise == null || cycleMeasurementNoise == null) return _reset();
    _cycleLength = cycleLength;
    _cycleError = cycleError;
    _cycleProcessNoise = cycleProcessNoise;
    _cycleMeasurementNoise = cycleMeasurementNoise;
    // TODO: period estimate should survive app restarts
  }

  void _reset() {
    final bool hasPcos = HiveDatabase().settings.get('hasPcos') as bool;
    if (hasPcos) {
      _cycleLength = 35.0;
      _cycleError = 4.0;
      _cycleProcessNoise = 4.50;
      _cycleMeasurementNoise = 2.00;
      _save();
      return;
    }

    final int year = HiveDatabase().settings.get('birthYear') as int;
    final int month = HiveDatabase().settings.get('birthMonth') as int;
    final double age = DateTime.now().difference(DateTime(year, month)).inYearsAsDouble;
    _cycleLength = (31.0 - (0.25 * (age - 15.0))).clamp(26.8, 31.0);
    _cycleProcessNoise = (0.015 * pow(age - 30, 2) + 0.15).clamp(0.15, 4.0);
    _cycleError = (0.010 * pow(age - 30, 2) + 1.5).clamp(1.5, 4.5);
    _cycleMeasurementNoise = 1.50;
    // TODO: prior for period length should vary by age and PCOS status
    _save();
  }

  void _save() {
    HiveDatabase().statistics.putAll({
      'kalmanEstimate': _cycleLength,
      'kalmanError': _cycleError,
      'kalmanProcessNoise': _cycleProcessNoise,
      'kalmanMeasurementNoise': _cycleMeasurementNoise,
      // TODO: period estimate should be persisted here
    });
  }

  void update(double cycleLength) {
    _cycleError = _cycleError + _cycleProcessNoise;
    final double gain = _cycleError  / (_cycleError + _cycleMeasurementNoise);
    _cycleLength = _cycleLength + gain * (cycleLength - _cycleLength);
    _cycleError = _cycleError * (1.0 - gain);
    _save();
  }

  // TODO: period length should be updated when flow stops being logged

  Phase predictPhase(int cycleDay, [Flow flow = Flow.none]) {
    if (flow != Flow.none) return Phase.menstrual;
    if (cycleDay <= 5) return Phase.menstrual; // TODO: 5 should come from the period length estimate
    if (cycleDay < ovulationDay - 1) return Phase.follicular;
    if (cycleDay <= ovulationDay + 1) return Phase.ovulatory;
    return Phase.luteal;
  }

  int predictCycleDay(DateTime date, Log last) {
    final int elapsed = date.difference(last.date).inDays;
    return ((last.cycleDay + elapsed - 1) % _cycleLength).floor() + 1;
  }

  double get cycleLength => _cycleLength;
  int get ovulationDay => (_cycleLength - 14).round();
}
