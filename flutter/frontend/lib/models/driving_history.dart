class DrivingHistory {
  final String id;
  final String startLocation;
  final String endLocation;
  final double distance; // in km
  final int duration; // in minutes
  final DateTime date;

  DrivingHistory({
    required this.id,
    required this.startLocation,
    required this.endLocation,
    required this.distance,
    required this.duration,
    required this.date,
  });

  factory DrivingHistory.fromJson(Map<String, dynamic> json) {
    return DrivingHistory(
      id: json['drive_log_id']?.toString() ?? '',
      startLocation: json['start_label'] ?? json['start_location'] ?? '',
      endLocation: json['end_label'] ?? json['end_location'] ?? '',
      distance: (json['distance_km'] ?? json['distance'] ?? 0).toDouble(),
      duration: json['duration_sec'] != null
          ? (json['duration_sec'] / 60).round()
          : (json['duration'] ?? 0),
      date:
          DateTime.tryParse(json['created_at'] ?? json['date'] ?? '') ??
          DateTime.now(),
    );
  }
}
