import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_service.dart';
import 'iu_digital_hub_service.dart';

enum AgentNavigationTarget {
  announcements,
  resources,
  timetable,
  reminders,
  locations,
  events,
}

class AIAgentReply {
  final String text;
  final AgentNavigationTarget? navigationTarget;
  final String? actionLabel;
  final String query;

  const AIAgentReply({
    required this.text,
    this.navigationTarget,
    this.actionLabel,
    this.query = '',
  });
}

class AIAgentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();

  Future<AIAgentReply> handleMessage({
    required String userId,
    required String message,
  }) async {
    final input = _stripWakeWord(message.trim());
    final lower = input.toLowerCase();

    if (input.isEmpty) {
      return const AIAgentReply(text: 'Please type or say something first.');
    }

    if (_isGreeting(lower)) {
      return const AIAgentReply(
        text:
            'Hi, I am Canva. I can help with reminders, weekly study planning, Digital Hub resources, timetable, announcements, events, and campus navigation.',
      );
    }

    if (!_isCampusTask(lower)) {
      return const AIAgentReply(
        text:
            'That is outside my campus support scope. I can only help with education and this app: reminders, due dates, timetable, announcements, events, resources, and campus navigation.',
      );
    }

    if (_isWeeklyPlanningIntent(lower)) {
      return await _getThisWeekPlan(userId);
    }
    if (_isReminderIntent(lower)) {
      return await _createReminderFromText(userId: userId, text: input);
    }
    if (_isResourceIntent(lower)) return await _searchResources(input);
    if (_isLocationIntent(lower)) return await _searchLocations(input);
    if (_isAnnouncementIntent(lower)) return await _getAnnouncements();
    if (_isEventIntent(lower)) return await _getEvents();
    if (_isTimetableIntent(lower)) return await _getTimetable(userId);
    if (_isShowReminderIntent(lower)) return await _getReminders(userId);

    return const AIAgentReply(
      text:
          'I can help with campus tasks only. Try: "Canva, set a reminder for my assignment tomorrow 10 pm" or "What should I do this week?"',
    );
  }

  String _stripWakeWord(String message) {
    return message
        .replaceFirst(
          RegExp(r'^\s*(hey|hi|hello)?\s*canva[:,]?\s*', caseSensitive: false),
          '',
        )
        .trim();
  }

  bool _isGreeting(String t) {
    return ['hi', 'hello', 'hey', 'canva'].contains(t.trim());
  }

  bool _isCampusTask(String t) {
    return _isReminderIntent(t) ||
        _isShowReminderIntent(t) ||
        _isWeeklyPlanningIntent(t) ||
        _isResourceIntent(t) ||
        _isLocationIntent(t) ||
        _isAnnouncementIntent(t) ||
        _isEventIntent(t) ||
        _isTimetableIntent(t) ||
        [
          'campus',
          'class',
          'course',
          'assignment',
          'test',
          'exam',
          'student',
          'inti',
          'iu digital hub',
          'canvas',
          'library',
          'finance',
          'registry',
          'counselling',
        ].any(t.contains);
  }

  bool _isReminderIntent(String t) {
    return t.contains('remind me') ||
        t.contains('set reminder') ||
        t.contains('create reminder') ||
        t.contains('add reminder') ||
        t.contains('set alarm') ||
        (t.contains('calendar') &&
            (t.contains('add') || t.contains('set') || t.contains('create')));
  }

  bool _isShowReminderIntent(String t) {
    return t.contains('show reminder') ||
        t.contains('my reminder') ||
        t.contains('reminders');
  }

  bool _isWeeklyPlanningIntent(String t) {
    return (t.contains('this week') || t.contains('upcoming')) &&
        (t.contains('due') ||
            t.contains('deadline') ||
            t.contains('what should') ||
            t.contains('what to do') ||
            t.contains('plan'));
  }

  bool _isResourceIntent(String t) {
    return t.contains('material') ||
        t.contains('resource') ||
        t.contains('course outline') ||
        t.contains('past year') ||
        t.contains('paper') ||
        t.contains('academic calendar') ||
        t.contains('form') ||
        t.contains('handbook') ||
        t.contains('digital hub') ||
        t.contains('canvas') ||
        t.contains('library') ||
        t.contains('office 365') ||
        t.contains('email');
  }

  bool _isLocationIntent(String t) {
    return t.contains('where') ||
        t.contains('location') ||
        t.contains('go to') ||
        t.contains('find room') ||
        t.contains('direction') ||
        t.contains('navigate');
  }

  bool _isAnnouncementIntent(String t) {
    return t.contains('announcement') ||
        t.contains('notice') ||
        t.contains('update');
  }

  bool _isEventIntent(String t) {
    return t.contains('event') ||
        t.contains('activity') ||
        t.contains('happening');
  }

  bool _isTimetableIntent(String t) {
    return t.contains('timetable') ||
        t.contains('class schedule') ||
        t.contains('lecture schedule');
  }

  Future<AIAgentReply> _createReminderFromText({
    required String userId,
    required String text,
  }) async {
    final courseCode = _extractCourseCode(text);
    final date = _extractDate(text);
    final time = _extractTime(text);
    final title = _buildReminderTitle(text, courseCode);

    await _firestoreService.createReminder(
      userId: userId,
      title: title,
      description: text,
      courseCode: courseCode,
      reminderDate: date,
      reminderTime: time,
      createdBy: 'canva_agent',
    );

    final response = 'Done. I created "$title" on $date at $time.';
    await _saveChat(
      userId: userId,
      userMessage: text,
      detectedIntent: 'create_reminder',
      agentAction: 'create_reminder',
      aiResponse: response,
    );

    return AIAgentReply(
      text: response,
      navigationTarget: AgentNavigationTarget.reminders,
      actionLabel: 'Open Reminders',
    );
  }

  Future<AIAgentReply> _searchResources(String input) async {
    final snapshot = await _db.collection('resources').get();
    final lower = input.toLowerCase();
    final words = lower.split(RegExp(r'\s+')).where((w) => w.length > 2);
    final items = <DigitalHubResource>[
      ...IUDigitalHubService.fallbackResources,
      ...snapshot.docs.map((doc) => DigitalHubResource.fromMap(doc.data())),
    ];

    final matches = items.where((item) {
      if (item.matches(input)) return true;
      return words.any((word) => item.title.toLowerCase().contains(word));
    }).toList();

    if (matches.isEmpty) {
      return const AIAgentReply(
        text:
            'I could not find a matching campus resource. Try asking for Canvas, academic calendar, forms, exam timetable, library, or a course code.',
        navigationTarget: AgentNavigationTarget.resources,
        actionLabel: 'Open Resources',
      );
    }

    final buffer = StringBuffer('I found these campus resources:\n');
    for (final item in matches.take(5)) {
      buffer.writeln('- ${item.title} (${item.category})');
      buffer.writeln('  ${item.url}');
    }

    return AIAgentReply(
      text: buffer.toString().trimRight(),
      navigationTarget: AgentNavigationTarget.resources,
      actionLabel: 'Open Resources',
      query: _extractCourseCode(input).isNotEmpty
          ? _extractCourseCode(input)
          : input,
    );
  }

  Future<AIAgentReply> _searchLocations(String input) async {
    final snapshot = await _db.collection('locations').get();
    final lower = input.toLowerCase();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final name = (data['name'] ?? '').toString().toLowerCase();
      final building = (data['building'] ?? '').toString().toLowerCase();
      final room = (data['room'] ?? '').toString().toLowerCase();
      final keywords = List<String>.from(data['keywords'] ?? []);
      final keywordMatch = keywords.any((k) => lower.contains(k.toLowerCase()));
      if (lower.contains(name) ||
          lower.contains(building) ||
          lower.contains(room) ||
          keywordMatch) {
        return AIAgentReply(
          text:
              '${data['name'] ?? 'Location'}\nBuilding: ${data['building'] ?? '-'}\nLevel: ${data['level'] ?? '-'}\nRoom: ${data['room'] ?? '-'}\n\n${data['directionText'] ?? 'No direction available.'}',
          navigationTarget: AgentNavigationTarget.locations,
          actionLabel: 'Open Navigation',
          query: input,
        );
      }
    }

    return const AIAgentReply(
      text:
          'I could not find that campus location. Try asking: Where is Finance Office?',
      navigationTarget: AgentNavigationTarget.locations,
      actionLabel: 'Open Navigation',
    );
  }

  Future<AIAgentReply> _getAnnouncements() async {
    final snapshot = await _db
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .get();
    if (snapshot.docs.isEmpty) {
      return const AIAgentReply(text: 'No announcements are available now.');
    }

    final buffer = StringBuffer('Latest announcements:\n');
    for (final doc in snapshot.docs) {
      final data = doc.data();
      buffer.writeln(
        '- ${data['title'] ?? 'Untitled'} (${data['priority'] ?? 'normal'})',
      );
    }
    return AIAgentReply(
      text: buffer.toString().trimRight(),
      navigationTarget: AgentNavigationTarget.announcements,
      actionLabel: 'Open Announcements',
    );
  }

  Future<AIAgentReply> _getEvents() async {
    final snapshot = await _db.collection('events').limit(5).get();
    if (snapshot.docs.isEmpty) {
      return const AIAgentReply(text: 'No events are available now.');
    }

    final buffer = StringBuffer('Upcoming events:\n');
    for (final doc in snapshot.docs) {
      final data = doc.data();
      buffer.writeln(
        '- ${data['title'] ?? 'Untitled'} on ${data['eventDate'] ?? '-'}',
      );
    }
    return AIAgentReply(
      text: buffer.toString().trimRight(),
      navigationTarget: AgentNavigationTarget.events,
      actionLabel: 'Open Events',
    );
  }

  Future<AIAgentReply> _getTimetable(String userId) async {
    final snapshot = await _db
        .collection('timetable')
        .where('userId', isEqualTo: userId)
        .get();
    if (snapshot.docs.isEmpty) {
      return const AIAgentReply(text: 'I could not find your timetable yet.');
    }

    final buffer = StringBuffer('Your timetable:\n');
    for (final doc in snapshot.docs) {
      final data = doc.data();
      buffer.writeln(
        '- ${data['courseCode'] ?? ''} ${data['courseName'] ?? ''}: ${data['day'] ?? '-'} ${data['startTime'] ?? '-'}-${data['endTime'] ?? '-'} at ${data['room'] ?? '-'}',
      );
    }
    return AIAgentReply(
      text: buffer.toString().trimRight(),
      navigationTarget: AgentNavigationTarget.timetable,
      actionLabel: 'Open Timetable',
    );
  }

  Future<AIAgentReply> _getReminders(String userId) async {
    final snapshot = await _db
        .collection('reminders')
        .where('userId', isEqualTo: userId)
        .get();
    if (snapshot.docs.isEmpty) {
      return const AIAgentReply(text: 'You do not have reminders yet.');
    }

    final rows = snapshot.docs.map((doc) => doc.data()).toList()
      ..sort((a, b) {
        final left = '${a['reminderDate'] ?? ''} ${a['reminderTime'] ?? ''}';
        final right = '${b['reminderDate'] ?? ''} ${b['reminderTime'] ?? ''}';
        return left.compareTo(right);
      });

    final buffer = StringBuffer('Your reminders:\n');
    for (final data in rows.take(8)) {
      buffer.writeln(
        '- ${data['title'] ?? 'Reminder'}: ${data['reminderDate'] ?? '-'} at ${data['reminderTime'] ?? '-'}',
      );
    }

    return AIAgentReply(
      text: buffer.toString().trimRight(),
      navigationTarget: AgentNavigationTarget.reminders,
      actionLabel: 'Open Reminders',
    );
  }

  Future<AIAgentReply> _getThisWeekPlan(String userId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endOfWeek = today.add(
      Duration(days: DateTime.sunday - today.weekday),
    );
    final reminders = await _db
        .collection('reminders')
        .where('userId', isEqualTo: userId)
        .get();
    final timetable = await _db
        .collection('timetable')
        .where('userId', isEqualTo: userId)
        .get();

    final dueThisWeek =
        reminders.docs.map((doc) => doc.data()).where((data) {
          final date = _parseStoredDate(
            (data['reminderDate'] ?? '').toString(),
          );
          if (date == null) return false;
          return !date.isBefore(today) && !date.isAfter(endOfWeek);
        }).toList()..sort((a, b) {
          final left = '${a['reminderDate'] ?? ''} ${a['reminderTime'] ?? ''}';
          final right = '${b['reminderDate'] ?? ''} ${b['reminderTime'] ?? ''}';
          return left.compareTo(right);
        });

    final buffer = StringBuffer('Here is your plan for this week:\n');
    if (dueThisWeek.isEmpty) {
      buffer.writeln(
        '- No reminder due dates are saved for the rest of this week.',
      );
    } else {
      for (final data in dueThisWeek.take(8)) {
        buffer.writeln(
          '- ${data['title'] ?? 'Reminder'}: ${data['reminderDate'] ?? '-'} at ${data['reminderTime'] ?? '-'}',
        );
      }
    }

    if (timetable.docs.isNotEmpty) {
      buffer.writeln('\nClasses to keep in mind:');
      for (final doc in timetable.docs.take(6)) {
        final data = doc.data();
        buffer.writeln(
          '- ${data['courseCode'] ?? ''} ${data['courseName'] ?? ''}: ${data['day'] ?? '-'} ${data['startTime'] ?? '-'}',
        );
      }
    }

    buffer.writeln(
      '\nBest next step: finish the earliest due item first, then review the timetable for classes before Sunday.',
    );

    return AIAgentReply(
      text: buffer.toString().trimRight(),
      navigationTarget: AgentNavigationTarget.reminders,
      actionLabel: 'Open Reminders',
    );
  }

  String _buildReminderTitle(String text, String courseCode) {
    final task = _guessTaskType(text);
    if (courseCode.isNotEmpty) return '$courseCode $task';
    return task == 'Reminder' ? 'Campus Reminder' : task;
  }

  String _guessTaskType(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('assignment')) return 'Assignment';
    if (lower.contains('deadline') || lower.contains('due')) return 'Due Date';
    if (lower.contains('exam')) return 'Exam';
    if (lower.contains('test') || lower.contains('quiz')) return 'Class Test';
    if (lower.contains('class')) return 'Class';
    if (lower.contains('meeting')) return 'Meeting';
    return 'Reminder';
  }

  String _extractCourseCode(String text) {
    final compactMatch = RegExp(
      r'\b[A-Za-z]{2,4}\s?\d{3,4}\b',
    ).firstMatch(text);
    return compactMatch?.group(0)?.replaceAll(' ', '').toUpperCase() ?? '';
  }

  String _extractDate(String text) {
    final lower = text.toLowerCase();
    final now = DateTime.now();

    final isoMatch = RegExp(
      r'\b(20\d{2})-(\d{1,2})-(\d{1,2})\b',
    ).firstMatch(text);
    if (isoMatch != null) {
      return _formatDate(
        DateTime(
          int.parse(isoMatch.group(1)!),
          int.parse(isoMatch.group(2)!),
          int.parse(isoMatch.group(3)!),
        ),
      );
    }

    if (lower.contains('tomorrow')) {
      return _formatDate(now.add(const Duration(days: 1)));
    }
    if (lower.contains('today')) return _formatDate(now);

    final monthMatch = RegExp(
      r'\b(\d{1,2})(?:st|nd|rd|th)?(?:\s+of)?\s+(jan|january|feb|february|mar|march|apr|april|may|jun|june|jul|july|aug|august|sep|sept|september|oct|october|nov|november|dec|december)(?:\s+(20\d{2}))?\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (monthMatch != null) {
      final day = int.parse(monthMatch.group(1)!);
      final month = _monthNumber(monthMatch.group(2)!);
      var year = int.tryParse(monthMatch.group(3) ?? '') ?? now.year;
      var parsed = DateTime(year, month, day);
      if (parsed.isBefore(DateTime(now.year, now.month, now.day))) {
        parsed = DateTime(++year, month, day);
      }
      return _formatDate(parsed);
    }

    final weekdays = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };
    for (final entry in weekdays.entries) {
      if (lower.contains(entry.key))
        return _formatDate(_nextWeekday(now, entry.value));
    }

    return _formatDate(now);
  }

  int _monthNumber(String value) {
    const months = {
      'jan': 1,
      'january': 1,
      'feb': 2,
      'february': 2,
      'mar': 3,
      'march': 3,
      'apr': 4,
      'april': 4,
      'may': 5,
      'jun': 6,
      'june': 6,
      'jul': 7,
      'july': 7,
      'aug': 8,
      'august': 8,
      'sep': 9,
      'sept': 9,
      'september': 9,
      'oct': 10,
      'october': 10,
      'nov': 11,
      'november': 11,
      'dec': 12,
      'december': 12,
    };
    return months[value.toLowerCase()] ?? DateTime.now().month;
  }

  String _extractTime(String text) {
    final amPmMatch = RegExp(
      r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (amPmMatch != null) {
      return _formatTime(
        int.parse(amPmMatch.group(1)!),
        int.tryParse(amPmMatch.group(2) ?? '0') ?? 0,
        amPmMatch.group(3)!.toLowerCase(),
      );
    }

    final periodMatch = RegExp(
      r'\b(morning|afternoon|evening|night)\s+(\d{1,2})(?::(\d{2}))?\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (periodMatch != null) {
      final period = periodMatch.group(1)!.toLowerCase();
      var hour = int.parse(periodMatch.group(2)!);
      final minute = int.tryParse(periodMatch.group(3) ?? '0') ?? 0;
      if ((period == 'afternoon' || period == 'evening' || period == 'night') &&
          hour < 12) {
        hour += 12;
      }
      return _timeString(hour, minute);
    }

    return '09:00';
  }

  String _formatTime(int hour, int minute, String ampm) {
    var adjustedHour = hour;
    if (ampm == 'pm' && adjustedHour < 12) {
      adjustedHour += 12;
    }
    if (ampm == 'am' && adjustedHour == 12) {
      adjustedHour = 0;
    }
    return _timeString(adjustedHour, minute);
  }

  String _timeString(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  DateTime _nextWeekday(DateTime from, int weekday) {
    var daysToAdd = weekday - from.weekday;
    if (daysToAdd <= 0) daysToAdd += 7;
    return from.add(Duration(days: daysToAdd));
  }

  DateTime? _parseStoredDate(String value) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _saveChat({
    required String userId,
    required String userMessage,
    required String detectedIntent,
    required String agentAction,
    required String aiResponse,
  }) async {
    await _db.collection('chatHistory').add({
      'userId': userId,
      'userMessage': userMessage,
      'detectedIntent': detectedIntent,
      'agentAction': agentAction,
      'aiResponse': aiResponse,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
