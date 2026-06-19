class TrackPoint {
  const TrackPoint({
    required this.latitude,
    required this.longitude,
    this.time,
    this.elevation,
    this.heartRate,
  });

  final double latitude;
  final double longitude;
  final DateTime? time;
  final double? elevation;
  final int? heartRate;
}
