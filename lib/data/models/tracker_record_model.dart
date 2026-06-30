class TrackerRecord {
  final int? id;
  final double latitude;
  final double longitude;
  final int timestamp;
  final double accuracy;

  const TrackerRecord({
    this.id,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.accuracy,
  });

  factory TrackerRecord.fromMap(Map<String, dynamic> map) {
    return TrackerRecord(
      id: map['id'] as int?,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      timestamp: map['timestamp'] as int,
      accuracy: (map['accuracy'] as num).toDouble(),
    );
  }

  /// Converts the typed object back into a Map for potential future disk writes from Dart.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
      'accuracy': accuracy,
    };
  }
}
