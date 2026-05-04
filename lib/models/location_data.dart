import 'dart:convert';

class LocationData {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  Map<String, String> toMap() {
    return {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory LocationData.fromMap(Map<String, String> map) {
    return LocationData(
      latitude: double.tryParse(map['latitude'] ?? '0') ?? 0.0,
      longitude: double.tryParse(map['longitude'] ?? '0') ?? 0.0,
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory LocationData.fromJson(String json) {
    final dynamicMap = jsonDecode(json) as Map<String, dynamic>;
    final stringMap = dynamicMap.map(
      (key, value) => MapEntry(key, value.toString()),
    );
    return LocationData.fromMap(stringMap);
  }
}
