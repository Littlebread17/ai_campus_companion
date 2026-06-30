import 'package:flutter/material.dart';

/// Helpers for working with Canvas-style course codes such as
/// `PRG4201.1G1.JAN2026` or `MPU3206.1C.JAN2026`.
class CourseUtils {
  /// Canvas-style course card palette (matches the look of the LMS cards).
  static const palette = <Color>[
    Color(0xff0b78c2), // blue
    Color(0xff9c27b0), // purple
    Color(0xffe91e63), // pink
    Color(0xff2e8b6f), // green
    Color(0xffd84315), // deep orange
    Color(0xff5c6bc0), // indigo
    Color(0xff00838f), // teal
    Color(0xff6d4c41), // brown
    Color(0xff607d8b), // blue grey
    Color(0xffc62828), // red
  ];

  /// The short subject code (before the first dot), e.g. `PRG4201`.
  static String baseCode(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.split('.').first.toUpperCase();
  }

  /// The intake/term segment (the last dotted part), e.g. `JAN2026`.
  /// Returns an empty string when the code has no term segment.
  static String term(String raw) {
    final parts = raw.trim().split('.');
    if (parts.length < 2) return '';
    final last = parts.last.toUpperCase();
    // Only treat it as a term if it looks like MON+YEAR (e.g. JAN2026).
    if (RegExp(r'^[A-Z]{3}\d{4}$').hasMatch(last)) return last;
    return '';
  }

  /// A nicely formatted term for display, e.g. `Jan 2026`.
  static String termLabel(String raw) {
    final t = term(raw);
    if (t.isEmpty) return '';
    final month = t.substring(0, 3);
    final year = t.substring(3);
    return '${month[0]}${month.substring(1).toLowerCase()} $year';
  }

  /// Deterministic colour for a course so the same code always gets the same
  /// card colour across screens.
  static Color colorFor(String raw) {
    final key = baseCode(raw);
    if (key.isEmpty) return palette.first;
    var hash = 0;
    for (final code in key.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return palette[hash % palette.length];
  }
}
