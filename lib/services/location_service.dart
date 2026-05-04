import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/location_data.dart';

class LocationService {
  LocationData? _lastLocation;
  DateTime? _lastFetchTime;

  // Cache duration: 10 seconds for stationary users
  static const Duration _cacheDuration = Duration(seconds: 10);
  Future<LocationData> getCurrentLocation() async {
    try {
      // Check if we have a recent cached location
      if (_lastLocation != null && _lastFetchTime != null) {
        final timeDiff = DateTime.now().difference(_lastFetchTime!);
        if (timeDiff < _cacheDuration) {
          // Return cached location if it's still fresh (prevents flickering)
          return _lastLocation!;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      // Filter out inaccurate readings (GPS can be ±10-50m)
      // Only accept if accuracy is within 30 meters
      if (position.accuracy > 30) {
        // Try again with higher accuracy
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
        );

        // If still not accurate enough, use it anyway
      }

      // Filter out inaccurate readings (GPS can be ±10-50m)
      // Only accept if accuracy is within 30 meters
      if (position.accuracy > 30) {
        // Try again with higher accuracy
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
        );

        // If still not accurate enough, use it anyway with a warning
        if (position.accuracy > 50) {
          // Could show a toast: "Location accuracy is low"
        }
      }

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String city = 'Unknown City';
      String area = 'Unknown Area';

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        // Build city from most specific to least
        city =
            place.locality ??
            place.subAdministrativeArea ??
            place.administrativeArea ??
            'Unknown City';

        // Build pinpoint area: [name] [subThoroughfare] [thoroughfare]
        // Include business/POI name (e.g., "Bitstorm Solutions") plus street address
        List<String> areaParts = [];

        // Business/POI name
        if (place.name != null && place.name!.isNotEmpty) {
          areaParts.add(place.name!);
        }

        // House/building number
        if (place.subThoroughfare != null &&
            place.subThoroughfare!.isNotEmpty) {
          areaParts.add(place.subThoroughfare!);
        }

        // Street name
        if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) {
          areaParts.add(place.thoroughfare!);
        }

        if (areaParts.isNotEmpty) {
          area = areaParts.join(', ');
        } else if (place.street != null && place.street!.isNotEmpty) {
          area = place.street!;
        } else {
          area = 'Unknown Area';
        }
      }

      final locationData = LocationData(
        city: city,
        area: area,
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
      );

      // Cache this location
      _lastLocation = locationData;
      _lastFetchTime = DateTime.now();

      return locationData;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }
}
