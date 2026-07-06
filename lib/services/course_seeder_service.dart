import '../utils/course_utils.dart';
import '../utils/semester_utils.dart';
import '../screens/courses_screen.dart' show StudentCourse;

/// Auto-generated starter content for a course so its tabs are never empty:
/// 3 assessments (as reminders) + 17 materials (as resources). Dates are
/// staggered per course code so no two courses fall on the same day.
class CourseSeedData {
  final List<Map<String, dynamic>> reminders;
  final List<Map<String, dynamic>> resources;
  const CourseSeedData({required this.reminders, required this.resources});
}

class CourseSeederService {
  /// The three assessments each course receives: (label, teaching week, time).
  static const _assessments = [
    ('Assignment', 5, '23:59'),
    ('Class Test', 9, '10:00'),
    ('Individual Assignment', 12, '23:59'),
  ];

  int _hash(String s) {
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  CourseSeedData buildFor(String userId, List<StudentCourse> courses) {
    final reminders = <Map<String, dynamic>>[];
    final resources = <Map<String, dynamic>>[];

    for (final course in courses) {
      final code = course.baseCode;
      final term = CourseUtils.term(course.fullCode);
      final start = SemesterUtils.startDate(term);
      // Day-of-week offset (Mon..Fri) unique per course so dates stagger.
      final dayOffset = _hash(code) % 5;

      for (final (label, week, time) in _assessments) {
        final date = SemesterUtils.weekDate(start, week, dayOffset);
        reminders.add({
          'userId': userId,
          'title': '$code $label',
          'description': 'Auto-generated $label for $code. Tap to edit the '
              'date and details once your lecturer confirms them.',
          'courseCode': code,
          'reminderDate': _fmtDate(date),
          'reminderTime': time,
          'status': 'active',
          'type': label.toLowerCase().contains('test') ? 'test' : 'assignment',
          'auto': true,
          'createdBy': 'course_seeder',
        });
      }

      final materials = <String>[
        'Course Outline',
        'Tutorial Questions',
        'Past Year Papers',
        for (var w = 1; w <= 14; w++) 'Week $w Notes',
      ];
      for (final title in materials) {
        resources.add({
          'userId': userId,
          'title': '$code - $title',
          'description': 'Auto-generated placeholder. Add the real link when '
              'your lecturer shares it.',
          'category': 'Course Material',
          'courseCode': code,
          'linkUrl': '',
          'fileUrl': '',
          'auto': true,
          'uploadedBy': 'course_seeder',
        });
      }
    }

    return CourseSeedData(reminders: reminders, resources: resources);
  }
}
