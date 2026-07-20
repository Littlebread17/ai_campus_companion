import 'package:cloud_firestore/cloud_firestore.dart';

import 'course_seeder_service.dart';
import '../screens/courses_screen.dart' show StudentCourse;

/// Populates Firestore with realistic demo content so a supervisor can see
/// every part of the app working. Uses fixed doc IDs so repeated runs update
/// (never duplicate) the seeded records.
class DemoSeederService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<DemoSeedResult> seedAll({
    required String userId,
    required String userName,
    required String userEmail,
  }) async {
    final startedAt = DateTime.now();

    await _seedStudentRegistry();

    await _seedTimetable(userId);
    await _seedAutoCourseContent(userId);
    await _seedReminders(userId);
    await _seedGrades(userId);
    await _seedCalendarEvents(userId);

    await _seedAnnouncements(userId);
    await _seedEvents(userId);
    await _seedResources(userId);
    await _seedNotifications();
    await _seedLocations();

    return DemoSeedResult(
      counts: _counts,
      elapsedMs: DateTime.now().difference(startedAt).inMilliseconds,
    );
  }

  /// Pre-approves the demo emails so they can sign up through the login screen.
  /// Each doc is keyed by the lowercase email (matches how AuthService looks
  /// up the registry). Seeded once; safe to run again.
  static const demoAccounts = <Map<String, String>>[
    {
      'email': 'admin.demo@intidemo.com',
      'name': 'Admin Demo',
      'role': 'admin',
      'studentId': 'ADMIN001',
      'programme': 'Staff',
      'year': '-',
    },
    {
      'email': 'ali.rahman@intidemo.com',
      'name': 'Ali Rahman',
      'role': 'student',
      'studentId': 'I24026254',
      'programme': 'BCSI',
      'year': 'Year 3',
    },
    {
      'email': 'aisha.tan@intidemo.com',
      'name': 'Aisha Tan',
      'role': 'student',
      'studentId': 'I24026255',
      'programme': 'BTDS',
      'year': 'Year 3',
    },
    {
      'email': 'ben.wong@intidemo.com',
      'name': 'Ben Wong',
      'role': 'student',
      'studentId': 'I24026256',
      'programme': 'BCSI',
      'year': 'Year 3',
    },
    {
      'email': 'priya.kaur@intidemo.com',
      'name': 'Priya Kaur',
      'role': 'student',
      'studentId': 'I24026257',
      'programme': 'BTDS',
      'year': 'Year 3',
    },
  ];

  Future<void> _seedStudentRegistry() async {
    for (final acc in demoAccounts) {
      final email = acc['email']!.toLowerCase();
      await _db.collection('studentRegistry').doc(email).set({
        'email': email,
        'name': acc['name'],
        'role': acc['role'],
        'studentId': acc['studentId'],
        'programme': acc['programme'],
        'year': acc['year'],
        'demo': true,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    _bump('studentRegistry', demoAccounts.length);
  }

  final Map<String, int> _counts = {};
  void _bump(String key, int by) => _counts[key] = (_counts[key] ?? 0) + by;

  // ---------------------------------------------------------- Timetable

  static const _timetable = <Map<String, dynamic>>[
    {
      'courseCode': 'PRG4201.1G1.JAN2026',
      'courseName': 'Concurrent & Real-Time Systems',
      'day': 'Monday',
      'startTime': '09:00',
      'endTime': '11:00',
      'room': 'A3-05',
      'lecturer': 'Dr Sarasvathi',
    },
    {
      'courseCode': 'PRG4205.8G1.AUG2025',
      'courseName': 'ERP Programming',
      'day': 'Tuesday',
      'startTime': '14:00',
      'endTime': '16:00',
      'room': 'Lab 2',
      'lecturer': 'Rechal',
    },
    {
      'courseCode': 'BDS3403.1DS1.JAN2026',
      'courseName': 'Machine Learning',
      'day': 'Wednesday',
      'startTime': '11:00',
      'endTime': '13:00',
      'room': 'A3-07',
      'lecturer': 'Dr Tan',
    },
    {
      'courseCode': 'IBM4202.8G1.AUG2025',
      'courseName': 'Web Programming',
      'day': 'Thursday',
      'startTime': '10:00',
      'endTime': '12:00',
      'room': 'Lab 5',
      'lecturer': 'Ms Wong',
    },
    {
      'courseCode': 'MPU3206.1C.JAN2026',
      'courseName': 'Community Service',
      'day': 'Friday',
      'startTime': '15:00',
      'endTime': '17:00',
      'room': 'LT A',
      'lecturer': 'Mr Ahmad',
    },
    {
      'courseCode': 'FYP4203.1G1.JAN2026',
      'courseName': 'Final Year Project I',
      'day': 'Monday',
      'startTime': '14:00',
      'endTime': '16:00',
      'room': 'A3-F02',
      'lecturer': 'Dr Sarasvathi',
    },
    {
      'courseCode': 'FYP4202.6G1.JUN2026',
      'courseName': 'Final Year Project II',
      'day': 'Wednesday',
      'startTime': '15:00',
      'endTime': '17:00',
      'room': 'A3-F02',
      'lecturer': 'Dr Sarasvathi',
    },
  ];

  Future<void> _seedTimetable(String userId) async {
    // Remove any prior seeded timetable for this user, then insert fresh.
    final existing = await _db
        .collection('timetable')
        .where('userId', isEqualTo: userId)
        .where('demo', isEqualTo: true)
        .get();
    for (final doc in existing.docs) {
      await doc.reference.delete();
    }

    for (final entry in _timetable) {
      await _db.collection('timetable').add({
        ...entry,
        'userId': userId,
        'type': 'class',
        'demo': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    _bump('timetable', _timetable.length);
  }

  Future<void> _seedAutoCourseContent(String userId) async {
    final courses = _timetable
        .map(
          (r) => StudentCourse(
            fullCode: r['courseCode'] as String,
            name: r['courseName'] as String,
          ),
        )
        .toList();

    final seed = CourseSeederService().buildFor(userId, courses);

    // Wipe previously auto-generated content, then write new.
    final oldR = await _db
        .collection('reminders')
        .where('userId', isEqualTo: userId)
        .where('auto', isEqualTo: true)
        .get();
    for (final d in oldR.docs) {
      await d.reference.delete();
    }
    final oldM = await _db
        .collection('resources')
        .where('userId', isEqualTo: userId)
        .where('auto', isEqualTo: true)
        .get();
    for (final d in oldM.docs) {
      await d.reference.delete();
    }

    for (final r in seed.reminders) {
      await _db.collection('reminders').add({
        ...r,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    for (final r in seed.resources) {
      await _db.collection('resources').add({
        ...r,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    _bump('reminders (auto)', seed.reminders.length);
    _bump('resources (auto)', seed.resources.length);
  }

  // ---------------------------------------------------------- Personal reminders

  Future<void> _seedReminders(String userId) async {
    final today = DateTime.now();
    String d(DateTime x) =>
        '${x.year.toString().padLeft(4, '0')}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';

    final rows = <Map<String, dynamic>>[
      {
        'title': 'Read PRG4201 lecture notes',
        'description': 'Chapters 3 and 4 before Monday class.',
        'courseCode': 'PRG4201',
        'reminderDate': d(today.subtract(const Duration(days: 2))),
        'reminderTime': '20:00',
      },
      {
        'title': 'ML tutorial submission',
        'description': 'Upload the regression exercise on Canvas.',
        'courseCode': 'BDS3403',
        'reminderDate': d(today),
        'reminderTime': '23:59',
      },
      {
        'title': 'Meet supervisor',
        'description': 'Weekly FYP progress meeting.',
        'courseCode': 'FYP4202',
        'reminderDate': d(today.add(const Duration(days: 1))),
        'reminderTime': '10:30',
      },
      {
        'title': 'Web Programming quiz',
        'description': 'Chapter 2 online quiz.',
        'courseCode': 'IBM4202',
        'reminderDate': d(today.add(const Duration(days: 3))),
        'reminderTime': '18:00',
      },
      {
        'title': 'Community service report',
        'description': 'Draft report for week 4 activity.',
        'courseCode': 'MPU3206',
        'reminderDate': d(today.add(const Duration(days: 5))),
        'reminderTime': '22:00',
      },
      {
        'title': 'Group project review',
        'description': 'Review teammate progress.',
        'courseCode': 'FYP4203',
        'reminderDate': d(today.add(const Duration(days: 7))),
        'reminderTime': '14:00',
      },
    ];

    // Remove previous personal seeded reminders (leave auto-ones alone).
    final existing = await _db
        .collection('reminders')
        .where('userId', isEqualTo: userId)
        .where('demo', isEqualTo: true)
        .get();
    for (final d in existing.docs) {
      await d.reference.delete();
    }

    for (final r in rows) {
      await _db.collection('reminders').add({
        ...r,
        'userId': userId,
        'status': 'active',
        'createdBy': 'demo',
        'demo': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    _bump('reminders (personal)', rows.length);
  }

  // ---------------------------------------------------------- Grades

  Future<void> _seedGrades(String userId) async {
    // A little history so CGPA has meaning.
    final rows = <Map<String, dynamic>>[
      {
        'code': 'PRG3101',
        'name': 'Introduction to Programming',
        'sem': 'AUG2024',
        'grade': 'A',
        'pt': 4.00,
        'cr': 3,
      },
      {
        'code': 'BDS3201',
        'name': 'Database Systems',
        'sem': 'AUG2024',
        'grade': 'A-',
        'pt': 3.67,
        'cr': 3,
      },
      {
        'code': 'MPU3113',
        'name': 'Malaysian Studies',
        'sem': 'AUG2024',
        'grade': 'B+',
        'pt': 3.33,
        'cr': 3,
      },
      {
        'code': 'BUS3301',
        'name': 'Business Ethics',
        'sem': 'AUG2024',
        'grade': 'B',
        'pt': 3.00,
        'cr': 3,
      },

      {
        'code': 'PRG3202',
        'name': 'Data Structures',
        'sem': 'JAN2025',
        'grade': 'A-',
        'pt': 3.67,
        'cr': 3,
      },
      {
        'code': 'BDS3302',
        'name': 'Statistics for Data Science',
        'sem': 'JAN2025',
        'grade': 'A',
        'pt': 4.00,
        'cr': 3,
      },
      {
        'code': 'PRG3303',
        'name': 'Object-Oriented Programming',
        'sem': 'JAN2025',
        'grade': 'B+',
        'pt': 3.33,
        'cr': 3,
      },
      {
        'code': 'MTH3101',
        'name': 'Discrete Mathematics',
        'sem': 'JAN2025',
        'grade': 'A-',
        'pt': 3.67,
        'cr': 3,
      },

      {
        'code': 'BDS3401',
        'name': 'Data Mining',
        'sem': 'AUG2025',
        'grade': 'A',
        'pt': 4.00,
        'cr': 3,
      },
      {
        'code': 'PRG3401',
        'name': 'Software Engineering',
        'sem': 'AUG2025',
        'grade': 'A-',
        'pt': 3.67,
        'cr': 3,
      },
      {
        'code': 'SEC3101',
        'name': 'Cybersecurity Foundations',
        'sem': 'AUG2025',
        'grade': 'B+',
        'pt': 3.33,
        'cr': 3,
      },
      {
        'code': 'MPU3222',
        'name': 'Ethnic Relations',
        'sem': 'AUG2025',
        'grade': 'A',
        'pt': 4.00,
        'cr': 2,
      },
    ];

    final existing = await _db
        .collection('grades')
        .where('userId', isEqualTo: userId)
        .where('demo', isEqualTo: true)
        .get();
    for (final d in existing.docs) {
      await d.reference.delete();
    }

    for (final r in rows) {
      await _db.collection('grades').add({
        'userId': userId,
        'courseCode': r['code'],
        'courseName': r['name'],
        'semester': r['sem'],
        'grade': r['grade'],
        'gradePoint': r['pt'],
        'creditHours': r['cr'],
        'demo': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    _bump('grades', rows.length);
  }

  // ---------------------------------------------------------- Calendar events

  Future<void> _seedCalendarEvents(String userId) async {
    final today = DateTime.now();
    String d(DateTime x) =>
        '${x.year.toString().padLeft(4, '0')}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';

    final rows = <Map<String, dynamic>>[
      {
        'title': 'ML study group',
        'date': d(today),
        'startTime': '19:00',
        'endTime': '21:00',
        'location': 'Library Level 2',
        'type': 'study',
        'courseCode': 'BDS3403',
        'notes': 'Revise week 3-4 topics.',
      },
      {
        'title': 'FYP supervisor meeting',
        'date': d(today.add(const Duration(days: 1))),
        'startTime': '10:30',
        'endTime': '11:00',
        'location': 'A3-F02',
        'type': 'meeting',
        'courseCode': 'FYP4202',
        'notes': 'Progress update.',
      },
      {
        'title': 'Web assignment work',
        'date': d(today.add(const Duration(days: 2))),
        'startTime': '20:00',
        'endTime': '22:00',
        'location': 'Home',
        'type': 'assignment',
        'courseCode': 'IBM4202',
        'notes': 'Finish frontend prototype.',
      },
      {
        'title': 'Coffee with Aisha',
        'date': d(today.add(const Duration(days: 3))),
        'startTime': '16:00',
        'endTime': '17:00',
        'location': 'Cafeteria',
        'type': 'personal',
        'courseCode': '',
        'notes': '',
      },
    ];

    final existing = await _db
        .collection('calendarEvents')
        .where('userId', isEqualTo: userId)
        .where('demo', isEqualTo: true)
        .get();
    for (final d in existing.docs) {
      await d.reference.delete();
    }

    for (final r in rows) {
      await _db.collection('calendarEvents').add({
        ...r,
        'userId': userId,
        'demo': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    _bump('calendarEvents', rows.length);
  }

  // ---------------------------------------------------------- Announcements

  Future<void> _seedAnnouncements(String userId) async {
    final rows = <Map<String, dynamic>>[
      {
        'id': 'demo_ann_1',
        'title': 'PRG4201 class cancelled Monday',
        'description':
            'Dear students, Monday PRG4201 lecture is cancelled due to a departmental meeting. Replacement class will be announced.',
        'category': 'Class Update',
        'priority': 'high',
        'targetProgramme': 'BCSI',
        'courseCode': 'PRG4201',
      },
      {
        'id': 'demo_ann_2',
        'title': 'Machine Learning group list released',
        'description':
            'Group allocations for BDS3403 project have been posted. Check the Materials tab for the PDF.',
        'category': 'Course',
        'priority': 'normal',
        'targetProgramme': 'BTDS',
        'courseCode': 'BDS3403',
      },
      {
        'id': 'demo_ann_3',
        'title': 'Final exam schedule Jan 2026',
        'description':
            'The final examination timetable for Jan 2026 semester is now available in Resources → Exam Timetable.',
        'category': 'Exam',
        'priority': 'high',
        'targetProgramme': 'All',
        'courseCode': '',
      },
      {
        'id': 'demo_ann_4',
        'title': 'Public holiday: Chinese New Year',
        'description':
            'Campus will be closed 17-18 February 2026. Classes resume 19 February.',
        'category': 'General',
        'priority': 'normal',
        'targetProgramme': 'All',
        'courseCode': '',
      },
      {
        'id': 'demo_ann_5',
        'title': 'ERP Programming assignment brief',
        'description':
            'Assignment 1 brief has been uploaded. Due next Wednesday 23:59.',
        'category': 'Assignment',
        'priority': 'normal',
        'targetProgramme': 'BCSI',
        'courseCode': 'PRG4205',
      },
      {
        'id': 'demo_ann_6',
        'title': 'FYP progress presentation',
        'description':
            'Final Year students must present progress in week 8. Slot booking opens next Monday.',
        'category': 'FYP',
        'priority': 'high',
        'targetProgramme': 'All',
        'courseCode': 'FYP4202',
      },
      {
        'id': 'demo_ann_7',
        'title': 'Library extended hours during exam week',
        'description':
            'Learning Resource Centre will remain open until 2 AM during exam week.',
        'category': 'General',
        'priority': 'normal',
        'targetProgramme': 'All',
        'courseCode': '',
      },
      {
        'id': 'demo_ann_8',
        'title': 'Web Programming quiz reminder',
        'description':
            'Online quiz for chapter 2 is available on Canvas until Sunday 23:59.',
        'category': 'Quiz',
        'priority': 'normal',
        'targetProgramme': 'BCSI',
        'courseCode': 'IBM4202',
      },
    ];

    for (final r in rows) {
      final id = r.remove('id') as String;
      await _db.collection('announcements').doc(id).set({
        ...r,
        'createdBy': userId,
        'source': 'demo',
        'demo': true,
        'expiredAt': '',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    _bump('announcements', rows.length);
  }

  // ---------------------------------------------------------- Events

  Future<void> _seedEvents(String userId) async {
    String d(DateTime x) =>
        '${x.year.toString().padLeft(4, '0')}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    final now = DateTime.now();

    final rows = <Map<String, dynamic>>[
      {
        'id': 'demo_ev_1',
        'title': 'INTI Virtual Career Fair 2026',
        'description': 'Meet 30+ top employers from Malaysia and abroad.',
        'eventDate': d(now.add(const Duration(days: 5))),
        'startTime': '09:00',
        'endTime': '17:00',
        'venue': 'Library',
        'clubName': 'Career Services',
        'posterUrl': 'asset:assets/images/event_posters/career_fair_2026.png',
      },
      {
        'id': 'demo_ev_2',
        'title': 'AI & Data Science Workshop',
        'description': 'Hands-on session with industry ML practitioners.',
        'eventDate': d(now.add(const Duration(days: 10))),
        'startTime': '14:00',
        'endTime': '17:00',
        'venue': 'A3-05',
        'clubName': 'FDSIT',
        'posterUrl':
            'asset:assets/images/event_posters/ai_data_science_workshop.png',
      },
      {
        'id': 'demo_ev_3',
        'title': 'Freshers Orientation Day',
        'description': 'Welcome session for new intake students.',
        'eventDate': d(now.add(const Duration(days: 14))),
        'startTime': '10:00',
        'endTime': '13:00',
        'venue': 'Lecture Theatre 1',
        'clubName': 'Student Affairs',
        'posterUrl':
            'asset:assets/images/event_posters/freshers_orientation_day.png',
      },
      {
        'id': 'demo_ev_4',
        'title': 'Inter-Faculty Sports Day',
        'description': 'Football, basketball, badminton and more.',
        'eventDate': d(now.add(const Duration(days: 21))),
        'startTime': '08:00',
        'endTime': '18:00',
        'venue': 'Sports Complex',
        'clubName': 'Sports Club',
        'posterUrl':
            'asset:assets/images/event_posters/inter_faculty_sports_day.png',
      },
      {
        'id': 'demo_ev_5',
        'title': 'Guest talk: Startups in Malaysia',
        'description': 'Panel with local founders and investors.',
        'eventDate': d(now.add(const Duration(days: 28))),
        'startTime': '15:00',
        'endTime': '17:00',
        'venue': 'LT A',
        'clubName': 'Entrepreneurs Club',
        'posterUrl':
            'asset:assets/images/event_posters/startups_in_malaysia.png',
      },
    ];

    for (final r in rows) {
      final id = r.remove('id') as String;
      await _db.collection('events').doc(id).set({
        ...r,
        'status': 'published',
        'createdBy': userId,
        'sourceProposalId': '',
        'demo': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    _bump('events', rows.length);
  }

  // ---------------------------------------------------------- Resources

  Future<void> _seedResources(String userId) async {
    final rows = <Map<String, dynamic>>[
      {
        'id': 'demo_res_1',
        'title': 'Canvas LMS student portal',
        'description': 'Log in to submit assignments and access materials.',
        'category': 'Learning',
        'courseCode': '',
        'linkUrl': 'https://newinti.instructure.com',
      },
      {
        'id': 'demo_res_2',
        'title': 'IU Digital Hub - Academic Calendar',
        'description': 'Semester dates, breaks and exam periods.',
        'category': 'Academic Calendar',
        'courseCode': '',
        'linkUrl':
            'https://sites.google.com/student.newinti.edu.my/iudigitalhub/resources/academic-calendar',
      },
      {
        'id': 'demo_res_3',
        'title': 'PRG4201 recommended textbook',
        'description': 'Concurrent Programming on Windows by Joe Duffy.',
        'category': 'Textbook',
        'courseCode': 'PRG4201',
        'linkUrl': '',
      },
      {
        'id': 'demo_res_4',
        'title': 'BDS3403 dataset repository',
        'description': 'Kaggle datasets used for ML tutorials.',
        'category': 'Dataset',
        'courseCode': 'BDS3403',
        'linkUrl': 'https://www.kaggle.com/datasets',
      },
      {
        'id': 'demo_res_5',
        'title': 'IBM4202 project starter template',
        'description': 'Boilerplate for web programming assignments.',
        'category': 'Template',
        'courseCode': 'IBM4202',
        'linkUrl': 'https://github.com',
      },
      {
        'id': 'demo_res_6',
        'title': 'FYP report template',
        'description': 'Word template used by all FYP students.',
        'category': 'FYP',
        'courseCode': 'FYP4202',
        'linkUrl': '',
      },
      {
        'id': 'demo_res_7',
        'title': 'Past year exam papers',
        'description': 'Archive of previous semester exams.',
        'category': 'Exam',
        'courseCode': '',
        'linkUrl':
            'https://sites.google.com/student.newinti.edu.my/iudigitalhub/resources/past-year-examination-papers',
      },
      {
        'id': 'demo_res_8',
        'title': 'Student handbook Jan 2026',
        'description': 'Programme and code of conduct.',
        'category': 'Handbook',
        'courseCode': '',
        'linkUrl':
            'https://sites.google.com/student.newinti.edu.my/iudigitalhub/resources/handbook',
      },
    ];

    for (final r in rows) {
      final id = r.remove('id') as String;
      await _db.collection('resources').doc(id).set({
        ...r,
        'fileUrl': '',
        'uploadedBy': userId,
        'demo': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    _bump('resources', rows.length);
  }

  // ---------------------------------------------------------- Notifications

  Future<void> _seedNotifications() async {
    final rows = <Map<String, dynamic>>[
      {
        'id': 'demo_notif_1',
        'title': 'New announcement: PRG4201 class cancelled',
        'body': 'Monday PRG4201 lecture is cancelled.',
        'type': 'announcement',
      },
      {
        'id': 'demo_notif_2',
        'title': 'Reminder: ML tutorial submission today',
        'body': 'Upload the regression exercise before 23:59.',
        'type': 'reminder',
      },
      {
        'id': 'demo_notif_3',
        'title': 'Event: Career Fair 2026',
        'body': 'Meet 30+ employers next week.',
        'type': 'event',
      },
      {
        'id': 'demo_notif_4',
        'title': 'BDS3403 group list released',
        'body': 'Check the Materials tab for your group.',
        'type': 'announcement',
      },
      {
        'id': 'demo_notif_5',
        'title': 'Timetable saved',
        'body': 'Your Jan 2026 timetable is set up.',
        'type': 'system',
      },
      {
        'id': 'demo_notif_6',
        'title': 'FYP supervisor meeting tomorrow',
        'body': '10:30 at A3-F02.',
        'type': 'reminder',
      },
    ];

    for (final r in rows) {
      final id = r.remove('id') as String;
      await _db.collection('notifications').doc(id).set({
        ...r,
        'audience': 'students',
        'demo': true,
        'readBy': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    _bump('notifications', rows.length);
  }

  // ---------------------------------------------------------- Locations

  Future<void> _seedLocations() async {
    final rows = <Map<String, dynamic>>[
      {
        'id': 'demo_loc_1',
        'name': 'Supervisor Office - Dr Sarasvathi',
        'building': 'Academic Block A',
        'level': 'Level 3',
        'room': 'A3-F02',
        'category': 'Office',
        'directionText':
            'Go to Academic Block A; take the lift to Level 3; follow the corridor to A3-F02.',
        'keywords': ['sarasvathi', 'fyp', 'supervisor', 'a3-f02'],
      },
      {
        'id': 'demo_loc_2',
        'name': 'Cafeteria',
        'building': 'Student Centre',
        'level': 'Ground Floor',
        'room': 'Cafeteria',
        'category': 'Facility',
        'directionText':
            'Go to Student Centre; enter through the main entrance; cafeteria is on the ground floor.',
        'keywords': ['food', 'cafeteria', 'canteen', 'lunch'],
      },
      {
        'id': 'demo_loc_3',
        'name': 'Finance Office',
        'building': 'Academic Block D',
        'level': 'Level 1',
        'room': 'Finance',
        'category': 'Support',
        'directionText':
            'Head to Academic Block D Level 1; finance counter is next to admissions.',
        'keywords': ['finance', 'fee', 'payment', 'block d'],
      },
      {
        'id': 'demo_loc_4',
        'name': 'Clinic',
        'building': 'Student Centre',
        'level': 'Level 1',
        'room': 'Health Clinic',
        'category': 'Facility',
        'directionText':
            'Student Centre Level 1; look for the health services signboard.',
        'keywords': ['clinic', 'health', 'sick', 'nurse'],
      },
    ];

    for (final r in rows) {
      final id = r.remove('id') as String;
      await _db.collection('locations').doc(id).set({
        ...r,
        'demo': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    _bump('locations', rows.length);
  }
}

class DemoSeedResult {
  final Map<String, int> counts;
  final int elapsedMs;
  DemoSeedResult({required this.counts, required this.elapsedMs});
}
