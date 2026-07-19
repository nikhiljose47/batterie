import 'package:geolocator/geolocator.dart';

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
}
