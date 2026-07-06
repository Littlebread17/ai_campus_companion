import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/course_prefs_service.dart';
import '../services/firestore_service.dart';
import '../utils/course_utils.dart';
import 'course_detail_screen.dart';

/// A course derived from the student's own timetable (distinct course codes).
class StudentCourse {
  final String fullCode; // e.g. PRG4201.1G1.JAN2026
  final String name;

  const StudentCourse({required this.fullCode, required this.name});

  String get baseCode => CourseUtils.baseCode(fullCode);
  String get termLabel => CourseUtils.termLabel(fullCode);
  Color get color => CourseUtils.colorFor(fullCode);

  /// Display name honouring a student nickname when set.
  String displayName(CoursePref? pref) {
    if (pref != null && pref.nickname.trim().isNotEmpty) return pref.nickname;
    return name.isEmpty ? fullCode : name;
  }

  /// Display colour honouring a student's custom colour when set.
  Color displayColor(CoursePref? pref) {
    if (pref?.colorValue != null) return Color(pref!.colorValue!);
    return color;
  }
}

const _weekdayNumbers = {
  'monday': 1,
  'tuesday': 2,
  'wednesday': 3,
  'thursday': 4,
  'friday': 5,
  'saturday': 6,
  'sunday': 7,
};

/// Returns a short "Next: Mon 9:00 · Room A3-01" label for the soonest upcoming
/// class of [baseCode], or null when the course has no timed rows.
String? nextClassLabel(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  String baseCode,
) {
  final now = DateTime.now();
  final nowMinutes = now.hour * 60 + now.minute;

  ({int order, String day, String start, String room})? best;

  for (final doc in docs) {
    final d = doc.data();
    if (CourseUtils.baseCode((d['courseCode'] ?? '').toString()) != baseCode) {
      continue;
    }
    final dayName = (d['day'] ?? '').toString().toLowerCase();
    final dayNum = _weekdayNumbers[dayName];
    if (dayNum == null) continue;

    final start = (d['startTime'] ?? '').toString();
    final parts = start.split(':');
    final startMinutes = parts.length == 2
        ? (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0)
        : 0;

    // Minutes from now until this weekly slot (0..7 days ahead).
    var dayDelta = dayNum - now.weekday;
    if (dayDelta < 0 || (dayDelta == 0 && startMinutes <= nowMinutes)) {
      dayDelta += 7;
    }
    final order = dayDelta * 1440 + startMinutes;

    if (best == null || order < best.order) {
      best = (
        order: order,
        day: dayName,
        start: start,
        room: (d['room'] ?? '').toString(),
      );
    }
  }

  if (best == null) return null;
  final dayShort = '${best.day[0].toUpperCase()}${best.day.substring(1, 3)}';
  final room = best.room.isEmpty ? '' : ' · ${best.room}';
  return 'Next: $dayShort ${best.start}$room';
}

/// Extracts the distinct courses from timetable documents.
List<StudentCourse> coursesFromTimetable(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final byCode = <String, StudentCourse>{};
  for (final doc in docs) {
    final data = doc.data();
    final code = (data['courseCode'] ?? '').toString().trim();
    final name = (data['courseName'] ?? '').toString().trim();
    if (code.isEmpty && name.isEmpty) continue;
    final key = CourseUtils.baseCode(code.isEmpty ? name : code);
    byCode.putIfAbsent(
      key,
      () => StudentCourse(fullCode: code.isEmpty ? name : code, name: name),
    );
  }
  final list = byCode.values.toList()
    ..sort((a, b) => a.baseCode.compareTo(b.baseCode));
  return list;
}

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final service = FirestoreService();
    final prefsService = CoursePrefsService();

    return Scaffold(
      appBar: AppBar(title: const Text('My Courses')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.streamUserTimetable(userId),
        builder: (context, ttSnap) {
          if (ttSnap.hasError) {
            return Center(child: Text('Error: ${ttSnap.error}'));
          }
          if (!ttSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final courses = coursesFromTimetable(ttSnap.data!.docs);
          if (courses.isEmpty) {
            return const _EmptyCourses();
          }

          return StreamBuilder<Map<String, CoursePref>>(
            stream: prefsService.streamPrefs(userId),
            builder: (context, prefSnap) {
              final prefs = prefSnap.data ?? {};
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: service.streamCollection('announcements'),
                builder: (context, annSnap) {
                  final annDocs = annSnap.data?.docs ?? [];
                  final visible = courses
                      .where((c) => prefs[c.baseCode]?.hidden != true)
                      .toList();
                  final hiddenCount = courses.length - visible.length;

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.55,
                    ),
                    itemCount: visible.length + (hiddenCount > 0 ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= visible.length) {
                        return _HiddenChip(count: hiddenCount);
                      }
                      final course = visible[index];
                      final pref = prefs[course.baseCode];
                      final unread = _unreadCount(course, pref, annDocs);
                      final nextClass = nextClassLabel(
                        ttSnap.data!.docs,
                        course.baseCode,
                      );
                      return CourseCard(
                        course: course,
                        pref: pref,
                        unread: unread,
                        nextClass: nextClass,
                        onEdit: () => _editPrefs(
                          context,
                          prefsService,
                          userId,
                          course,
                          pref,
                        ),
                        onOpen: () {
                          prefsService.markRead(
                            userId: userId,
                            rawCode: course.fullCode,
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CourseDetailScreen(course: course),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  int _unreadCount(
    StudentCourse course,
    CoursePref? pref,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> annDocs,
  ) {
    final lastRead = pref?.lastReadAt;
    var count = 0;
    for (final doc in annDocs) {
      final data = doc.data();
      if (CourseUtils.baseCode((data['courseCode'] ?? '').toString()) !=
          course.baseCode) {
        continue;
      }
      final created = data['createdAt'];
      if (lastRead == null) {
        count++;
      } else if (created is Timestamp && created.toDate().isAfter(lastRead)) {
        count++;
      }
    }
    return count;
  }

  Future<void> _editPrefs(
    BuildContext context,
    CoursePrefsService prefsService,
    String userId,
    StudentCourse course,
    CoursePref? pref,
  ) async {
    final nickname = TextEditingController(text: pref?.nickname ?? '');
    var selectedColor = pref?.colorValue ?? course.color.toARGB32();
    var hidden = pref?.hidden ?? false;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(course.baseCode),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nickname,
                decoration: const InputDecoration(
                  labelText: 'Nickname (optional)',
                  hintText: 'e.g. Concurrent Systems',
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Card colour',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CourseUtils.palette.map((c) {
                  final selected = c.toARGB32() == selectedColor;
                  return GestureDetector(
                    onTap: () =>
                        setLocal(() => selectedColor = c.toARGB32()),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.black : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: hidden,
                onChanged: (v) => setLocal(() => hidden = v),
                title: const Text('Hide this course'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await prefsService.savePref(
                  userId: userId,
                  rawCode: course.fullCode,
                  nickname: nickname.text.trim(),
                  colorValue: selectedColor,
                  hidden: hidden,
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    nickname.dispose();
  }
}

/// Compact "accent" course card: thin colour bar + code pill + name + the next
/// upcoming class, with an unread badge. Modern, content-first layout.
class CourseCard extends StatelessWidget {
  final StudentCourse course;
  final CoursePref? pref;
  final int unread;
  final String? nextClass;
  final VoidCallback onOpen;
  final VoidCallback? onEdit;

  const CourseCard({
    super.key,
    required this.course,
    required this.onOpen,
    this.pref,
    this.unread = 0,
    this.nextClass,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final color = course.displayColor(pref);
    final subtitle = nextClass ??
        (course.termLabel.isEmpty ? 'Tap to open' : course.termLabel);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          onLongPress: onEdit,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                course.baseCode,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (unread > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xffdc2626),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '$unread new',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            if (onEdit != null)
                              InkWell(
                                onTap: onEdit,
                                child: const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.more_vert,
                                    size: 18,
                                    color: Color(0xff94a3b8),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          course.displayName(pref),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xff0f172a),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule,
                              size: 14,
                              color: Color(0xff94a3b8),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xff64748b),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HiddenChip extends StatelessWidget {
  final int count;
  const _HiddenChip({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xfff1f5f9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.visibility_off, color: Color(0xff94a3b8)),
          const SizedBox(height: 6),
          Text(
            '$count hidden',
            style: const TextStyle(color: Color(0xff64748b)),
          ),
        ],
      ),
    );
  }
}

class _EmptyCourses extends StatelessWidget {
  const _EmptyCourses();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'No courses yet.\nUpload your timetable to generate your course cards.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
