import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

final gpsServiceProvider = Provider((ref) => GpsService());

class GpsService {
  StreamSubscription<Position>? _positionSub;
  bool _isRunning = false;
  static const String _prefKey = 'gps_tracking';

  bool get isRunning => _isRunning;

  Future<bool> getSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  Future<void> setSavedState(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  Future<void> start({
    required String token,
    required String busId,
    required ApiService apiService,
  }) async {
    if (_isRunning) return;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    _isRunning = true;
    await setSavedState(true);
    await NotificationService.showGpsNotification();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) async {
      try {
        await apiService.pushGps(
          token,
          lat: position.latitude,
          lon: position.longitude,
          speed: position.speed * 3.6, // m/s → km/h
          heading: position.heading,
        );
      } catch (_) {}
    });
  }

  Future<void> stop() async {
    _isRunning = false;
    await setSavedState(false);
    await _positionSub?.cancel();
    _positionSub = null;
    await NotificationService.cancelGpsNotification();
  }
}
