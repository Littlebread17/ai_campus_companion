import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

class AIAgentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();

  Future<String> handleMessage({required String userId, required String message}) async {
    final input = message.trim();
    final lower = input.toLowerCase();

    if (input.isEmpty) return 'Please type or say something first.';

    if (_isReminderIntent(lower)) return await _createReminderFromText(userId: userId, text: input);
    if (_isResourceIntent(lower)) return await _searchResources(input);
    if (_isLocationIntent(lower)) return await _searchLocations(input);
    if (_isAnnouncementIntent(lower)) return await _getAnnouncements();
    if (_isEventIntent(lower)) return await _getEvents();
    if (_isTimetableIntent(lower)) return await _getTimetable(userId);

    return 'I am your AI Campus Agent. I can only help with campus tasks: reminders, resources, timetable, announcements, events, and navigation.';
  }

  bool _isReminderIntent(String t) => t.contains('remind') || t.contains('reminder') || t.contains('set alarm');
  bool _isResourceIntent(String t) => t.contains('material') || t.contains('resource') || t.contains('course outline') || t.contains('past year') || t.contains('paper') || t.contains('calendar') || t.contains('form');
  bool _isLocationIntent(String t) => t.contains('where') || t.contains('location') || t.contains('go to') || t.contains('find room') || t.contains('direction') || t.contains('navigate');
  bool _isAnnouncementIntent(String t) => t.contains('announcement') || t.contains('notice') || t.contains('update');
  bool _isEventIntent(String t) => t.contains('event') || t.contains('activity') || t.contains('happening');
  bool _isTimetableIntent(String t) => t.contains('timetable') || t.contains('class') || t.contains('schedule') || t.contains('lecture');

  Future<String> _createReminderFromText({required String userId, required String text}) async {
    final courseCode = _extractCourseCode(text);
    final date = _extractDate(text);
    final time = _extractTime(text);
    final title = courseCode.isEmpty ? 'Campus Reminder' : '$courseCode Reminder';

    await _firestoreService.createReminder(
      userId: userId,
      title: title,
      description: text,
      courseCode: courseCode,
      reminderDate: date,
      reminderTime: time,
      createdBy: 'ai_agent',
    );

    await _saveChat(userId: userId, userMessage: text, detectedIntent: 'create_reminder', agentAction: 'create_reminder', aiResponse: 'Reminder created: $title on $date at $time.');
    return 'Done. I created a reminder for "$title" on $date at $time.';
  }

  Future<String> _searchResources(String input) async {
    final snapshot = await _db.collection('resources').get();
    final lower = input.toLowerCase();
    final words = lower.split(' ').where((w) => w.length > 2).toList();

    final matches = snapshot.docs.where((doc) {
      final data = doc.data();
      final title = (data['title'] ?? '').toString().toLowerCase();
      final category = (data['category'] ?? '').toString().toLowerCase();
      final courseCode = (data['courseCode'] ?? '').toString().toLowerCase();
      return (courseCode.isNotEmpty && lower.contains(courseCode)) || lower.contains(category) || words.any((word) => title.contains(word));
    }).toList();

    if (matches.isEmpty) return 'I could not find matching resources. Try asking with a course code, for example: Find ITM3206 course outline.';

    final buffer = StringBuffer('I found these resources:\n');
    for (final doc in matches.take(5)) {
      final data = doc.data();
      buffer.writeln('- ${data['title'] ?? 'Untitled'}');
      final link = (data['linkUrl'] ?? data['fileUrl'] ?? '').toString();
      if (link.isNotEmpty) buffer.writeln('  Link: $link');
    }
    return buffer.toString();
  }

  Future<String> _searchLocations(String input) async {
    final snapshot = await _db.collection('locations').get();
    final lower = input.toLowerCase();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final name = (data['name'] ?? '').toString().toLowerCase();
      final building = (data['building'] ?? '').toString().toLowerCase();
      final room = (data['room'] ?? '').toString().toLowerCase();
      final keywords = List<String>.from(data['keywords'] ?? []);
      final keywordMatch = keywords.any((k) => lower.contains(k.toLowerCase()));
      if (lower.contains(name) || lower.contains(building) || lower.contains(room) || keywordMatch) {
        return '${data['name'] ?? 'Location'}\nBuilding: ${data['building'] ?? '-'}\nLevel: ${data['level'] ?? '-'}\nRoom: ${data['room'] ?? '-'}\n\n${data['directionText'] ?? 'No direction available.'}';
      }
    }
    return 'I could not find that campus location. Try asking: Where is Finance Office?';
  }

  Future<String> _getAnnouncements() async {
    final snapshot = await _db.collection('announcements').orderBy('createdAt', descending: true).limit(5).get();
    if (snapshot.docs.isEmpty) return 'No announcements are available now.';
    final buffer = StringBuffer('Latest announcements:\n');
    for (final doc in snapshot.docs) {
      final data = doc.data();
      buffer.writeln('- ${data['title'] ?? 'Untitled'} (${data['priority'] ?? 'normal'})');
    }
    return buffer.toString();
  }

  Future<String> _getEvents() async {
    final snapshot = await _db.collection('events').limit(5).get();
    if (snapshot.docs.isEmpty) return 'No events are available now.';
    final buffer = StringBuffer('Upcoming events:\n');
    for (final doc in snapshot.docs) {
      final data = doc.data();
      buffer.writeln('- ${data['title'] ?? 'Untitled'} on ${data['eventDate'] ?? '-'}');
    }
    return buffer.toString();
  }

  Future<String> _getTimetable(String userId) async {
    final snapshot = await _db.collection('timetable').where('userId', isEqualTo: userId).get();
    if (snapshot.docs.isEmpty) return 'I could not find your timetable yet.';
    final buffer = StringBuffer('Your timetable:\n');
    for (final doc in snapshot.docs) {
      final data = doc.data();
      buffer.writeln('- ${data['courseCode'] ?? ''} ${data['courseName'] ?? ''}: ${data['day'] ?? '-'} ${data['startTime'] ?? '-'}-${data['endTime'] ?? '-'} at ${data['room'] ?? '-'}');
    }
    return buffer.toString();
  }

  String _extractCourseCode(String text) => RegExp(r'\b[A-Za-z]{2,4}\d{3,4}\b').firstMatch(text)?.group(0)?.toUpperCase() ?? '';

  String _extractDate(String text) {
    final lower = text.toLowerCase();
    final now = DateTime.now();
    if (lower.contains('tomorrow')) return _formatDate(now.add(const Duration(days: 1)));
    final weekdays = {'monday': DateTime.monday, 'tuesday': DateTime.tuesday, 'wednesday': DateTime.wednesday, 'thursday': DateTime.thursday, 'friday': DateTime.friday, 'saturday': DateTime.saturday, 'sunday': DateTime.sunday};
    for (final entry in weekdays.entries) {
      if (lower.contains(entry.key)) return _formatDate(_nextWeekday(now, entry.value));
    }
    return _formatDate(now);
  }

  String _extractTime(String text) {
    final match = RegExp(r'\b(\d{1,2})(:\d{2})?\s*(am|pm)?\b', caseSensitive: false).firstMatch(text);
    if (match == null) return '09:00';
    var hour = int.tryParse(match.group(1) ?? '9') ?? 9;
    final minute = int.tryParse((match.group(2) ?? ':00').replaceAll(':', '')) ?? 0;
    final ampm = (match.group(3) ?? '').toLowerCase();
    if (ampm == 'pm' && hour < 12) hour += 12;
    if (ampm == 'am' && hour == 12) hour = 0;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  DateTime _nextWeekday(DateTime from, int weekday) {
    var daysToAdd = weekday - from.weekday;
    if (daysToAdd <= 0) daysToAdd += 7;
    return from.add(Duration(days: daysToAdd));
  }

  String _formatDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _saveChat({required String userId, required String userMessage, required String detectedIntent, required String agentAction, required String aiResponse}) async {
    await _db.collection('chatHistory').add({'userId': userId, 'userMessage': userMessage, 'detectedIntent': detectedIntent, 'agentAction': agentAction, 'aiResponse': aiResponse, 'createdAt': FieldValue.serverTimestamp()});
  }
}
