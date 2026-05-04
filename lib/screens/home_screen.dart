import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location_data.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';
import '../widgets/location_dialogs.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final LocationService _locationService = LocationService();
  final StorageService _storageService = StorageService();

  LocationData? _currentLocation;
  String _statusMessage = 'Checking location services...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // App opened/foregrounded
        _logLocation('app open');
        break;
      case AppLifecycleState.paused:
        // App went to background
        _logLocation('app background');
        break;
      default:
        // Ignore all other states
        break;
    }
  }

  Future<void> _logLocation(String event) async {
    try {
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 15),
        );
      } catch (e) {
        // Fall back to most recently saved location
        final savedLocation = await _storageService.getMostRecentLocation();
        if (savedLocation != null) {
          final now = DateTime.now();
          developer.log(
            '[$event] Location (from storage): lat=${savedLocation.latitude.toStringAsFixed(6)}, '
            'lon=${savedLocation.longitude.toStringAsFixed(6)}, '
            'time=${now.toIso8601String()}',
            name: 'LocationTracker',
          );
          return;
        }
        rethrow;
      }

      final now = DateTime.now();
      developer.log(
        '[$event] Location: lat=${position.latitude.toStringAsFixed(6)}, '
        'lon=${position.longitude.toStringAsFixed(6)}, '
        'accuracy=${position.accuracy.toStringAsFixed(1)}m, '
        'time=${now.toIso8601String()}',
        name: 'LocationTracker',
      );
    } catch (e) {
      developer.log(
        '[$event] Failed to get location: $e',
        name: 'LocationTracker',
      );
    }
  }

  Future<void> _initializeLocation() async {
    await _checkLocationServicesAndPermissions();
  }

  Future<void> _checkLocationServicesAndPermissions() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking location services...';
    });

    bool serviceEnabled = await _locationService.isLocationServiceEnabled();
    if (!mounted) return;

    if (!serviceEnabled) {
      setState(() {
        _statusMessage = 'Location services disabled';
        _isLoading = false;
      });
      await LocationDialogs.showLocationDisabledDialog(context);
      return;
    }

    LocationPermission permission = await _locationService.checkPermission();
    if (!mounted) return;

    if (permission == LocationPermission.denied) {
      permission = await _locationService.requestPermission();
      if (!mounted) return;

      if (permission == LocationPermission.denied) {
        setState(() {
          _statusMessage = 'Location permission denied';
          _isLoading = false;
        });
        await LocationDialogs.showPermissionDeniedDialog(context);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _statusMessage = 'Location permission permanently denied';
        _isLoading = false;
      });
      await LocationDialogs.showPermissionPermanentlyDeniedDialog(context);
      return;
    }

    await _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationData location = await _locationService.getCurrentLocation();
      setState(() {
        _currentLocation = location;
        _statusMessage = 'Location fetched successfully';
        _isLoading = false;
      });
      // Log initial location on app start as 'app open'
      await _logLocation('app open');
    } catch (e) {
      setState(() {
        _statusMessage = 'Error getting location: $e';
        _isLoading = false;
      });
      developer.log(
        '[app open] Failed to get initial location: $e',
        name: 'LocationTracker',
      );
    }
  }

  Future<void> _saveCurrentLocation() async {
    if (_currentLocation == null) {
      _showSnackBar('No location to save');
      return;
    }
    try {
      await _storageService.saveLocation(_currentLocation!);
      _showSnackBar('Location saved successfully');
    } catch (e) {
      _showSnackBar('Error saving location: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _deleteAllHistory() async {
    try {
      await _storageService.deleteAllLocations();
      if (!mounted) return;
      _showSnackBar('All history deleted');
    } catch (e) {
      _showSnackBar('Error deleting history: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Location Tracker'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? _buildLoadingState()
          : RefreshIndicator(
              onRefresh: _checkLocationServicesAndPermissions,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLocationCard(),
                    const SizedBox(height: 16),
                    _buildSaveButton(),
                    const SizedBox(height: 12),
                    _buildDeleteHistoryButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(_statusMessage),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Theme.of(context).colorScheme.primary,
                  size: 30,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Current Location',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            _buildInfoRow(
              'Latitude',
              _currentLocation?.latitude.toStringAsFixed(6) ?? 'N/A',
            ),
            _buildInfoRow(
              'Longitude',
              _currentLocation?.longitude.toStringAsFixed(6) ?? 'N/A',
            ),
            _buildInfoRow(
              'Timestamp',
              _formatTimestamp(_currentLocation?.timestamp),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return 'Not available';
    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} '
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _saveCurrentLocation,
      icon: const Icon(Icons.save),
      label: const Text('Save Current Location'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _buildDeleteHistoryButton() {
    return TextButton.icon(
      onPressed: _deleteAllHistory,
      icon: const Icon(Icons.delete, color: Colors.red),
      label: const Text(
        'Delete All History',
        style: TextStyle(color: Colors.red),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}
