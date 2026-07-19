import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather.dart';

class WeatherServiceException implements Exception {
  const WeatherServiceException(this.message);
  final String message;

  @override
  String toString() => 'WeatherServiceException: $message';
}

/// Thin client for the free Open-Meteo forecast endpoint.
///
/// Docs: https://open-meteo.com/en/docs — no API key needed.
class WeatherService {
  const WeatherService({http.Client? client}) : _client = client;

  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  final http.Client? _client;

  http.Client get _http => _client ?? http.Client();

  /// Fetches current conditions + hourly (next ~48 h) + a 7-day daily
  /// forecast for [location].
  /// Throws [WeatherServiceException] on network / parsing errors.
  Future<
      ({
        CurrentWeather current,
        List<DailyForecast> daily,
        List<HourlyForecast> hourly,
      })> fetchForLocation(
    UserLocation location, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: <String, String>{
      'latitude': location.latitude.toStringAsFixed(4),
      'longitude': location.longitude.toStringAsFixed(4),
      'current':
          'temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day',
      'hourly': 'temperature_2m,weather_code,precipitation_probability',
      'daily':
          'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max',
      'timezone': 'auto',
      'wind_speed_unit': 'kmh',
      'forecast_days': '7',
    });

    late final http.Response response;
    try {
      response = await _http.get(uri).timeout(timeout);
    } catch (e) {
      throw WeatherServiceException('Network error: $e');
    }

    if (response.statusCode != 200) {
      throw WeatherServiceException(
        'Open-Meteo returned HTTP ${response.statusCode}',
      );
    }

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final current = _parseCurrent(json);
      final daily = _parseDaily(json);
      final hourly = _parseHourly(json);
      return (current: current, daily: daily, hourly: hourly);
    } catch (e) {
      throw WeatherServiceException('Bad response from Open-Meteo: $e');
    }
  }

  CurrentWeather _parseCurrent(Map<String, dynamic> json) {
    final c = json['current'] as Map<String, dynamic>;
    return CurrentWeather(
      temperatureC: (c['temperature_2m'] as num).toDouble(),
      apparentTemperatureC:
          (c['apparent_temperature'] as num).toDouble(),
      humidityPercent: (c['relative_humidity_2m'] as num).toInt(),
      windSpeedKph: (c['wind_speed_10m'] as num).toDouble(),
      condition: WeatherCondition.fromCode((c['weather_code'] as num).toInt()),
      isDay: (c['is_day'] as num).toInt() == 1,
    );
  }

  /// First ~48 hours only — enough for "what will this slot feel like",
  /// small enough to keep the SharedPreferences cache lean.
  List<HourlyForecast> _parseHourly(Map<String, dynamic> json) {
    final h = json['hourly'] as Map<String, dynamic>?;
    if (h == null) return const <HourlyForecast>[];
    final times = (h['time'] as List<dynamic>).cast<String>();
    final temps = (h['temperature_2m'] as List<dynamic>).cast<num>();
    final codes = (h['weather_code'] as List<dynamic>).cast<num>();
    final precip =
        (h['precipitation_probability'] as List<dynamic>?)?.cast<num?>();

    final count = times.length < 48 ? times.length : 48;
    return List<HourlyForecast>.generate(count, (i) {
      return HourlyForecast(
        time: DateTime.parse(times[i]),
        temperatureC: temps[i].toDouble(),
        condition: WeatherCondition.fromCode(codes[i].toInt()),
        precipitationProbability: precip?[i]?.toInt(),
      );
    });
  }

  List<DailyForecast> _parseDaily(Map<String, dynamic> json) {
    final d = json['daily'] as Map<String, dynamic>;
    final times = (d['time'] as List<dynamic>).cast<String>();
    final codes = (d['weather_code'] as List<dynamic>).cast<num>();
    final maxes = (d['temperature_2m_max'] as List<dynamic>).cast<num>();
    final mins = (d['temperature_2m_min'] as List<dynamic>).cast<num>();
    final precip =
        (d['precipitation_probability_max'] as List<dynamic>?)?.cast<num?>();

    return List<DailyForecast>.generate(times.length, (i) {
      return DailyForecast(
        date: DateTime.parse(times[i]),
        condition: WeatherCondition.fromCode(codes[i].toInt()),
        tempMinC: mins[i].toDouble(),
        tempMaxC: maxes[i].toDouble(),
        precipitationProbability: precip?[i]?.toInt(),
      );
    });
  }
}
