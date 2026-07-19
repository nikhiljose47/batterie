import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';
import '../../models/energy_log_record.dart';
import '../../models/logged_activity.dart';
import '../../services/energy_log_store.dart';
import '../home_tab/data/mode_advice.dart';

/// Which data store the inspector should dump.
enum InspectorSource {
  energyLog('Energy log (SQLite)', Icons.storage_rounded),
  weatherCache('Weather cache (prefs)', Icons.cloud_outlined),
  modeAdvice('Mode advice (const)', Icons.menu_book_outlined);

  const InspectorSource(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Dev-only page that dumps whatever the app has persisted, so you can
/// verify data without hunting through adb/sqlite by hand. Reached from
/// the test-tube button in the top bar.
class DataInspectorPage extends StatefulWidget {
  const DataInspectorPage({super.key, required this.source});

  final InspectorSource source;

  @override
  State<DataInspectorPage> createState() => _DataInspectorPageState();
}

class _DataInspectorPageState extends State<DataInspectorPage> {
  late Future<List<_InspectorEntry>> _entries;

  @override
  void initState() {
    super.initState();
    _entries = _load();
  }

  Future<List<_InspectorEntry>> _load() async {
    switch (widget.source) {
      case InspectorSource.energyLog:
        return _loadEnergyLog();
      case InspectorSource.weatherCache:
        return _loadWeatherCache();
      case InspectorSource.modeAdvice:
        return _loadModeAdvice();
    }
  }

  Future<List<_InspectorEntry>> _loadEnergyLog() async {
    final entries = <_InspectorEntry>[];
    final store = SqliteEnergyLogStore.instance;
    final today = DateTime.now();

    for (var back = 0; back <= 7; back++) {
      final day = today.subtract(Duration(days: back));
      final key = dateKey(day);
      List<EnergyLogRecord> records;
      try {
        records = await store.recordsForDate(key);
      } catch (e) {
        entries.add(_InspectorEntry(
          title: key,
          body: 'read failed: $e',
          isError: true,
        ));
        continue;
      }
      if (records.isEmpty) continue;
      for (final r in records) {
        final emoji = activityEmojis[r.activityId] ?? '⚡';
        entries.add(_InspectorEntry(
          title:
              '$key · ${formatMinutes(r.startMinutes)} · $emoji ${r.activityId}',
          body: 'duration ${r.durationMinutes} min · '
              'physical ${r.physicalAfter} · brain ${r.brainAfter}\n'
              'id ${r.id}',
        ));
      }
    }
    if (entries.isEmpty) {
      entries.add(const _InspectorEntry(
        title: 'No records',
        body: 'Nothing logged in the last 8 days.',
      ));
    }
    return entries;
  }

  Future<List<_InspectorEntry>> _loadWeatherCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('weather.snapshot.v1');
      if (raw == null) {
        return const <_InspectorEntry>[
          _InspectorEntry(
            title: 'weather.snapshot.v1',
            body: '(empty — no snapshot cached yet)',
          ),
        ];
      }
      final pretty = const JsonEncoder.withIndent('  ')
          .convert(jsonDecode(raw));
      return <_InspectorEntry>[
        _InspectorEntry(title: 'weather.snapshot.v1', body: pretty),
      ];
    } catch (e) {
      return <_InspectorEntry>[
        _InspectorEntry(
            title: 'weather.snapshot.v1',
            body: 'read failed: $e',
            isError: true),
      ];
    }
  }

  Future<List<_InspectorEntry>> _loadModeAdvice() async {
    final entries = <_InspectorEntry>[];
    for (final mode in modeAdviceMap.entries) {
      final lines = <String>[];
      for (var i = 0; i < mode.value.length; i++) {
        final slot = plannerSlots[i];
        final a = mode.value[i];
        lines.add('${slot.rangeLabel}: ${a.recommendation}\n'
            '   tip: ${a.tip}\n   crowd: ${a.crowd}');
      }
      entries.add(_InspectorEntry(
        title: 'mode: ${mode.key} (${mode.value.length} slots)',
        body: lines.join('\n'),
      ));
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 44,
        title: Row(
          children: <Widget>[
            Icon(widget.source.icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              widget.source.label,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () => setState(() => _entries = _load()),
          ),
        ],
      ),
      body: FutureBuilder<List<_InspectorEntry>>(
        future: _entries,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.large),
                child: Text('Failed to load: ${snapshot.error}'),
              ),
            );
          }
          final entries = snapshot.data ?? const <_InspectorEntry>[];
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.large),
            itemCount: entries.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.small),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.medium),
                decoration: BoxDecoration(
                  color: entry.isError
                      ? const Color(0xFFFFF0F0)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: entry.isError
                        ? const Color(0xFFE0A0A0)
                        : AppColors.outline.withValues(alpha: 0.8),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      entry.body,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        fontFamily: 'monospace',
                        color: Colors.black.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _InspectorEntry {
  const _InspectorEntry({
    required this.title,
    required this.body,
    this.isError = false,
  });

  final String title;
  final String body;
  final bool isError;
}
