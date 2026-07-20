import 'dart:convert';

import 'package:share_plus/share_plus.dart';

/// A single calendar entry to serialise into an .ics file.
class IcsEntry {
  final String uid;
  final String title;
  final DateTime start;
  final DateTime? end;
  final String location;
  final String description;

  const IcsEntry({
    required this.uid,
    required this.title,
    required this.start,
    this.end,
    this.location = '',
    this.description = '',
  });
}

class IcsExport {
  /// Build a valid iCalendar document from [entries].
  static String build(List<IcsEntry> entries) {
    final b = StringBuffer()
      ..writeln('BEGIN:VCALENDAR')
      ..writeln('VERSION:2.0')
      ..writeln('PRODID:-//AI Campus Companion//Canva//EN')
      ..writeln('CALSCALE:GREGORIAN');
    final stamp = _fmt(DateTime.now().toUtc(), utc: true);
    for (final e in entries) {
      final end = e.end ?? e.start.add(const Duration(minutes: 30));
      b
        ..writeln('BEGIN:VEVENT')
        ..writeln('UID:${e.uid}@aicampuscompanion')
        ..writeln('DTSTAMP:$stamp')
        ..writeln('DTSTART:${_fmt(e.start)}')
        ..writeln('DTEND:${_fmt(end)}')
        ..writeln('SUMMARY:${_escape(e.title)}');
      if (e.location.isNotEmpty) b.writeln('LOCATION:${_escape(e.location)}');
      if (e.description.isNotEmpty) {
        b.writeln('DESCRIPTION:${_escape(e.description)}');
      }
      b.writeln('END:VEVENT');
    }
    b.writeln('END:VCALENDAR');
    return b.toString();
  }

  /// Share / download the .ics. On web this triggers a file download; on mobile
  /// it opens the share sheet so the student can import into their calendar app.
  static Future<void> share(List<IcsEntry> entries) async {
    final content = build(entries);
    await Share.shareXFiles([
      XFile.fromData(
        utf8.encode(content),
        mimeType: 'text/calendar',
        name: 'campus_calendar.ics',
      ),
    ], subject: 'My Campus Calendar');
  }

  static String _fmt(DateTime d, {bool utc = false}) {
    String two(int n) => n.toString().padLeft(2, '0');
    final s =
        '${d.year}${two(d.month)}${two(d.day)}T${two(d.hour)}${two(d.minute)}${two(d.second)}';
    return utc ? '${s}Z' : s;
  }

  static String _escape(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll(',', '\\,').replaceAll(';', '\\;').replaceAll('\n', '\\n');
}
