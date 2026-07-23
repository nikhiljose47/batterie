import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/weather.dart';

/// Thrown when we cannot obtain the user's location. The UI decides how to
/// present the failure — a "grant permission" CTA, a retry, or a fallback.
class LocationException implements Exception {
  const LocationException(this.kind, [this.message]);

  final LocationExceptionKind kind;
  final String? message;

  @override
  String toString() => 'LocationException($kind): ${message ?? kind.name}';
}

enum LocationExceptionKind {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unknown,
}

/// Wraps Geolocator so the repository never has to touch the plugin directly.
class LocationService {
  const LocationService();

  /// Resolves the device's current lat/lon, prompting for permission if
  /// needed. Throws [LocationException] on any failure so the caller can
  /// branch on [LocationExceptionKind].
  Future<UserLocation> currentLocation({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(
        LocationExceptionKind.serviceDisabled,
        'Location services are off on this device.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        LocationExceptionKind.permissionDeniedForever,
        'Location permission was permanently denied.',
      );
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(
        LocationExceptionKind.permissionDenied,
        'Location permission was denied.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: timeout,
        ),
      );
      return UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on LocationServiceDisabledException {
      throw const LocationException(LocationExceptionKind.serviceDisabled);
    } on PermissionDeniedException {
      throw const LocationException(LocationExceptionKind.permissionDenied);
    } catch (e) {
      throw LocationException(LocationExceptionKind.unknown, e.toString());
    }
  }

  /// Returns a friendly label like "Bangalore, IN" for a lat/lon pair.
  /// Uses the Nominatim free reverse geocoding API. Throws on any failure —
  /// callers should swallow the error and treat place name as optional.
  Future<String?> reverseGeocode(UserLocation location) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', <String, String>{
      'lat': location.latitude.toString(),
      'lon': location.longitude.toString(),
      'format': 'json',
      'zoom': '10', // city-level resolution
      'addressdetails': '1',
    });

    final response = await http.get(
      uri,
      headers: <String, String>{'User-Agent': 'batterie-app/1.0'},
    ).timeout(const Duration(seconds: 6));

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final address = data['address'] as Map<String, dynamic>?;
    if (address == null) return null;

    final city = (address['city'] ??
            address['town'] ??
            address['village'] ??
            address['county']) as String?;
    final country = address['country_code'] as String?;

    if (city == null) return null;
    if (country == null) return city;
    return '$city, ${country.toUpperCase()}';
  }
}
