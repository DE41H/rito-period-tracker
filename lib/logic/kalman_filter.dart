import 'package:buritto/hive/hive_database.dart';

class KalmanFilter {
  static final KalmanFilter _instance = KalmanFilter._internal();
  factory KalmanFilter() => _instance;
  KalmanFilter._internal();

  double? _estimatedLength = HiveDatabase().statistics;
  double? _errorCovariance;
  double? _processNoise;
  double? _measurementNoise;

  void init() {
    if ({_estimatedLength, _errorCovariance, _processNoise, _measurementNoise}.contains(null)) {

    }
  }

  void update(double cycleLength) {
    _errorCovariance = _errorCovariance! + _processNoise!;
    final double gain = _errorCovariance!  / (_errorCovariance! + _measurementNoise!);
    _estimatedLength = _estimatedLength! + gain * (cycleLength - _estimatedLength!);
    _errorCovariance = _errorCovariance! * (1.0 - gain);
  }

  double get estimatedLength => _estimatedLength;
}