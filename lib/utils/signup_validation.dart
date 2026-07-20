const studentEmailDomain = 'student.newinti.edu.my';

final _studentIdPattern = RegExp(r'^I\d{8}$');

String normalizeStudentId(String value) => value.trim().toUpperCase();

bool isValidStudentId(String value) =>
    _studentIdPattern.hasMatch(normalizeStudentId(value));

String studentEmailForId(String studentId) =>
    '${normalizeStudentId(studentId).toLowerCase()}@$studentEmailDomain';

bool isValidStudentEmail(String email, String studentId) =>
    isValidStudentId(studentId) &&
    email.trim().toLowerCase() == studentEmailForId(studentId);

List<int> validIntakeYears(int currentYear) =>
    List<int>.generate(11, (index) => currentYear - index);

bool isValidIntakeYear(int year, int currentYear) =>
    year >= currentYear - 10 && year <= currentYear;
