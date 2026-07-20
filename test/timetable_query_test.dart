import 'package:flutter_test/flutter_test.dart';

import 'package:ai_campus_companion/services/ai_agent_service.dart';

void main() {
  test('resolves relative and named timetable days', () {
    final tuesday = DateTime(2026, 7, 14);

    expect(timetableDayFromQuery('tomorrow class', tuesday), 'Wednesday');
    expect(timetableDayFromQuery('classes today', tuesday), 'Tuesday');
    expect(timetableDayFromQuery('Friday lectures', tuesday), 'Friday');
    expect(timetableDayFromQuery('show my timetable', tuesday), isNull);
  });

  test('tomorrow wraps from Sunday to Monday', () {
    final sunday = DateTime(2026, 7, 19);

    expect(timetableDayFromQuery('tomorrow class', sunday), 'Monday');
  });
}
