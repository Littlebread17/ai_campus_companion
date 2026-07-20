import 'package:flutter_test/flutter_test.dart';

import 'package:ai_campus_companion/utils/signup_validation.dart';

void main() {
  group('student identity validation', () {
    test('normalizes and accepts I followed by eight digits', () {
      expect(normalizeStudentId(' i24026253 '), 'I24026253');
      expect(isValidStudentId('I24026253'), isTrue);
    });

    test('rejects invalid student ID formats', () {
      expect(isValidStudentId('24026253'), isFalse);
      expect(isValidStudentId('I2402625'), isFalse);
      expect(isValidStudentId('I240262530'), isFalse);
      expect(isValidStudentId('A24026253'), isFalse);
    });

    test('derives and validates the matching student email', () {
      expect(
        studentEmailForId('I24026253'),
        'i24026253@student.newinti.edu.my',
      );
      expect(
        isValidStudentEmail('I24026253@STUDENT.NEWINTI.EDU.MY', 'I24026253'),
        isTrue,
      );
      expect(
        isValidStudentEmail('i24026254@student.newinti.edu.my', 'I24026253'),
        isFalse,
      );
    });
  });

  group('intake year validation', () {
    test('offers the current year and previous ten years', () {
      final years = validIntakeYears(2026);

      expect(years, [
        2026,
        2025,
        2024,
        2023,
        2022,
        2021,
        2020,
        2019,
        2018,
        2017,
        2016,
      ]);
    });

    test('rejects years outside the allowed range', () {
      expect(isValidIntakeYear(2016, 2026), isTrue);
      expect(isValidIntakeYear(2026, 2026), isTrue);
      expect(isValidIntakeYear(2015, 2026), isFalse);
      expect(isValidIntakeYear(2027, 2026), isFalse);
    });
  });
}
