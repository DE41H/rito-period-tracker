import 'dart:math';
import 'package:statistics/statistics.dart';

import 'package:buritto/hive/hive_database.dart';

class KalmanFilter {
  static final KalmanFilter _instance = KalmanFilter._internal();
  factory KalmanFilter() => _instance;
  KalmanFilter._internal();

  late double _estimate;
  late double _error;
  late double _processNoise;
  late double _measurementNoise;

  void init() {
    final double? estimate = HiveDatabase().statistics.get('kalmanEstimate');
    final double? error = HiveDatabase().statistics.get('kalmanError');
    final double? processNoise = HiveDatabase().statistics.get('kalmanProcessNoise');
    final double? measurementNoise = HiveDatabase().statistics.get('kalmanMeasurementNoise');
    if (estimate == null || error == null || processNoise == null || measurementNoise == null) return _reset();
    _estimate = estimate;
    _error = error;
    _processNoise = processNoise;
    _measurementNoise = measurementNoise;
  }

  void _reset() {
    final bool onBirthControl = HiveDatabase().settings.get('onBirthControl') as bool;
    if (onBirthControl) {
      _estimate = 28.0;
      _error = 0.1;
      _processNoise = 0.001;
      _measurementNoise = 1.00;
      _save();
      return;
    }

    final bool hasPcos = HiveDatabase().settings.get('hasPcos') as bool;
    if (hasPcos) {
      _estimate = 35.0;
      _error = 4.0;
      _processNoise = 4.50;
      _measurementNoise = 2.00;
      _save();
      return;
    }

    final int year = HiveDatabase().settings.get('birthYear') as int;
    final int month = HiveDatabase().settings.get('birthMonth') as int;
    final double age = DateTime.now().difference(DateTime(year, month)).inYearsAsDouble;
    _estimate = (31.0 - (0.25 * (age - 15.0))).clamp(26.8, 31.0);
    _processNoise = (0.015 * pow(age - 30, 2) + 0.15).clamp(0.15, 4.0);
    _error = (0.010 * pow(age - 30, 2) + 1.5).clamp(1.5, 4.5);
    _measurementNoise = 1.50;
    _save();
  }

  void _save() {
    HiveDatabase().statistics.putAll({
      'kalmanEstimate': _estimate,
      'kalmanError': _error,
      'kalmanProcessNoise': _processNoise,
      'kalmanMeasurementNoise': _measurementNoise,
    });
  }

  void update(double cycleLength) {
    _error = _error + _processNoise;
    final double gain = _error  / (_error + _measurementNoise);
    _estimate = _estimate + gain * (cycleLength - _estimate);
    _error = _error * (1.0 - gain);
    _save();
  }

  double get cycleLength => _estimate;
}
