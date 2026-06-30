import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('My Courses')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.streamUserTimetable(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final courses = coursesFromTimetable(snapshot.data!.docs);
          if (courses.isEmpty) {
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
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.92,
            ),
            itemCount: courses.length,
            itemBuilder: (context, index) =>
                CourseCard(course: courses[index]),
          );
        },
      ),
    );
  }
}

/// Canvas-style course card: coloured banner + code + term + quick actions.
class CourseCard extends StatelessWidget {
  final StudentCourse course;
  const CourseCard({super.key, required this.course});

  void _open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 88,
              decoration: BoxDecoration(
                color: course.color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.all(10),
              child: Text(
                course.baseCode,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.name.isEmpty ? course.fullCode : course.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: course.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (course.termLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      course.termLabel,
                      style: const TextStyle(
                        color: Color(0xff64748b),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  Icon(Icons.campaign, size: 18, color: Color(0xff64748b)),
                  Icon(Icons.assignment, size: 18, color: Color(0xff64748b)),
                  Icon(Icons.folder, size: 18, color: Color(0xff64748b)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
