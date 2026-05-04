import 'dart:convert';

class LocationData {
  final String city;
  final String area;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  LocationData({
    required this.city,
    required this.area,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  Map<String, String> toMap() {
    return {
      'city': city,
      'area': area,
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory LocationData.fromMap(Map<String, String> map) {
    return LocationData(
      city: map['city'] ?? 'Unknown',
      area: map['area'] ?? 'Unknown',
      latitude: double.tryParse(map['latitude'] ?? '0') ?? 0.0,
      longitude: double.tryParse(map['longitude'] ?? '0') ?? 0.0,
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory LocationData.fromJson(String json) =>
      LocationData.fromMap(jsonDecode(json));
}
