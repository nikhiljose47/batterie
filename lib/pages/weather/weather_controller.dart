import 'package:flutter/foundation.dart';

import '../../models/weather.dart';
import '../../repositories/weather_repository.dart';
import '../../services/location_service.dart';
import '../../services/weather_service.dart';

enum WeatherStatus {
  initial,
  loading,
  refreshing, // showing cached data but re-fetching in the background
  success,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  error,
}

class WeatherState {
  const WeatherState({
    this.status = WeatherStatus.initial,
    this.snapshot,
    this.errorMessage,
  });

  final WeatherStatus status;
  final WeatherSnapshot? snapshot;
  final String? errorMessage;

  WeatherState copyWith({
    WeatherStatus? status,
    WeatherSnapshot? snapshot,
    String? errorMessage,
    bool clearError = false,
  }) {
    return WeatherState(
      status: status ?? this.status,
      snapshot: snapshot ?? this.snapshot,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Owns the weather flow: seeds from cache, requests a fresh snapshot, and
/// broadcasts state transitions to the UI.
class WeatherController extends ChangeNotifier {
  WeatherController({WeatherRepository? repository})
      : _repository = repository ?? WeatherRepository();

  final WeatherRepository _repository;

  WeatherState _state = const WeatherState();
  WeatherState get state => _state;

  /// Show whatever we've got cached, then kick off a fresh fetch.
  Future<void> load() async {
    final cached = await _repository.cachedSnapshot();
    if (cached != null) {
      _emit(_state.copyWith(
        status: WeatherStatus.refreshing,
        snapshot: cached,
        clearError: true,
      ));
    } else {
      _emit(_state.copyWith(
        status: WeatherStatus.loading,
        clearError: true,
      ));
    }
    await _fetch();
  }

  /// User-triggered pull-to-refresh: never falls back to cache silently.
  Future<void> refresh() async {
    _emit(_state.copyWith(
      status: _state.snapshot == null
          ? WeatherStatus.loading
          : WeatherStatus.refreshing,
      clearError: true,
    ));
    await _fetch();
  }

  Future<void> _fetch() async {
    try {
      final snapshot = await _repository.fetchFresh();
      _emit(WeatherState(
        status: WeatherStatus.success,
        snapshot: snapshot,
      ));
    } on LocationException catch (e) {
      final status = switch (e.kind) {
        LocationExceptionKind.permissionDenied =>
          WeatherStatus.permissionDenied,
        LocationExceptionKind.permissionDeniedForever =>
          WeatherStatus.permissionDeniedForever,
        LocationExceptionKind.serviceDisabled =>
          WeatherStatus.serviceDisabled,
        _ => WeatherStatus.error,
      };
      _emit(_state.copyWith(
        status: status,
        errorMessage: e.message,
      ));
    } on WeatherServiceException catch (e) {
      _emit(_state.copyWith(
        status: WeatherStatus.error,
        errorMessage: e.message,
      ));
    } catch (e) {
      _emit(_state.copyWith(
        status: WeatherStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void _emit(WeatherState next) {
    _state = next;
    notifyListeners();
  }
}
