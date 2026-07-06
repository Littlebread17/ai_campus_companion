import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/firestore_service.dart';
import '../utils/course_utils.dart';
import 'courses_screen.dart';
import 'my_results_screen.dart';

class CourseDetailScreen extends StatelessWidget {
  final StudentCourse course;
  const CourseDetailScreen({super.key, required this.course});

  bool _matchesCourse(String? code) {
    if (code == null) return false;
    return CourseUtils.baseCode(code) == course.baseCode;
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final service = FirestoreService();

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: course.color,
          foregroundColor: Colors.white,
          title: Text(course.baseCode),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Materials'),
              Tab(text: 'Announcements'),
              Tab(text: 'Due dates'),
              Tab(text: 'Schedule'),
              Tab(text: 'Grade'),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: course.color.withValues(alpha: 0.08),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.name.isEmpty ? course.fullCode : course.name,
                    style: TextStyle(
                      color: course.color,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  if (course.termLabel.isNotEmpty)
                    Text(
                      '${course.fullCode}  ·  ${course.termLabel}',
                      style: const TextStyle(
                        color: Color(0xff64748b),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _materials(service),
                  _announcements(service),
                  _dueDates(service, userId),
                  _schedule(service, userId),
                  _grade(context, service, userId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _materials(FirestoreService service) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.streamCollection('resources'),
      builder: (context, snapshot) {
        final docs = (snapshot.data?.docs ?? [])
            .where((d) => _matchesCourse(d.data()['courseCode']?.toString()))
            .toList();
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (docs.isEmpty) {
          return _empty('No materials posted for this course yet.');
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: docs.map((doc) {
            final d = doc.data();
            final url = (d['linkUrl'] ?? d['fileUrl'] ?? '').toString();
            return Card(
              child: ListTile(
                leading: Icon(Icons.folder, color: course.color),
                title: Text((d['title'] ?? 'Material').toString()),
                subtitle: Text((d['description'] ?? '').toString()),
                trailing: url.isEmpty
                    ? null
                    : const Icon(Icons.open_in_new),
                onTap: url.isEmpty
                    ? null
                    : () => launchUrl(
                          Uri.parse(url),
                          mode: LaunchMode.externalApplication,
                        ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _announcements(FirestoreService service) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.streamCollection(
        'announcements',
        orderBy: 'createdAt',
        descending: true,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        // Course-specific announcements only (those tagged with this code).
        final docs = snapshot.data!.docs
            .where((d) => _matchesCourse(d.data()['courseCode']?.toString()))
            .toList();
        if (docs.isEmpty) {
          return _empty(
            'No announcements for this course yet.\n'
            '(Class cancellations, group lists, and lecture notices will show here.)',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: docs.map((doc) {
            final d = doc.data();
            final priority = (d['priority'] ?? 'normal').toString();
            return Card(
              child: ListTile(
                leading: Icon(
                  Icons.campaign,
                  color: priority == 'high' ? Colors.red : course.color,
                ),
                title: Text((d['title'] ?? 'Announcement').toString()),
                subtitle: Text((d['description'] ?? '').toString()),
                isThreeLine: true,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _dueDates(FirestoreService service, String userId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.streamUserReminders(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs
            .where((d) => _matchesCourse(d.data()['courseCode']?.toString()))
            .toList()
          ..sort((a, b) {
            final l = '${a.data()['reminderDate']} ${a.data()['reminderTime']}';
            final r = '${b.data()['reminderDate']} ${b.data()['reminderTime']}';
            return l.compareTo(r);
          });
        if (docs.isEmpty) {
          return _empty('No due dates saved for this course yet.');
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: docs.map((doc) {
            final d = doc.data();
            return Card(
              child: ListTile(
                leading: Icon(Icons.event, color: course.color),
                title: Text((d['title'] ?? 'Due date').toString()),
                subtitle: Text(
                  '${d['reminderDate'] ?? '-'} at ${d['reminderTime'] ?? '-'}',
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _schedule(FirestoreService service, String userId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.streamUserTimetable(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs
            .where((d) => _matchesCourse(d.data()['courseCode']?.toString()))
            .toList();
        if (docs.isEmpty) {
          return _empty('No class slots found for this course.');
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: docs.map((doc) {
            final d = doc.data();
            return Card(
              child: ListTile(
                leading: Icon(Icons.schedule, color: course.color),
                title: Text(
                  '${d['day'] ?? '-'}  ${d['startTime'] ?? '-'} - ${d['endTime'] ?? '-'}',
                ),
                subtitle: Text(
                  'Room: ${d['room'] ?? '-'}\nLecturer: ${d['lecturer'] ?? '-'}',
                ),
                isThreeLine: true,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _grade(
    BuildContext context,
    FirestoreService service,
    String userId,
  ) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.streamUserGrades(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final match = snapshot.data!.docs.where(
          (d) => _matchesCourse(d.data()['courseCode']?.toString()),
        );
        final open = TextButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyResultsScreen()),
          ),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open My Results'),
        );

        if (match.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No grade recorded for this course yet.',
                    textAlign: TextAlign.center,
                  ),
                ),
                open,
              ],
            ),
          );
        }

        final g = match.first.data();
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: course.color,
                child: Text(
                  (g['grade'] ?? '?').toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${((g['gradePoint'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} grade points',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text('${g['creditHours'] ?? 0} credit hours'),
              const SizedBox(height: 12),
              open,
            ],
          ),
        );
      },
    );
  }

  Widget _empty(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
