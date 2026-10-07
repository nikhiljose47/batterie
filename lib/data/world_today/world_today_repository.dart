import 'world_today_jan_to_jun_1.dart' as janJunOne;
import 'world_today_jan_to_jun_2.dart' as janJunTwo;
import 'world_today_jul_to_dec_1.dart' as julDecOne;
import 'world_today_jul_to_dec_2.dart' as julDecTwo;

class WorldTodayRepository {
  const WorldTodayRepository();

  String factFor(DateTime date) {
    return factsFor(date).first;
  }

  List<String> factsFor(DateTime date) {
    final key = _keyFor(date);
    final sources = date.month <= 6
        ? <Map<String, String>>[
            janJunOne.worldToday,
            janJunTwo.worldToday,
          ]
        : <Map<String, String>>[
            julDecOne.worldTodayJuly,
            julDecTwo.worldTodayJuly,
          ];
    final facts = sources
        .map((source) => source[key])
        .whereType<String>()
        .where((fact) => fact.trim().isNotEmpty)
        .toList(growable: false);
    if (facts.isNotEmpty) return facts;
    return <String>[
      'Every day has something worth noticing. Add a world-today note for $key.',
    ];
  }

  String _keyFor(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month-$day';
  }
}
