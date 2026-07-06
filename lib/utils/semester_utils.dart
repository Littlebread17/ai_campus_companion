/// Parses INTI-style term codes (JAN2026, AUG2025, JUN2026) into real dates and
/// helps determine the current vs last semester.
class SemesterUtils {
  static const _months = {
    'JAN': 1,
    'FEB': 2,
    'MAR': 3,
    'APR': 4,
    'MAY': 5,
    'JUN': 6,
    'JUL': 7,
    'AUG': 8,
    'SEP': 9,
    'OCT': 10,
    'NOV': 11,
    'DEC': 12,
  };

  /// True when [term] looks like MON+YEAR, e.g. `JAN2026`.
  static bool isTerm(String term) =>
      RegExp(r'^[A-Z]{3}\d{4}$').hasMatch(term.toUpperCase());

  /// Sortable key so terms order chronologically (year * 100 + month).
  static int sortKey(String term) {
    final t = term.toUpperCase();
    if (!isTerm(t)) return 0;
    final month = _months[t.substring(0, 3)] ?? 1;
    final year = int.tryParse(t.substring(3)) ?? 0;
    return year * 100 + month;
  }

  /// The first Monday on/after the 1st of the intake month — a reasonable
  /// 14-week semester start when the exact academic calendar isn't known.
  static DateTime startDate(String term) {
    final t = term.toUpperCase();
    if (!isTerm(t)) return _fallbackStart();
    final month = _months[t.substring(0, 3)] ?? DateTime.now().month;
    final year = int.tryParse(t.substring(3)) ?? DateTime.now().year;
    var d = DateTime(year, month, 1);
    while (d.weekday != DateTime.monday) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  static DateTime _fallbackStart() {
    final now = DateTime.now();
    var d = DateTime(now.year, now.month, 1);
    while (d.weekday != DateTime.monday) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  /// Date of a specific teaching week (1-based) with a day-of-week offset.
  static DateTime weekDate(DateTime start, int week, int dayOffset) {
    return start.add(Duration(days: (week - 1) * 7 + dayOffset));
  }

  /// Picks the latest term from a set of term codes.
  static String? latest(Iterable<String> terms) {
    String? best;
    var bestKey = -1;
    for (final term in terms) {
      if (!isTerm(term)) continue;
      final k = sortKey(term);
      if (k > bestKey) {
        bestKey = k;
        best = term.toUpperCase();
      }
    }
    return best;
  }

  /// Picks the most recent term strictly before [current].
  static String? previous(Iterable<String> terms, String current) {
    final currentKey = sortKey(current);
    String? best;
    var bestKey = -1;
    for (final term in terms) {
      if (!isTerm(term)) continue;
      final k = sortKey(term);
      if (k < currentKey && k > bestKey) {
        bestKey = k;
        best = term.toUpperCase();
      }
    }
    return best;
  }

  /// `JAN2026` -> `Jan 2026`.
  static String label(String term) {
    final t = term.toUpperCase();
    if (!isTerm(t)) return term;
    final m = t.substring(0, 3);
    return '${m[0]}${m.substring(1).toLowerCase()} ${t.substring(3)}';
  }
}
