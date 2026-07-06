import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../utils/course_utils.dart';
import '../utils/grade_utils.dart';
import '../utils/semester_utils.dart';
import 'courses_screen.dart';
import 'upload_results_screen.dart';

class MyResultsScreen extends StatelessWidget {
  const MyResultsScreen({super.key});

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Results'),
        actions: [
          IconButton(
            tooltip: 'Upload result slip',
            icon: const Icon(Icons.upload_file),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UploadResultsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editGrade(context, service),
        icon: const Icon(Icons.add),
        label: const Text('Add result'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.streamUserGrades(_userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No results yet.\nTap "Add result" to record a course grade '
                  'and start tracking your CGPA.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final all = docs.map((d) => {'id': d.id, ...d.data()}).toList();
          final cgpa = GradeUtils.cgpa(all);
          final totalCredits = all.fold<double>(
            0,
            (acc, r) => acc + ((r['creditHours'] as num?)?.toDouble() ?? 0),
          );

          // Group by semester.
          final bySemester = <String, List<Map<String, dynamic>>>{};
          for (final r in all) {
            final sem = (r['semester'] ?? 'Other').toString();
            bySemester.putIfAbsent(sem, () => []).add(r);
          }
          final semesters = bySemester.keys.toList()..sort();

          final currentSem = SemesterUtils.latest(semesters);
          final lastSem = currentSem == null
              ? null
              : SemesterUtils.previous(semesters, currentSem);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _cgpaHeader(cgpa, totalCredits, all.length),
              const SizedBox(height: 12),
              _semesterCompare(currentSem, lastSem, bySemester),
              const SizedBox(height: 16),
              for (final sem in semesters) ...[
                _semesterHeader(sem, bySemester[sem]!),
                ...bySemester[sem]!.map(
                  (r) => _gradeTile(context, service, r),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _cgpaHeader(double cgpa, double credits, int count) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff2563eb), Color(0xff7c3aed)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cumulative CGPA',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                GradeUtils.format(cgpa),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _miniStat('$count', 'courses'),
              const SizedBox(height: 8),
              _miniStat(credits.toStringAsFixed(0), 'credit hrs'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _semesterCompare(
    String? current,
    String? last,
    Map<String, List<Map<String, dynamic>>> bySemester,
  ) {
    return Row(
      children: [
        Expanded(
          child: _semCard(
            'Current semester',
            current,
            current == null ? null : GradeUtils.cgpa(bySemester[current]!),
            current == null ? 0 : bySemester[current]!.length,
            const Color(0xff2563eb),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _semCard(
            'Last semester',
            last,
            last == null ? null : GradeUtils.cgpa(bySemester[last]!),
            last == null ? 0 : bySemester[last]!.length,
            const Color(0xff7c3aed),
          ),
        ),
      ],
    );
  }

  Widget _semCard(
    String label,
    String? term,
    double? gpa,
    int count,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xff64748b))),
          const SizedBox(height: 2),
          Text(
            term == null ? 'No data' : SemesterUtils.label(term),
            style: TextStyle(fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            gpa == null ? '-' : 'GPA ${GradeUtils.format(gpa)}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          Text(
            '$count course${count == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 11, color: Color(0xff64748b)),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _semesterHeader(String semester, List<Map<String, dynamic>> rows) {
    final gpa = GradeUtils.cgpa(rows);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Row(
        children: [
          Text(
            CourseUtils.termLabel('X.X.$semester').isEmpty
                ? semester
                : CourseUtils.termLabel('X.X.$semester'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const Spacer(),
          Text(
            'GPA ${GradeUtils.format(gpa)}',
            style: const TextStyle(
              color: Color(0xff2563eb),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradeTile(
    BuildContext context,
    FirestoreService service,
    Map<String, dynamic> r,
  ) {
    final code = (r['courseCode'] ?? '').toString();
    final color = CourseUtils.colorFor(code);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Text(
            (r['grade'] ?? '?').toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
        title: Text(CourseUtils.baseCode(code)),
        subtitle: Text(
          '${r['courseName'] ?? ''}\n'
          '${r['creditHours'] ?? 0} credit hrs · ${((r['gradePoint'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} points',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') _editGrade(context, service, existing: r);
            if (v == 'delete') service.deleteGrade(r['id'].toString());
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  Future<void> _editGrade(
    BuildContext context,
    FirestoreService service, {
    Map<String, dynamic>? existing,
  }) async {
    // Pull the student's courses (from timetable) to offer as quick-pick.
    final ttSnap = await FirebaseFirestore.instance
        .collection('timetable')
        .where('userId', isEqualTo: _userId)
        .get();
    final courses = coursesFromTimetable(ttSnap.docs);

    final codeCtrl =
        TextEditingController(text: existing?['courseCode']?.toString() ?? '');
    final nameCtrl =
        TextEditingController(text: existing?['courseName']?.toString() ?? '');
    final semCtrl =
        TextEditingController(text: existing?['semester']?.toString() ?? '');
    final creditCtrl = TextEditingController(
      text: (existing?['creditHours'] ?? 3).toString(),
    );
    var grade = (existing?['grade'] ?? 'A').toString();

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Add result' : 'Edit result'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (courses.isNotEmpty && existing == null)
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Pick from my courses',
                    ),
                    items: courses
                        .map((c) => DropdownMenuItem(
                              value: c.fullCode,
                              child: Text(
                                '${c.baseCode} ${c.name}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) {
                      final c = courses.firstWhere((e) => e.fullCode == v);
                      setLocal(() {
                        codeCtrl.text = c.baseCode;
                        nameCtrl.text = c.name;
                        semCtrl.text = CourseUtils.term(c.fullCode);
                      });
                    },
                  ),
                _field(codeCtrl, 'Course code'),
                _field(nameCtrl, 'Course name'),
                _field(semCtrl, 'Semester (e.g. JAN2026)'),
                _field(creditCtrl, 'Credit hours', number: true),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: grade,
                  decoration: const InputDecoration(labelText: 'Grade'),
                  items: GradeUtils.grades
                      .map((g) => DropdownMenuItem(
                            value: g,
                            child: Text(
                              '$g  (${GradeUtils.pointFor(g).toStringAsFixed(2)})',
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setLocal(() => grade = v ?? 'A'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final credit = double.tryParse(creditCtrl.text.trim()) ?? 0;
                if (codeCtrl.text.trim().isEmpty || credit <= 0) return;
                final point = GradeUtils.pointFor(grade);
                if (existing == null) {
                  await service.addGrade(
                    userId: _userId,
                    courseCode: codeCtrl.text.trim(),
                    courseName: nameCtrl.text.trim(),
                    semester: semCtrl.text.trim(),
                    grade: grade,
                    gradePoint: point,
                    creditHours: credit,
                  );
                } else {
                  await service.updateGrade(
                    id: existing['id'].toString(),
                    courseCode: codeCtrl.text.trim(),
                    courseName: nameCtrl.text.trim(),
                    semester: semCtrl.text.trim(),
                    grade: grade,
                    gradePoint: point,
                    creditHours: credit,
                  );
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    for (final c in [codeCtrl, nameCtrl, semCtrl, creditCtrl]) {
      c.dispose();
    }
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool number = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: c,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label, isDense: true),
      ),
    );
  }
}
