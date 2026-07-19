import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../constants/app_colors.dart';
import '../../../constants/app_spacing.dart';
import 'toolkit.dart';

// API-backed services — all free, keyless endpoints:
//  • Air Quality  — Open-Meteo air-quality API (reuses the app's cached
//    weather location; no extra permission prompts).
//  • Holiday Calendar — Nager.Date public holidays.
//  • Food Calorie Check — Open Food Facts search.

// ═══════════════════════════════════════════════════════════════════════
//  AIR QUALITY
// ═══════════════════════════════════════════════════════════════════════

class AirQualityPage extends StatefulWidget {
  const AirQualityPage({super.key});

  @override
  State<AirQualityPage> createState() => _AirQualityPageState();
}

class _AirQualityPageState extends State<AirQualityPage> {
  Map<String, dynamic>? _current;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Reuse the location the weather module already cached.
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('weather.snapshot.v1');
      if (raw == null) {
        throw Exception('No location yet — open the Home tab once so '
            'weather can grab your location, then retry.');
      }
      final snapshot = jsonDecode(raw) as Map<String, dynamic>;
      final location = snapshot['location'] as Map<String, dynamic>;
      final lat = (location['latitude'] as num).toDouble();
      final lon = (location['longitude'] as num).toDouble();

      final uri = Uri.https('air-quality-api.open-meteo.com',
          '/v1/air-quality', <String, String>{
        'latitude': '$lat',
        'longitude': '$lon',
        'current': 'us_aqi,pm2_5,pm10,ozone,nitrogen_dioxide',
      });
      final response =
          await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception('API error ${response.statusCode}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _current = data['current'] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e'.replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  ({String label, Color color, String advice}) _verdict(int aqi) {
    if (aqi <= 50) {
      return (
        label: 'Good',
        color: const Color(0xFF2E7D32),
        advice: 'Great air — perfect for outdoor runs and walks.'
      );
    }
    if (aqi <= 100) {
      return (
        label: 'Moderate',
        color: const Color(0xFF9E9D24),
        advice: 'Fine for most people; sensitive folks take it easy.'
      );
    }
    if (aqi <= 150) {
      return (
        label: 'Unhealthy (sensitive)',
        color: const Color(0xFFEF6C00),
        advice: 'Shorten intense outdoor workouts today.'
      );
    }
    if (aqi <= 200) {
      return (
        label: 'Unhealthy',
        color: const Color(0xFFC62828),
        advice: 'Move workouts indoors; consider a mask outside.'
      );
    }
    return (
      label: 'Hazardous',
      color: const Color(0xFF6A1B9A),
      advice: 'Stay indoors with windows closed if you can.'
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = ListView(
        padding: const EdgeInsets.all(AppSpacing.large),
        children: <Widget>[
          WhiteCard(
            child: Text(_error!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted)),
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _load, child: const Text('Retry')),
        ],
      );
    } else {
      final aqi = ((_current?['us_aqi'] as num?) ?? 0).round();
      final verdict = _verdict(aqi);
      body = ListView(
        padding: const EdgeInsets.all(AppSpacing.large),
        children: <Widget>[
          WhiteCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: <Widget>[
                Text('$aqi',
                    style: TextStyle(
                        fontSize: 46,
                        fontWeight: FontWeight.w800,
                        color: verdict.color,
                        height: 1.0)),
                Text('US AQI · ${verdict.label}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: verdict.color)),
                const SizedBox(height: 8),
                Text(verdict.advice,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const SectionLabel('Breakdown'),
          Row(
            children: <Widget>[
              _PollutantCard(
                  label: 'PM2.5',
                  value: (_current?['pm2_5'] as num?)?.toDouble()),
              const SizedBox(width: 8),
              _PollutantCard(
                  label: 'PM10',
                  value: (_current?['pm10'] as num?)?.toDouble()),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              _PollutantCard(
                  label: 'Ozone',
                  value: (_current?['ozone'] as num?)?.toDouble()),
              const SizedBox(width: 8),
              _PollutantCard(
                  label: 'NO₂',
                  value: (_current?['nitrogen_dioxide'] as num?)
                      ?.toDouble()),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Refresh', style: TextStyle(fontSize: 12)),
          ),
        ],
      );
    }

    return Scaffold(appBar: svcAppBar('🌫️ Air Quality'), body: body);
  }
}

class _PollutantCard extends StatelessWidget {
  const _PollutantCard({required this.label, required this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: WhiteCard(
        child: Column(
          children: <Widget>[
            Text(value == null ? '—' : value!.toStringAsFixed(1),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            Text('$label µg/m³',
                style: const TextStyle(
                    fontSize: 9.5, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  HOLIDAY CALENDAR
// ═══════════════════════════════════════════════════════════════════════

const List<(String, String)> _countries = <(String, String)>[
  ('IN', '🇮🇳 India'),
  ('US', '🇺🇸 USA'),
  ('GB', '🇬🇧 UK'),
  ('AE', '🇦🇪 UAE'),
  ('SG', '🇸🇬 Singapore'),
  ('AU', '🇦🇺 Australia'),
];

class HolidaysPage extends StatefulWidget {
  const HolidaysPage({super.key});

  @override
  State<HolidaysPage> createState() => _HolidaysPageState();
}

class _HolidaysPageState extends State<HolidaysPage> {
  String _country = 'IN';
  List<Map<String, dynamic>> _holidays = <Map<String, dynamic>>[];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final settings = await ServiceStore.loadMap('svc.holidays.settings');
    _country = settings['country'] as String? ?? 'IN';
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final year = DateTime.now().year;
      final uri =
          Uri.https('date.nager.at', '/api/v3/PublicHolidays/$year/$_country');
      final response =
          await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception('API error ${response.statusCode}');
      }
      final data = (jsonDecode(response.body) as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _holidays = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load holidays — check the internet '
            'connection and retry.';
        _loading = false;
      });
    }
  }

  Future<void> _setCountry(String code) async {
    setState(() => _country = code);
    await ServiceStore.saveMap(
        'svc.holidays.settings', <String, dynamic>{'country': code});
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final upcoming = _holidays.where((h) {
      final d = DateTime.tryParse(h['date'] as String? ?? '');
      return d != null && !d.isBefore(DateTime(today.year, today.month, today.day));
    }).toList();
    final past = _holidays.where((h) {
      final d = DateTime.tryParse(h['date'] as String? ?? '');
      return d != null && d.isBefore(DateTime(today.year, today.month, today.day));
    }).toList();

    return Scaffold(
      appBar: svcAppBar('🎉 Holiday Calendar'),
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.large, 10, AppSpacing.large, 0),
              children: <Widget>[
                for (final (code, label) in _countries)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: SvcChip(
                      label: label,
                      selected: _country == code,
                      onTap: () => _setCountry(code),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.large),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(_error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted)),
                              const SizedBox(height: 8),
                              OutlinedButton(
                                  onPressed: _load,
                                  child: const Text('Retry')),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(AppSpacing.large),
                        children: <Widget>[
                          if (upcoming.isNotEmpty) ...<Widget>[
                            _NextHolidayCard(holiday: upcoming.first),
                            const SectionLabel('Coming up'),
                            for (final h in upcoming.skip(1))
                              _HolidayTile(holiday: h),
                          ],
                          if (upcoming.isEmpty)
                            const EmptyHint(
                                'No more holidays this year — hang in '
                                'there!'),
                          if (past.isNotEmpty) ...<Widget>[
                            const SectionLabel('Earlier this year'),
                            for (final h in past.reversed.take(10))
                              _HolidayTile(holiday: h, dimmed: true),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _NextHolidayCard extends StatelessWidget {
  const _NextHolidayCard({required this.holiday});
  final Map<String, dynamic> holiday;

  @override
  Widget build(BuildContext context) {
    final d = DateTime.tryParse(holiday['date'] as String? ?? '');
    final days = d == null
        ? 0
        : d
            .difference(DateTime(DateTime.now().year, DateTime.now().month,
                DateTime.now().day))
            .inDays;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFF9A825).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            days == 0 ? '🎉 TODAY!' : '🎉 NEXT · in $days days',
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: Color(0xFFF57F17)),
          ),
          const SizedBox(height: 4),
          Text(holiday['localName'] as String? ?? '',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800)),
          Text(
            d == null ? '' : svcDayLabel(svcDay(d)),
            style:
                const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _HolidayTile extends StatelessWidget {
  const _HolidayTile({required this.holiday, this.dimmed = false});
  final Map<String, dynamic> holiday;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final d = DateTime.tryParse(holiday['date'] as String? ?? '');
    final isLongWeekend =
        d != null && (d.weekday == DateTime.friday || d.weekday == DateTime.monday);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Opacity(
        opacity: dimmed ? 0.55 : 1,
        child: WhiteCard(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 88,
                child: Text(
                  d == null ? '' : svcDayLabel(svcDay(d)),
                  style: const TextStyle(
                      fontSize: 10.5, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: Text(holiday['localName'] as String? ?? '',
                    style: const TextStyle(fontSize: 12)),
              ),
              if (isLongWeekend && !dimmed)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('long wknd 🏖️',
                      style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2E7D32))),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  FOOD CALORIE CHECK (Open Food Facts)
// ═══════════════════════════════════════════════════════════════════════

class FoodDbPage extends StatefulWidget {
  const FoodDbPage({super.key});

  @override
  State<FoodDbPage> createState() => _FoodDbPageState();
}

class _FoodDbPageState extends State<FoodDbPage> {
  final TextEditingController _query = TextEditingController();
  List<Map<String, dynamic>> _results = <Map<String, dynamic>>[];
  bool _loading = false;
  String? _message = 'Search any food — "dal", "paneer", "oats"…';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final uri = Uri.https(
          'world.openfoodfacts.org', '/cgi/search.pl', <String, String>{
        'search_terms': q,
        'search_simple': '1',
        'action': 'process',
        'json': '1',
        'page_size': '20',
        'fields': 'product_name,brands,nutriments',
      });
      final response =
          await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('API error ${response.statusCode}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final products = ((data['products'] as List<dynamic>?) ?? <dynamic>[])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((p) =>
              (p['product_name'] as String?)?.trim().isNotEmpty == true &&
              (p['nutriments'] as Map?)?['energy-kcal_100g'] != null)
          .toList();
      if (!mounted) return;
      setState(() {
        _results = products;
        _loading = false;
        if (products.isEmpty) _message = 'Nothing found for "$q".';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Search failed — check the connection and retry.';
      });
    }
  }

  Future<void> _addToCounter(Map<String, dynamic> product) async {
    final n = (product['nutriments'] as Map?) ?? <String, dynamic>{};
    final kcal = ((n['energy-kcal_100g'] as num?) ?? 0).round();
    final entries = await ServiceStore.loadList('svc.food.entries');
    entries.insert(0, <String, dynamic>{
      't': DateTime.now().toIso8601String(),
      'name': '${product['product_name']} (100 g)',
      'kcal': kcal,
      if (n['proteins_100g'] != null)
        'p': ((n['proteins_100g'] as num).toDouble()).round(),
      if (n['carbohydrates_100g'] != null)
        'c': ((n['carbohydrates_100g'] as num).toDouble()).round(),
      if (n['fat_100g'] != null)
        'f': ((n['fat_100g'] as num).toDouble()).round(),
    });
    await ServiceStore.saveList('svc.food.entries', entries);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Added 100 g to your Calorie Counter.'),
          duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: svcAppBar('🔍 Food Calorie Check'),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.large, AppSpacing.medium, AppSpacing.large, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _query,
                      onSubmitted: (_) => _search(),
                      style: const TextStyle(fontSize: 12.5),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search foods…',
                        hintStyle: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted
                                .withValues(alpha: 0.8)),
                        prefixIcon: const Icon(Icons.search_rounded,
                            size: 18, color: AppColors.textMuted),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.zero,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: AppColors.outline
                                  .withValues(alpha: 0.9)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 1.2),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _search,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(60, 38),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Go',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _message != null
                    ? EmptyHint(_message!)
                    : ListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.large),
                        itemCount: _results.length,
                        itemBuilder: (context, i) {
                          final p = _results[i];
                          final n = (p['nutriments'] as Map?) ??
                              <String, dynamic>{};
                          final kcal =
                              ((n['energy-kcal_100g'] as num?) ?? 0)
                                  .round();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: WhiteCard(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          p['product_name'] as String? ??
                                              '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight:
                                                  FontWeight.w600),
                                        ),
                                        Text(
                                          'per 100 g · P ${_g(n, 'proteins_100g')} · C ${_g(n, 'carbohydrates_100g')} · F ${_g(n, 'fat_100g')}',
                                          style: const TextStyle(
                                              fontSize: 9.5,
                                              color:
                                                  AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text('$kcal kcal',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary)),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => _addToCounter(p),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceTint,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                          Icons
                                              .add_circle_outline_rounded,
                                          size: 16,
                                          color: AppColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _g(Map<dynamic, dynamic> n, String key) {
    final v = n[key] as num?;
    return v == null ? '–' : '${v.toStringAsFixed(0)}g';
  }
}
