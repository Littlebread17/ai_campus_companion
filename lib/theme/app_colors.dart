import 'package:flutter/material.dart';

/// Single source of truth for the app's colours and content-type accents, so
/// every screen speaks the same visual language.
class AppColors {
  AppColors._();

  // Brand
  static const brand = Color(0xffe30613);
  static const primary = Color(0xff2563eb);
  static const secondary = Color(0xff7c3aed);
  static const tertiary = Color(0xff06b6d4);

  // Tonal accents
  static const primarySoft = Color(0xffeef2ff);
  static const primaryBorder = Color(0xffdbe2fb);
  static const secondarySoft = Color(0xfff3e8ff);
  static const tertiarySoft = Color(0xffecfeff);
  static const brandSoft = Color(0xfffef2f2);

  // Surfaces
  static const background = Color(0xfff6f8ff);
  static const surface = Colors.white;
  static const surfaceSoft = Color(0xfff8fafc);
  static const border = Color(0xffe2e8f0);
  static const borderStrong = Color(0xffcbd5e1);

  // Text
  static const ink = Color(0xff0f172a);
  static const muted = Color(0xff64748b);
  static const faint = Color(0xff94a3b8);

  // Semantic
  static const success = Color(0xff16a34a);
  static const warning = Color(0xffea580c);
  static const danger = Color(0xffdc2626);

  // Content-type accents — locked meanings used across cards, chips, dots.
  static const classColor = Color(0xff2563eb); // classes / timetable
  static const eventColor = Color(0xff7c3aed); // events
  static const reminderColor = Color(0xffea580c); // reminders / tasks
  static const chatColor = Color(0xff0891b2); // chats
  static const announcementColor = Color(0xfff59e0b); // announcements

  /// Accent for a content type key: class | event | reminder | chat |
  /// announcement | assignment | study | meeting | personal.
  static Color forType(String type) {
    switch (type.toLowerCase()) {
      case 'class':
      case 'timetable':
        return classColor;
      case 'event':
        return eventColor;
      case 'reminder':
      case 'task':
      case 'assignment':
        return reminderColor;
      case 'chat':
      case 'dm':
        return chatColor;
      case 'announcement':
        return announcementColor;
      case 'study':
        return success;
      case 'meeting':
        return secondary;
      default:
        return muted;
    }
  }
}
