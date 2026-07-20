/// Shared helpers for the simple recurrence presets used by reminders/events:
/// 'none', 'daily', 'weekdays', 'weekly'.
class Recurrence {
  static const options = <String, String>{
    'none': 'Does not repeat',
    'daily': 'Every day',
    'weekdays': 'Every weekday (Mon–Fri)',
    'weekly': 'Every week',
  };

  static const leadTimeOptions = <int, String>{
    0: 'At time of event',
    5: '5 minutes before',
    15: '15 minutes before',
    60: '1 hour before',
  };

  /// Does an item whose first date is [baseYmd] (yyyy-MM-dd) with [recurrence]
  /// land on [target]?
  static bool occursOn(String baseYmd, String recurrence, DateTime target) {
    final base = DateTime.tryParse(baseYmd);
    if (base == null) return false;
    final b = DateTime(base.year, base.month, base.day);
    final t = DateTime(target.year, target.month, target.day);
    switch (recurrence) {
      case 'daily':
        return !t.isBefore(b);
      case 'weekdays':
        return !t.isBefore(b) && t.weekday >= DateTime.monday && t.weekday <= DateTime.friday;
      case 'weekly':
        return !t.isBefore(b) && t.weekday == b.weekday;
      default:
        return t == b;
    }
  }

  /// The next date on/after [from] that a recurring item occurs. For 'none'
  /// this is just the base date. Returns the base date if nothing matches
  /// within a year (defensive).
  static DateTime nextOccurrence(String baseYmd, String recurrence, DateTime from) {
    final base = DateTime.tryParse(baseYmd) ?? from;
    if (recurrence == 'none' || recurrence.isEmpty) return base;
    var day = DateTime(from.year, from.month, from.day);
    final baseDay = DateTime(base.year, base.month, base.day);
    if (day.isBefore(baseDay)) day = baseDay;
    for (var i = 0; i < 366; i++) {
      if (occursOn(baseYmd, recurrence, day)) return day;
      day = day.add(const Duration(days: 1));
    }
    return base;
  }
}
