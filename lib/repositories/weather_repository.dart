import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';

/// Coordinates location + weather fetching, and keeps a single-slot cache in
/// SharedPreferences so the last successful snapshot survives cold starts and
/// intermittent connectivity.
class WeatherRepository {
  WeatherRepository({
    LocationService? locationService,
    WeatherService? weatherService,
    Future<SharedPreferences> Function()? preferencesLoader,
  })  : _locationService = locationService ?? const LocationService(),
        _weatherService = weatherService ?? const WeatherService(),
        _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const String _cacheKey = 'weather.snapshot.v1';

  final LocationService _locationService;
  final WeatherService _weatherService;
  final Future<SharedPreferences> Function() _preferencesLoader;

  /// Reads the last snapshot we successfully stored, if any.
  Future<WeatherSnapshot?> cachedSnapshot() async {
    try {
      final prefs = await _preferencesLoader();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      return WeatherSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // A corrupted cache should never block a fresh fetch.
      return null;
    }
  }

  /// Resolves the device location, hits Open-Meteo, and caches the result.
  /// Any [LocationException] or [WeatherServiceException] thrown by the
  /// services propagates up to the controller.
  Future<WeatherSnapshot> fetchFresh() async {
    final location = await _locationService.currentLocation();
    final result = await _weatherService.fetchForLocation(location);

    final snapshot = WeatherSnapshot(
      location: location,
      current: result.current,
      daily: result.daily,
      hourly: result.hourly,
      fetchedAt: DateTime.now(),
    );

    unawaited(_writeCache(snapshot));
    return snapshot;
  }

  Future<void> _writeCache(WeatherSnapshot snapshot) async {
    try {
      final prefs = await _preferencesLoader();
      await prefs.setString(_cacheKey, jsonEncode(snapshot.toJson()));
    } catch (_) {
      // Cache write failures should never surface to the user.
    }
  }
}
