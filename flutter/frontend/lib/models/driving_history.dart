class DrivingHistory {
  final int id;
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
      id: json['id'] ?? 0,
      startLocation: json['start_location'] ?? '',
      endLocation: json['end_location'] ?? '',
      distance: (json['distance'] ?? 0).toDouble(),
      duration: json['duration'] ?? 0,
      date: DateTime.parse(json['date']),
    );
  }
}
