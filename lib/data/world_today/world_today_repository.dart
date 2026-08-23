import 'world_today_jan_to_jun.dart';
import 'world_today_jul_to_dec.dart';

class WorldTodayRepository {
  const WorldTodayRepository();

  String factFor(DateTime date) {
    final key = _keyFor(date);
    final source = date.month <= 6 ? worldToday : worldTodayJuly;
    return source[key] ??
        'Every day has something worth noticing. Add a world-today note for $key.';
  }

  String _keyFor(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month-$day';
  }
}
