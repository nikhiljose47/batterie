import 'package:flutter/material.dart';

/// WMO weather-code categories used by Open-Meteo. Each groups multiple raw
/// codes into a single condition our UI knows how to render.
enum WeatherCondition {
  clear,
  partlyCloudy,
  cloudy,
  fog,
  drizzle,
  rain,
  freezingRain,
  snow,
  showers,
  thunderstorm,
  unknown;

  /// Human-readable label used in the current-condition strip.
  String get label => switch (this) {
        WeatherCondition.clear => 'Clear',
        WeatherCondition.partlyCloudy => 'Partly cloudy',
        WeatherCondition.cloudy => 'Cloudy',
        WeatherCondition.fog => 'Fog',
        WeatherCondition.drizzle => 'Drizzle',
        WeatherCondition.rain => 'Rain',
        WeatherCondition.freezingRain => 'Freezing rain',
        WeatherCondition.snow => 'Snow',
        WeatherCondition.showers => 'Showers',
        WeatherCondition.thunderstorm => 'Thunderstorm',
        WeatherCondition.unknown => 'Weather',
      };

  IconData get icon => switch (this) {
        WeatherCondition.clear => Icons.wb_sunny_rounded,
        WeatherCondition.partlyCloudy => Icons.wb_cloudy_rounded,
        WeatherCondition.cloudy => Icons.cloud_rounded,
        WeatherCondition.fog => Icons.foggy,
        WeatherCondition.drizzle => Icons.grain_rounded,
        WeatherCondition.rain => Icons.water_drop_rounded,
        WeatherCondition.freezingRain => Icons.ac_unit_rounded,
        WeatherCondition.snow => Icons.ac_unit_rounded,
        WeatherCondition.showers => Icons.thunderstorm_outlined,
        WeatherCondition.thunderstorm => Icons.thunderstorm_rounded,
        WeatherCondition.unknown => Icons.help_outline_rounded,
      };

  /// Map WMO code → condition. Reference: https://open-meteo.com/en/docs
  static WeatherCondition fromCode(int? code) {
    if (code == null) return WeatherCondition.unknown;
    if (code == 0) return WeatherCondition.clear;
    if (code == 1 || code == 2) return WeatherCondition.partlyCloudy;
    if (code == 3) return WeatherCondition.cloudy;
    if (code == 45 || code == 48) return WeatherCondition.fog;
    if (code >= 51 && code <= 57) return WeatherCondition.drizzle;
    if (code == 66 || code == 67) return WeatherCondition.freezingRain;
    if (code >= 61 && code <= 65) return WeatherCondition.rain;
    if (code >= 71 && code <= 77) return WeatherCondition.snow;
    if (code >= 80 && code <= 82) return WeatherCondition.showers;
    if (code == 85 || code == 86) return WeatherCondition.snow;
    if (code >= 95 && code <= 99) return WeatherCondition.thunderstorm;
    return WeatherCondition.unknown;
  }

  String toJson() => name;
  static WeatherCondition fromJson(String? name) =>
      WeatherCondition.values.firstWhere(
        (c) => c.name == name,
        orElse: () => WeatherCondition.unknown,
      );
}

/// Result of resolving the user's device location.
class UserLocation {
  const UserLocation({
    required this.latitude,
    required this.longitude,
    this.placeLabel,
  });

  final double latitude;
  final double longitude;

  /// Optional friendly label ("Bengaluru", "Home", …). Open-Meteo doesn't
  /// resolve names, so this stays null unless we add reverse geocoding.
  final String? placeLabel;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
        if (placeLabel != null) 'placeLabel': placeLabel,
      };

  static UserLocation fromJson(Map<String, dynamic> json) => UserLocation(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        placeLabel: json['placeLabel'] as String?,
      );
}

/// Current weather snapshot.
class CurrentWeather {
  const CurrentWeather({
    required this.temperatureC,
    required this.apparentTemperatureC,
    required this.humidityPercent,
    required this.windSpeedKph,
    required this.condition,
    required this.isDay,
  });

  final double temperatureC;
  final double apparentTemperatureC;
  final int humidityPercent;
  final double windSpeedKph;
  final WeatherCondition condition;
  final bool isDay;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'temperatureC': temperatureC,
        'apparentTemperatureC': apparentTemperatureC,
        'humidityPercent': humidityPercent,
        'windSpeedKph': windSpeedKph,
        'condition': condition.toJson(),
        'isDay': isDay,
      };

  static CurrentWeather fromJson(Map<String, dynamic> json) => CurrentWeather(
        temperatureC: (json['temperatureC'] as num).toDouble(),
        apparentTemperatureC:
            (json['apparentTemperatureC'] as num).toDouble(),
        humidityPercent: (json['humidityPercent'] as num).toInt(),
        windSpeedKph: (json['windSpeedKph'] as num).toDouble(),
        condition:
            WeatherCondition.fromJson(json['condition'] as String?),
        isDay: json['isDay'] as bool? ?? true,
      );
}

/// One row in the 7-day forecast strip.
class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.condition,
    required this.tempMinC,
    required this.tempMaxC,
    required this.precipitationProbability,
  });

  final DateTime date;
  final WeatherCondition condition;
  final double tempMinC;
  final double tempMaxC;

  /// 0–100. Null if the API didn't return it.
  final int? precipitationProbability;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': date.toIso8601String(),
        'condition': condition.toJson(),
        'tempMinC': tempMinC,
        'tempMaxC': tempMaxC,
        'precipitationProbability': precipitationProbability,
      };

  static DailyForecast fromJson(Map<String, dynamic> json) => DailyForecast(
        date: DateTime.parse(json['date'] as String),
        condition:
            WeatherCondition.fromJson(json['condition'] as String?),
        tempMinC: (json['tempMinC'] as num).toDouble(),
        tempMaxC: (json['tempMaxC'] as num).toDouble(),
        precipitationProbability: json['precipitationProbability'] as int?,
      );
}

/// One hour of forecast — used to predict conditions for each planner slot.
class HourlyForecast {
  const HourlyForecast({
    required this.time,
    required this.temperatureC,
    required this.condition,
    required this.precipitationProbability,
  });

  final DateTime time;
  final double temperatureC;
  final WeatherCondition condition;

  /// 0–100. Null if the API didn't return it.
  final int? precipitationProbability;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'time': time.toIso8601String(),
        'temperatureC': temperatureC,
        'condition': condition.toJson(),
        'precipitationProbability': precipitationProbability,
      };

  static HourlyForecast fromJson(Map<String, dynamic> json) => HourlyForecast(
        time: DateTime.parse(json['time'] as String),
        temperatureC: (json['temperatureC'] as num).toDouble(),
        condition: WeatherCondition.fromJson(json['condition'] as String?),
        precipitationProbability: json['precipitationProbability'] as int?,
      );
}

/// Combined snapshot returned by the repository — current + hourly + 7-day
/// forecast + the location it was fetched for, plus when it was fetched.
class WeatherSnapshot {
  const WeatherSnapshot({
    required this.location,
    required this.current,
    required this.daily,
    required this.fetchedAt,
    this.hourly = const <HourlyForecast>[],
  });

  final UserLocation location;
  final CurrentWeather current;
  final List<DailyForecast> daily;
  final List<HourlyForecast> hourly;
  final DateTime fetchedAt;

  /// Forecast closest to [when], if we have one within ±90 minutes.
  HourlyForecast? hourlyAt(DateTime when) {
    HourlyForecast? best;
    var bestDelta = const Duration(minutes: 91);
    for (final h in hourly) {
      final delta = (h.time.difference(when)).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        best = h;
      }
    }
    return best;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'location': location.toJson(),
        'current': current.toJson(),
        'daily': daily.map((d) => d.toJson()).toList(),
        'hourly': hourly.map((h) => h.toJson()).toList(),
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  static WeatherSnapshot fromJson(Map<String, dynamic> json) => WeatherSnapshot(
        location:
            UserLocation.fromJson(json['location'] as Map<String, dynamic>),
        current: CurrentWeather.fromJson(
            json['current'] as Map<String, dynamic>),
        daily: (json['daily'] as List<dynamic>)
            .map((e) => DailyForecast.fromJson(e as Map<String, dynamic>))
            .toList(),
        hourly: (json['hourly'] as List<dynamic>? ?? const <dynamic>[])
            .map((e) => HourlyForecast.fromJson(e as Map<String, dynamic>))
            .toList(),
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      );
}
