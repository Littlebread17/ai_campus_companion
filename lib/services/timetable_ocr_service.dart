import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// One class row extracted (best-effort) from a scanned timetable image.
/// All fields are guesses the student is expected to review and correct.
class ScannedClass {
  String courseCode;
  String courseName;
  String day;
  String startTime;
  String endTime;
  String room;
  String lecturer;

  ScannedClass({
    this.courseCode = '',
    this.courseName = '',
    this.day = '',
    this.startTime = '',
    this.endTime = '',
    this.room = '',
    this.lecturer = '',
  });

  Map<String, dynamic> toMap() => {
        'courseCode': courseCode,
        'courseName': courseName,
        'day': day,
        'startTime': startTime,
        'endTime': endTime,
        'room': room,
        'lecturer': lecturer,
      };
}

class TimetableOcrResult {
  final List<ScannedClass> classes;
  final String rawText;
  const TimetableOcrResult({required this.classes, required this.rawText});
}

class TimetableOcrService {
  static bool get isSupported => !kIsWeb;

  static final _courseCode = RegExp(r'[A-Z]{2,4}\d{3,4}(?:\.[A-Za-z0-9]+)*');
  static final _timeRange = RegExp(
    r'(\d{1,2})[:.](\d{2})\s*(am|pm)?\s*[-–to]+\s*(\d{1,2})[:.](\d{2})\s*(am|pm)?',
    caseSensitive: false,
  );
  static const _days = {
    'monday': 'Monday',
    'mon': 'Monday',
    'tuesday': 'Tuesday',
    'tue': 'Tuesday',
    'tues': 'Tuesday',
    'wednesday': 'Wednesday',
    'wed': 'Wednesday',
    'thursday': 'Thursday',
    'thu': 'Thursday',
    'thur': 'Thursday',
    'thurs': 'Thursday',
    'friday': 'Friday',
    'fri': 'Friday',
    'saturday': 'Saturday',
    'sat': 'Saturday',
    'sunday': 'Sunday',
    'sun': 'Sunday',
  };

  /// Runs OCR on the image and returns best-effort class rows + the raw text.
  Future<TimetableOcrResult> scan(String imagePath) async {
    if (!isSupported) {
      return const TimetableOcrResult(classes: [], rawText: '');
    }

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(input);
      final lines = <String>[];
      for (final block in result.blocks) {
        for (final line in block.lines) {
          final text = line.text.trim();
          if (text.isNotEmpty) lines.add(text);
        }
      }
      return TimetableOcrResult(
        classes: _parse(lines),
        rawText: result.text,
      );
    } finally {
      await recognizer.close();
    }
  }

  /// Heuristic parser: a timetable screenshot loses its grid structure once
  /// flattened to lines, so we anchor one row per detected time range and
  /// attach the nearest course code / day / room around it.
  List<ScannedClass> _parse(List<String> lines) {
    final rows = <ScannedClass>[];

    String normTime(String h, String m, String? ap) {
      var hour = int.parse(h);
      final minute = m;
      final a = ap?.toLowerCase();
      if (a == 'pm' && hour < 12) hour += 12;
      if (a == 'am' && hour == 12) hour = 0;
      return '${hour.toString().padLeft(2, '0')}:$minute';
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final timeMatch = _timeRange.firstMatch(line);
      if (timeMatch == null) continue;

      final row = ScannedClass(
        startTime: normTime(
          timeMatch.group(1)!,
          timeMatch.group(2)!,
          timeMatch.group(3),
        ),
        endTime: normTime(
          timeMatch.group(4)!,
          timeMatch.group(5)!,
          timeMatch.group(6),
        ),
      );

      // Look at this line plus the two lines before and after for context.
      final context = <String>[
        if (i - 2 >= 0) lines[i - 2],
        if (i - 1 >= 0) lines[i - 1],
        line,
        if (i + 1 < lines.length) lines[i + 1],
        if (i + 2 < lines.length) lines[i + 2],
      ].join(' ');

      final codeMatch = _courseCode.firstMatch(context);
      if (codeMatch != null) row.courseCode = codeMatch.group(0)!;

      final lower = context.toLowerCase();
      for (final entry in _days.entries) {
        if (RegExp('\\b${entry.key}\\b').hasMatch(lower)) {
          row.day = entry.value;
          break;
        }
      }

      // A room often looks like A3-01, B5-13, Lab 2, LT A.
      final roomMatch = RegExp(
        r'\b([A-Z]{1,3}\d{0,2}-?\d{1,3}|lab\s*\d+|lt\s*[a-z0-9]+)\b',
        caseSensitive: false,
      ).firstMatch(context);
      if (roomMatch != null &&
          roomMatch.group(0)!.toUpperCase() != row.courseCode) {
        row.room = roomMatch.group(0)!;
      }

      rows.add(row);
    }

    return rows;
  }
}
