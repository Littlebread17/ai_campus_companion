import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import 'locations_screen.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _CalendarItem {
  final String title;
  final String description;
  final String date;
  final String time;
  final String venue;
  final String source;
  final bool isEvent;

  const _CalendarItem({
    required this.title,
    required this.description,
    required this.date,
    required this.time,
    required this.venue,
    required this.source,
    required this.isEvent,
  });
}

class _RemindersScreenState extends State<RemindersScreen> {
  final service = FirestoreService();
  DateTime selectedDate = DateTime.now();

  Future<void> showAddReminderDialog({DateTime? initialDate}) async {
    final title = TextEditingController();
    final desc = TextEditingController();
    final course = TextEditingController();
    final date = TextEditingController(
      text: _formatDate(initialDate ?? selectedDate),
    );
    final time = TextEditingController(text: '09:00');

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create Reminder'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: desc,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: course,
                decoration: const InputDecoration(labelText: 'Course Code'),
              ),
              TextField(
                controller: date,
                decoration: const InputDecoration(
                  labelText: 'Date e.g. 2026-06-20',
                ),
              ),
              TextField(
                controller: time,
                decoration: const InputDecoration(labelText: 'Time e.g. 09:00'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await service.createReminder(
                userId: FirebaseAuth.instance.currentUser?.uid ?? '',
                title: title.text.trim().isEmpty
                    ? 'Campus Reminder'
                    : title.text.trim(),
                description: desc.text.trim(),
                courseCode: course.text.trim().toUpperCase(),
                reminderDate: date.text.trim(),
                reminderTime: time.text.trim().isEmpty ? '09:00' : time.text,
              );
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    for (final c in [title, desc, course, date, time]) {
      c.dispose();
    }
  }

  List<_CalendarItem> _buildItems({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> reminders,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> events,
  }) {
    final items = <_CalendarItem>[
      ...reminders.map((doc) {
        final data = doc.data();
        final createdBy = (data['createdBy'] ?? 'user').toString();
        return _CalendarItem(
          title: data['title'] ?? 'Untitled Reminder',
          description: data['description'] ?? '',
          date: (data['reminderDate'] ?? '').toString(),
          time: (data['reminderTime'] ?? '').toString(),
          venue: '',
          source: createdBy.contains('canva') ? 'Canva' : 'User',
          isEvent: false,
        );
      }),
      ...events
          .where((doc) {
            final status = (doc.data()['status'] ?? 'published').toString();
            return status == 'published';
          })
          .map((doc) {
            final data = doc.data();
            final start = (data['startTime'] ?? '').toString();
            final end = (data['endTime'] ?? '').toString();
            return _CalendarItem(
              title: data['title'] ?? 'Campus Event',
              description: data['description'] ?? '',
              date: (data['eventDate'] ?? '').toString(),
              time: [start, end].where((item) => item.isNotEmpty).join(' - '),
              venue: (data['venue'] ?? '').toString(),
              source: 'Campus Event',
              isEvent: true,
            );
          }),
    ];

    items.sort(
      (a, b) => '${a.date} ${a.time}'.compareTo('${b.date} ${b.time}'),
    );
    return items;
  }

  bool _isSameSelectedDate(_CalendarItem item) {
    final parsed = DateTime.tryParse(item.date);
    if (parsed == null) return false;
    return parsed.year == selectedDate.year &&
        parsed.month == selectedDate.month &&
        parsed.day == selectedDate.day;
  }

  bool _isUpcoming(_CalendarItem item) {
    final parsed = DateTime.tryParse(item.date);
    if (parsed == null) return false;
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    return !parsed.isBefore(start);
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _openVenue(String venue) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LocationsScreen(initialQuery: venue)),
    );
  }

  Widget _calendarTile(_CalendarItem item) {
    final color = item.isEvent ? Colors.teal : Colors.red;
    final icon = item.isEvent ? Icons.event_available : Icons.notifications;
    final dateLine = item.time.isEmpty
        ? item.date
        : '${item.date} at ${item.time}';
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(item.title),
        subtitle: Text(
          [
            if (item.description.isNotEmpty) item.description,
            dateLine,
            if (item.venue.isNotEmpty) 'Venue: ${item.venue}',
          ].join('\n'),
        ),
        isThreeLine: true,
        trailing: item.isEvent && item.venue.isNotEmpty
            ? IconButton(
                tooltip: 'Navigate',
                onPressed: () => _openVenue(item.venue),
                icon: const Icon(Icons.near_me),
              )
            : Chip(
                label: Text(item.source),
                visualDensity: VisualDensity.compact,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar & Reminders')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddReminderDialog(initialDate: selectedDate),
        icon: const Icon(Icons.add),
        label: const Text('Reminder'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.streamUserReminders(userId),
        builder: (context, reminderSnapshot) {
          if (reminderSnapshot.hasError) {
            return Center(child: Text('Error: ${reminderSnapshot.error}'));
          }
          if (!reminderSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: service.streamCollection('events'),
            builder: (context, eventSnapshot) {
              if (eventSnapshot.hasError) {
                return Center(child: Text('Error: ${eventSnapshot.error}'));
              }
              if (!eventSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final items = _buildItems(
                reminders: reminderSnapshot.data!.docs,
                events: eventSnapshot.data!.docs,
              );
              final selectedItems = items.where(_isSameSelectedDate).toList();
              final upcomingItems = items.where(_isUpcoming).toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xffd8e2f1)),
                    ),
                    child: CalendarDatePicker(
                      initialDate: selectedDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2032),
                      onDateChanged: (date) {
                        setState(() => selectedDate = date);
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Calendar on ${_formatDate(selectedDate)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (selectedItems.isEmpty)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.event_available),
                        title: Text('No reminders or events on this date'),
                      ),
                    )
                  else
                    ...selectedItems.map(_calendarTile),
                  const SizedBox(height: 18),
                  Text(
                    'Upcoming',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (upcomingItems.isEmpty)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.inbox),
                        title: Text('No upcoming reminders or events yet'),
                      ),
                    )
                  else
                    ...upcomingItems.take(8).map(_calendarTile),
                  const SizedBox(height: 80),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
