import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../utils/grade_utils.dart';
import '../utils/semester_utils.dart';

/// One result row extracted (best-effort) from a scanned transcript / result
/// slip. All fields are guesses the student reviews and corrects.
class ScannedResult {
  String courseCode;
  String courseName;
  String semester;
  String grade;
  String creditHours;

  ScannedResult({
    this.courseCode = '',
    this.courseName = '',
    this.semester = '',
    this.grade = '',
    this.creditHours = '3',
  });
}

class ResultOcrResult {
  final List<ScannedResult> results;
  final String rawText;
  const ResultOcrResult({required this.results, required this.rawText});
}

class ResultOcrService {
  static bool get isSupported => !kIsWeb;

  static final _courseCode = RegExp(r'[A-Z]{2,4}\d{3,4}(?:\.[A-Za-z0-9]+)*');
  // Grade token: A, A-, B+, ... standalone.
  static final _grade = RegExp(r'\b(A\-|A|B\+|B\-|B|C\+|C\-|C|D\+|D|F)\b');
  static final _term = RegExp(r'\b([A-Z]{3}\d{4})\b');

  Future<ResultOcrResult> scan(String imagePath) async {
    if (!isSupported) {
      return const ResultOcrResult(results: [], rawText: '');
    }
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(input);
      final lines = <String>[];
      for (final block in result.blocks) {
        for (final line in block.lines) {
          final t = line.text.trim();
          if (t.isNotEmpty) lines.add(t);
        }
      }
      return ResultOcrResult(
        results: _parse(lines, result.text),
        rawText: result.text,
      );
    } finally {
      await recognizer.close();
    }
  }

  List<ScannedResult> _parse(List<String> lines, String fullText) {
    // A single term often covers the whole slip; capture the first as default.
    final termMatch = _term.firstMatch(fullText.toUpperCase());
    final defaultSemester = termMatch?.group(1) ?? '';

    final rows = <ScannedResult>[];
    for (final line in lines) {
      final upper = line.toUpperCase();
      final codeMatch = _courseCode.firstMatch(upper);
      final gradeMatch = _grade.firstMatch(upper);
      // A row needs at least a course code AND a grade to be worth adding.
      if (codeMatch == null || gradeMatch == null) continue;

      // Credit hours: a small standalone integer (1-6) on the line.
      final creditMatch = RegExp(r'\b([1-6])\b').firstMatch(line);

      final lineTerm = _term.firstMatch(upper)?.group(1);

      rows.add(
        ScannedResult(
          courseCode: codeMatch.group(0)!,
          semester: lineTerm != null && SemesterUtils.isTerm(lineTerm)
              ? lineTerm
              : defaultSemester,
          grade: gradeMatch.group(0)!,
          creditHours: creditMatch?.group(1) ?? '3',
        ),
      );
    }
    return rows;
  }

  static double pointFor(String grade) => GradeUtils.pointFor(grade);
}
