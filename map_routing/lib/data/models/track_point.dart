class TrackPoint {
  const TrackPoint({
    required this.latitude,
    required this.longitude,
    this.time,
    this.elevation,
  });

  final double latitude;
  final double longitude;
  final DateTime? time;
  final double? elevation;
}
