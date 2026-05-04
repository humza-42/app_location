import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/location_data.dart';
import '../services/storage_service.dart';

// Global notification plugin for background isolate
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<bool> onLocationUpdate(ServiceInstance service) async {
  const locationInterval = Duration(seconds: 30);

  Timer.periodic(locationInterval, (timer) async {
    try {
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        );
      } catch (e) {
        return;
      }

      if (position.accuracy > 100) {
        return;
      }

      final locationData = LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
      );

      try {
        final storage = StorageService();
        await storage.saveLocation(locationData);
      } catch (e) {
        // Storage error - ignore to keep service alive
      }

      // Update notification
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          final now = DateTime.now();
          final timeStr =
              '${now.hour}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

          await flutterLocalNotificationsPlugin.show(
            1000,
            'Location Tracker',
            'Last update: $timeStr',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'location_tracking_channel',
                'Location Tracking',
                importance: Importance.low,
                priority: Priority.low,
                ongoing: true,
                autoCancel: false,
                icon: '@mipmap/ic_launcher',
              ),
            ),
          );
        }
      }
    } catch (e) {
      // Silent fail
    }
    });

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    return true;
  }

class BackgroundLocationService {
  static final BackgroundLocationService _instance =
      BackgroundLocationService._internal();
  factory BackgroundLocationService() => _instance;
  BackgroundLocationService._internal();

  final FlutterBackgroundService _service = FlutterBackgroundService();

  Future<void> initialize() async {
    // Create notification channel for Android (required for foreground service)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'location_tracking_channel',
      'Location Tracking',
      importance: Importance.low,
    );

    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onLocationUpdate,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'location_tracking_channel',
        initialNotificationTitle: 'Location Tracker',
        initialNotificationContent: 'Tracking location in background',
        foregroundServiceNotificationId: 1000,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onLocationUpdate,
        onBackground: onLocationUpdate,
      ),
    );
  }

  Future<bool> start() async {
    if (await _service.isRunning()) return true;

    // Request notification permission (Android 13+)
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    if (!await Permission.notification.isGranted) {
      throw Exception(
        'Notification permission is required for background location tracking on Android 13+. Please grant notification permission.',
      );
    }

    // Check location permission
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      throw Exception(
        'Location permission permanently denied. Please enable in app settings.',
      );
    }

    // Check for background location permission (Android 10+)
    if (permission == LocationPermission.whileInUse) {
      await Geolocator.openAppSettings();
      throw Exception(
        'Background location permission required. Please open app settings and select "Allow all the time" for location access.',
      );
    }

    // Start the service
    await _service.startService();

    return true;
  }

  Future<void> stop() async {
    _service.invoke('stopService');
  }

  Future<bool> isRunning() async {
    return await _service.isRunning();
  }
}
