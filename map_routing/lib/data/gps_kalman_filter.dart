/// Простой 1D Kalman для широты/долготы — сглаживает GPS без сильного отставания.
class GpsKalmanFilter {
  double? _lat;
  double? _lng;
  double _variance = 1;

  static const _processNoisePerSecondM = 0.75;

  void reset() {
    _lat = null;
    _lng = null;
    _variance = 1;
  }

  ({double latitude, double longitude}) update({
    required double latitude,
    required double longitude,
    required double accuracyM,
    double dtSeconds = 1,
  }) {
    final measurementVariance = (accuracyM * accuracyM).clamp(1.0, 2500.0);

    if (_lat == null || _lng == null) {
      _lat = latitude;
      _lng = longitude;
      _variance = measurementVariance;
      return (latitude: latitude, longitude: longitude);
    }

    final safeDt = dtSeconds.isFinite && dtSeconds > 0 ? dtSeconds : 1.0;
    _variance += _processNoisePerSecondM * _processNoisePerSecondM * safeDt;

    final gain = _variance / (_variance + measurementVariance);
    _lat = _lat! + gain * (latitude - _lat!);
    _lng = _lng! + gain * (longitude - _lng!);
    _variance = (1 - gain) * _variance;

    return (latitude: _lat!, longitude: _lng!);
  }
}
