import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/firestore_service.dart';
import '../utils/course_utils.dart';
import 'locations_screen.dart';

/// A unified item shown on the calendar for a given day.
class _DayItem {
  final String start;
  final String end;
  final String title;
  final String venue;
  final Color color;
  final bool isClass;
  final String type;
  final String? eventId; // set for editable personal events

  const _DayItem({
    required this.start,
    required this.end,
    required this.title,
    required this.venue,
    required this.color,
    required this.isClass,
    this.type = 'class',
    this.eventId,
  });
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _service = FirestoreService();
  DateTime _selected = DateTime.now();

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _weekday => DateFormat('EEEE').format(_selected);
  String get _dateKey => DateFormat('yyyy-MM-dd').format(_selected);

  static const _typeMeta = {
    'class': (Icons.school, Color(0xff2563eb)),
    'meeting': (Icons.groups, Color(0xff7c3aed)),
    'assignment': (Icons.assignment_turned_in, Color(0xffdc2626)),
    'study': (Icons.menu_book, Color(0xff16a34a)),
    'personal': (Icons.event_note, Color(0xff0891b2)),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Calendar'),
        actions: [
          IconButton(
            tooltip: 'Pick date',
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickDate,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editEvent(),
        icon: const Icon(Icons.add),
        label: const Text('Add event'),
      ),
      body: Column(
        children: [
          _weekStrip(),
          const Divider(height: 1),
          Expanded(child: _agenda()),
        ],
      ),
    );
  }

  Widget _weekStrip() {
    final startOfWeek = _selected.subtract(
      Duration(days: _selected.weekday - 1),
    );
    return SizedBox(
      height: 78,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: 14,
        itemBuilder: (context, index) {
          final day = startOfWeek.add(Duration(days: index));
          final isSel = DateUtils.isSameDay(day, _selected);
          final isToday = DateUtils.isSameDay(day, DateTime.now());
          return GestureDetector(
            onTap: () => setState(() => _selected = day),
            child: Container(
              width: 52,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSel ? const Color(0xff2563eb) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isToday && !isSel
                      ? const Color(0xff2563eb)
                      : const Color(0xffdfe7f3),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(day),
                    style: TextStyle(
                      fontSize: 11,
                      color: isSel ? Colors.white70 : const Color(0xff64748b),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isSel ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _agenda() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.streamUserTimetable(_userId),
      builder: (context, ttSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _service.streamUserCalendarEvents(_userId),
          builder: (context, evSnap) {
            if (!ttSnap.hasData || !evSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = _buildItems(ttSnap.data!.docs, evSnap.data!.docs);
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Nothing scheduled for\n${DateFormat('EEEE, d MMM').format(_selected)}.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: items.length,
              itemBuilder: (context, i) => _itemTile(items[i]),
            );
          },
        );
      },
    );
  }

  List<_DayItem> _buildItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> ttDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> evDocs,
  ) {
    final items = <_DayItem>[];

    for (final doc in ttDocs) {
      final d = doc.data();
      if ((d['day'] ?? '').toString() != _weekday) continue;
      final code = (d['courseCode'] ?? '').toString();
      items.add(
        _DayItem(
          start: (d['startTime'] ?? '').toString(),
          end: (d['endTime'] ?? '').toString(),
          title:
              '${d['courseCode'] ?? ''}  ${d['courseName'] ?? ''}'.trim(),
          venue: (d['room'] ?? '').toString(),
          color: CourseUtils.colorFor(code),
          isClass: true,
        ),
      );
    }

    for (final doc in evDocs) {
      final d = doc.data();
      if ((d['date'] ?? '').toString() != _dateKey) continue;
      final type = (d['type'] ?? 'personal').toString();
      final meta = _typeMeta[type] ?? _typeMeta['personal']!;
      items.add(
        _DayItem(
          start: (d['startTime'] ?? '').toString(),
          end: (d['endTime'] ?? '').toString(),
          title: (d['title'] ?? 'Event').toString(),
          venue: (d['location'] ?? '').toString(),
          color: meta.$2,
          isClass: false,
          type: type,
          eventId: doc.id,
        ),
      );
    }

    items.sort((a, b) => a.start.compareTo(b.start));
    return items;
  }

  Widget _itemTile(_DayItem item) {
    final meta = _typeMeta[item.type] ?? _typeMeta['class']!;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              item.start.isEmpty ? '--' : item.start,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              item.end,
              style: const TextStyle(fontSize: 11, color: Color(0xff64748b)),
            ),
          ],
        ),
        title: Row(
          children: [
            Container(width: 4, height: 36, color: item.color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Row(
                    children: [
                      Icon(meta.$1, size: 13, color: item.color),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.venue.isEmpty
                              ? (item.isClass ? 'Class' : item.type)
                              : item.venue,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xff64748b),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        trailing: item.isClass
            ? (item.venue.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Navigate',
                    icon: const Icon(Icons.near_me),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            LocationsScreen(initialQuery: item.venue),
                      ),
                    ),
                  ))
            : PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _editEvent(eventId: item.eventId);
                  if (v == 'delete') _deleteEvent(item.eventId!);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime.now().subtract(const Duration(days: 180)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selected = picked);
  }

  Future<void> _deleteEvent(String id) async {
    await _service.deleteCalendarEvent(id);
  }

  Future<void> _editEvent({String? eventId}) async {
    Map<String, dynamic> existing = {};
    if (eventId != null) {
      final doc = await FirebaseFirestore.instance
          .collection('calendarEvents')
          .doc(eventId)
          .get();
      existing = doc.data() ?? {};
    }

    final title = TextEditingController(text: existing['title'] ?? '');
    final location = TextEditingController(text: existing['location'] ?? '');
    final start = TextEditingController(text: existing['startTime'] ?? '');
    final end = TextEditingController(text: existing['endTime'] ?? '');
    final notes = TextEditingController(text: existing['notes'] ?? '');
    final courseCode = TextEditingController(text: existing['courseCode'] ?? '');
    var type = (existing['type'] ?? 'meeting').toString();

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(eventId == null ? 'Add event' : 'Edit event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'On ${DateFormat('EEEE, d MMM yyyy').format(_selected)}',
                  style: const TextStyle(color: Color(0xff64748b)),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'meeting', child: Text('Meeting')),
                    DropdownMenuItem(
                      value: 'assignment',
                      child: Text('Assignment'),
                    ),
                    DropdownMenuItem(value: 'study', child: Text('Study')),
                    DropdownMenuItem(value: 'personal', child: Text('Personal')),
                  ],
                  onChanged: (v) => setLocal(() => type = v ?? 'meeting'),
                ),
                _dialogField(title, 'Title'),
                Row(
                  children: [
                    Expanded(child: _dialogField(start, 'Start (HH:MM)')),
                    const SizedBox(width: 8),
                    Expanded(child: _dialogField(end, 'End (HH:MM)')),
                  ],
                ),
                _dialogField(location, 'Location / venue'),
                _dialogField(courseCode, 'Course code (optional)'),
                _dialogField(notes, 'Notes (optional)'),
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
                if (title.text.trim().isEmpty) return;
                if (eventId == null) {
                  await _service.addCalendarEvent(
                    userId: _userId,
                    title: title.text.trim(),
                    date: _dateKey,
                    startTime: start.text.trim(),
                    endTime: end.text.trim(),
                    location: location.text.trim(),
                    type: type,
                    courseCode: courseCode.text.trim(),
                    notes: notes.text.trim(),
                  );
                } else {
                  await _service.updateCalendarEvent(
                    id: eventId,
                    title: title.text.trim(),
                    date: _dateKey,
                    startTime: start.text.trim(),
                    endTime: end.text.trim(),
                    location: location.text.trim(),
                    type: type,
                    courseCode: courseCode.text.trim(),
                    notes: notes.text.trim(),
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

    for (final c in [title, location, start, end, notes, courseCode]) {
      c.dispose();
    }
  }

  Widget _dialogField(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: c,
        decoration: InputDecoration(labelText: label, isDense: true),
      ),
    );
  }
}
