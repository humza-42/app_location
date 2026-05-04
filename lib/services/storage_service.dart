import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_data.dart';

class StorageService {
  static const String _keySavedLocations = 'saved_locations';

  Future<List<LocationData>> getSavedLocations() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedLocationsJson = prefs.getStringList(_keySavedLocations) ?? [];

    return savedLocationsJson
        .map((json) => LocationData.fromJson(json))
        .toList();
  }

  Future<void> saveLocation(LocationData location) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedLocations = prefs.getStringList(_keySavedLocations) ?? [];

    savedLocations.add(location.toJson());
    await prefs.setStringList(_keySavedLocations, savedLocations);
  }

  Future<void> deleteLocation(int index) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedLocations = prefs.getStringList(_keySavedLocations) ?? [];

    if (index < savedLocations.length) {
      savedLocations.removeAt(index);
      await prefs.setStringList(_keySavedLocations, savedLocations);
    }
  }

  Future<void> deleteAllLocations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySavedLocations);
  }
}
