/// Grade-to-point mapping and CGPA calculation on the standard 4.0 scale
/// (used by INTI and most Malaysian universities).
class GradeUtils {
  /// Ordered list of selectable letter grades.
  static const grades = [
    'A',
    'A-',
    'B+',
    'B',
    'B-',
    'C+',
    'C',
    'C-',
    'D+',
    'D',
    'F',
  ];

  static const _points = <String, double>{
    'A': 4.00,
    'A-': 3.67,
    'B+': 3.33,
    'B': 3.00,
    'B-': 2.67,
    'C+': 2.33,
    'C': 2.00,
    'C-': 1.67,
    'D+': 1.33,
    'D': 1.00,
    'F': 0.00,
  };

  static double pointFor(String grade) => _points[grade.toUpperCase()] ?? 0.0;

  /// Weighted GPA/CGPA: Σ(point × credit) / Σ(credit).
  /// [rows] each need a `gradePoint` (num) and `creditHours` (num).
  static double cgpa(Iterable<Map<String, dynamic>> rows) {
    double totalPoints = 0;
    double totalCredits = 0;
    for (final row in rows) {
      final credit = (row['creditHours'] as num?)?.toDouble() ?? 0;
      final point = (row['gradePoint'] as num?)?.toDouble() ?? 0;
      totalPoints += point * credit;
      totalCredits += credit;
    }
    if (totalCredits == 0) return 0;
    return totalPoints / totalCredits;
  }

  static String format(double value) => value.toStringAsFixed(2);
}
