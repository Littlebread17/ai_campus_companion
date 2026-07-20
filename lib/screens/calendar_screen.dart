import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/firestore_service.dart';
import '../services/reminder_scheduler.dart';
import '../utils/course_utils.dart';
import '../utils/ics_export.dart';
import '../utils/recurrence.dart';
import 'calendar_entry_editor.dart';
import 'locations_screen.dart';

/// A unified item shown on the calendar for a given day.
class _DayItem {
  final String start;
  final String end;
  final String title;
  final String venue;
  final Color color;
  final bool isClass;
  final bool isReminder;
  final String type;
  final String? docId; // set for editable personal events / reminders

  const _DayItem({
    required this.start,
    required this.end,
    required this.title,
    required this.venue,
    required this.color,
    required this.isClass,
    this.isReminder = false,
    this.type = 'class',
    this.docId,
  });
}

/// A reminder row for the Tasks tab, with its next effective due date.
class _Task {
  final String id;
  final String title;
  final String description;
  final String courseCode;
  final DateTime due;
  final String recurrence;
  final int leadTimeMinutes;
  final bool done;
  final String source;

  const _Task({
    required this.id,
    required this.title,
    required this.description,
    required this.courseCode,
    required this.due,
    required this.recurrence,
    required this.leadTimeMinutes,
    required this.done,
    required this.source,
  });
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, this.initialTab = 0});

  /// 0 = Day, 1 = Week, 2 = Tasks. Used when Canva / dashboard deep-links here.
  final int initialTab;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  final _service = FirestoreService();
  late final TabController _tabs;
  DateTime _selected = DateTime.now();
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  static const _typeMeta = {
    'class': (Icons.school, Color(0xff2563eb)),
    'meeting': (Icons.groups, Color(0xff7c3aed)),
    'assignment': (Icons.assignment_turned_in, Color(0xffdc2626)),
    'study': (Icons.menu_book, Color(0xff16a34a)),
    'personal': (Icons.event_note, Color(0xff0891b2)),
    'reminder': (Icons.notifications_active, Color(0xffea580c)),
  };

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Calendar'),
        actions: [
          IconButton(
            tooltip: 'Export to calendar (.ics)',
            icon: const Icon(Icons.ios_share),
            onPressed: _exportIcs,
          ),
          if (_tabs.index != 2)
            IconButton(
              tooltip: 'Pick date',
              icon: const Icon(Icons.calendar_today),
              onPressed: _pickDate,
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Day'),
            Tab(text: 'Week'),
            Tab(text: 'Tasks'),
          ],
        ),
      ),
      // Bottom-left so it never overlaps the bottom-right Canva bubble.
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'calendar-fab',
        onPressed: _tabs.index == 2 ? _addReminder : () => _editEvent(),
        icon: const Icon(Icons.add),
        label: Text(_tabs.index == 2 ? 'Reminder' : 'Event'),
      ),
      body: _AllStreams(
        service: _service,
        userId: _userId,
        builder: (tt, ev, rem, campus) {
          return TabBarView(
            controller: _tabs,
            children: [
              _dayTab(tt, ev, rem),
              _weekTab(tt, ev, rem),
              _tasksTab(rem),
            ],
          );
        },
      ),
    );
  }

  // ---------------- DAY TAB (monthly grid + inline agenda) ----------------

  Widget _dayTab(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> tt,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> ev,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> rem,
  ) {
    final items = _itemsForDay(tt, ev, rem, _selected);
    return Column(
      children: [
        _monthHeader(),
        _monthGrid(tt, ev, rem),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              DateFormat('EEEE, d MMM').format(_selected),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Nothing scheduled for this day.'),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _itemTile(items[i]),
                ),
        ),
      ],
    );
  }

  Widget _monthHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          Text(
            DateFormat('MMMM yyyy').format(_visibleMonth),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous month',
            onPressed: () => _changeMonth(-1),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next month',
            onPressed: () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _monthGrid(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> tt,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> ev,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> rem,
  ) {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < 0) _changeMonth(1);
        if (v > 0) _changeMonth(-1);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Row(
              children: labels
                  .map((l) => Expanded(
                        child: Center(
                          child: Text(
                            l,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xff94a3b8),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 2),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: 52,
              ),
              itemCount: 42,
              itemBuilder: (context, i) {
                final day = gridStart.add(Duration(days: i));
                return _monthCell(day, tt, ev, rem);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthCell(
    DateTime day,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> tt,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> ev,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> rem,
  ) {
    final inMonth = day.month == _visibleMonth.month;
    final isSel = DateUtils.isSameDay(day, _selected);
    final isToday = DateUtils.isSameDay(day, DateTime.now());
    final dots = _dotColorsFor(day, tt, ev, rem);

    Color numberColor;
    if (isSel) {
      numberColor = Colors.white;
    } else if (isToday) {
      numberColor = const Color(0xff2563eb);
    } else if (inMonth) {
      numberColor = Colors.black87;
    } else {
      numberColor = const Color(0xffcbd5e1);
    }

    return GestureDetector(
      onTap: () => setState(() => _selected = day),
      child: Container(
        margin: const EdgeInsets.all(3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSel ? const Color(0xff2563eb) : Colors.transparent,
                border: isToday && !isSel
                    ? Border.all(color: const Color(0xff2563eb), width: 1.4)
                    : null,
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: numberColor,
                ),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: dots
                    .map((c) => Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSel ? Colors.white : c,
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Distinct source colours (max 3) for the dots under a day cell.
  List<Color> _dotColorsFor(
    DateTime day,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> tt,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> ev,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> rem,
  ) {
    final items = _itemsForDay(tt, ev, rem, day);
    final seen = <Color>{};
    final colors = <Color>[];
    for (final it in items) {
      if (seen.add(it.color)) colors.add(it.color);
      if (colors.length == 3) break;
    }
    return colors;
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + delta,
        1,
      );
    });
  }

  // ---------------- WEEK TAB ----------------

  Widget _weekTab(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> tt,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> ev,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> rem,
  ) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount: 7,
      itemBuilder: (context, i) {
        final day = start.add(Duration(days: i));
        final items = _itemsForDay(tt, ev, rem, day);
        final isToday = i == 0;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      DateFormat('EEE, d MMM').format(day),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: isToday
                            ? const Color(0xff2563eb)
                            : Colors.black87,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      const Chip(
                        label: Text('Today'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                if (items.isEmpty)
                  const Text(
                    'Free day',
                    style: TextStyle(color: Color(0xff94a3b8)),
                  )
                else
                  ...items.map(
                    (it) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(width: 4, height: 18, color: it.color),
                          const SizedBox(width: 8),
                          Text(
                            it.start.isEmpty ? '--' : it.start,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              it.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------- TASKS TAB ----------------

  Widget _tasksTab(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> rem,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tasks = <_Task>[];
    for (final doc in rem) {
      final d = doc.data();
      if (d['done'] == true) continue;
      final recurrence = (d['recurrence'] ?? 'none').toString();
      final baseYmd = (d['reminderDate'] ?? '').toString();
      final timeStr = (d['reminderTime'] ?? '09:00').toString();
      final nextDay = Recurrence.nextOccurrence(baseYmd, recurrence, today);
      final parts = timeStr.split(':');
      final due = DateTime(
        nextDay.year,
        nextDay.month,
        nextDay.day,
        int.tryParse(parts.isNotEmpty ? parts[0] : '9') ?? 9,
        int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      );
      final createdBy = (d['createdBy'] ?? 'user').toString();
      tasks.add(
        _Task(
          id: doc.id,
          title: (d['title'] ?? 'Reminder').toString(),
          description: (d['description'] ?? '').toString(),
          courseCode: (d['courseCode'] ?? '').toString(),
          due: due,
          recurrence: recurrence,
          leadTimeMinutes: _asInt(d['leadTimeMinutes']),
          done: false,
          source: createdBy.contains('canva') ? 'Canva' : 'You',
        ),
      );
    }
    tasks.sort((a, b) => a.due.compareTo(b.due));

    if (tasks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No active reminders.\nTap + to add one, or ask Canva.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final tomorrow = today.add(const Duration(days: 1));
    final endOfWeek = today.add(Duration(days: DateTime.sunday - today.weekday));
    final groups = <String, List<_Task>>{
      'Overdue': [],
      'Today': [],
      'Tomorrow': [],
      'This week': [],
      'Later': [],
    };
    for (final t in tasks) {
      final day = DateTime(t.due.year, t.due.month, t.due.day);
      if (t.due.isBefore(now) && day.isBefore(today)) {
        groups['Overdue']!.add(t);
      } else if (day == today) {
        groups['Today']!.add(t);
      } else if (day == tomorrow) {
        groups['Tomorrow']!.add(t);
      } else if (!day.isAfter(endOfWeek)) {
        groups['This week']!.add(t);
      } else {
        groups['Later']!.add(t);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      children: [
        for (final entry in groups.entries)
          if (entry.value.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
              child: Text(
                entry.key,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: entry.key == 'Overdue'
                      ? const Color(0xffdc2626)
                      : const Color(0xff475569),
                ),
              ),
            ),
            ...entry.value.map(_taskTile),
          ],
      ],
    );
  }

  Widget _taskTile(_Task t) {
    final overdue = t.due.isBefore(DateTime.now());
    return Dismissible(
      key: ValueKey('task_${t.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xfff59e0b),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.snooze, color: Colors.white),
            SizedBox(width: 6),
            Text('Snooze', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        await _snoozeTask(t);
        return false; // keep the tile; snooze just moves the alert
      },
      child: Card(
        child: ListTile(
          leading: Container(
            width: 6,
            height: 40,
            decoration: BoxDecoration(
              color: _taskColor(t),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          title: Text(
            t.courseCode.isEmpty ? t.title : '${t.courseCode}  ${t.title}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            [
              DateFormat('EEE, d MMM  HH:mm').format(t.due),
              if (t.recurrence != 'none') '· ${Recurrence.options[t.recurrence]}',
              if (t.leadTimeMinutes > 0)
                '· ${Recurrence.leadTimeOptions[t.leadTimeMinutes] ?? '${t.leadTimeMinutes}m before'}',
            ].join('  '),
            style: TextStyle(
              color: overdue ? const Color(0xffdc2626) : const Color(0xff64748b),
              fontSize: 12,
            ),
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'done') {
                if (await _confirm(
                  'Mark "${t.title}" as done?',
                  confirmLabel: 'Mark done',
                )) {
                  await _markDone(t);
                }
              } else if (v == 'edit') {
                if (await _confirm(
                  'Edit "${t.title}"?',
                  confirmLabel: 'Edit',
                )) {
                  await _editReminder(t.id);
                }
              } else if (v == 'delete') {
                if (await _confirm(
                  'Delete "${t.title}"? This cannot be undone.',
                  confirmLabel: 'Delete',
                  destructive: true,
                )) {
                  await _deleteReminder(t.id);
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'done', child: Text('Mark as done')),
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ),
      ),
    );
  }

  /// Colour for a task's leading bar — by course if it has one, else the
  /// reminder orange (matching the Day/Week views).
  Color _taskColor(_Task t) => t.courseCode.isEmpty
      ? const Color(0xffea580c)
      : CourseUtils.colorFor(t.courseCode);

  /// Shared confirmation dialog. Returns true only if the user confirms.
  Future<bool> _confirm(
    String message, {
    String confirmLabel = 'Confirm',
    bool destructive = false,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Please confirm'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: const Color(0xffdc2626),
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  Future<void> _snoozeTask(_Task t) async {
    final choice = await showModalBottomSheet<Duration>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Snooze until…')),
            ListTile(
              leading: const Icon(Icons.timelapse),
              title: const Text('1 hour'),
              onTap: () => Navigator.pop(context, const Duration(hours: 1)),
            ),
            ListTile(
              leading: const Icon(Icons.wb_sunny_outlined),
              title: const Text('Tomorrow 9 am'),
              onTap: () {
                final now = DateTime.now();
                final t = DateTime(now.year, now.month, now.day + 1, 9);
                Navigator.pop(context, t.difference(now));
              },
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final until = DateTime.now().add(choice);
    await _service.snoozeReminder(t.id, until);
    await ReminderScheduler.instance.schedule(
      docId: t.id,
      title: t.title,
      body: t.courseCode.isEmpty ? 'Reminder' : t.courseCode,
      when: until,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Snoozed to ${DateFormat('HH:mm').format(until)}')),
      );
    }
  }

  Future<void> _markDone(_Task t) async {
    await _service.setReminderDone(t.id, true);
    await ReminderScheduler.instance.cancel(t.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked done')),
      );
    }
  }

  // ---------------- SHARED ITEM BUILDING ----------------

  List<_DayItem> _itemsForDay(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> ttDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> evDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> remDocs,
    DateTime day,
  ) {
    final items = <_DayItem>[];
    final weekday = DateFormat('EEEE').format(day);
    final dateKey = DateFormat('yyyy-MM-dd').format(day);

    for (final doc in ttDocs) {
      final d = doc.data();
      if ((d['day'] ?? '').toString() != weekday) continue;
      final code = (d['courseCode'] ?? '').toString();
      items.add(
        _DayItem(
          start: (d['startTime'] ?? '').toString(),
          end: (d['endTime'] ?? '').toString(),
          title: '${d['courseCode'] ?? ''}  ${d['courseName'] ?? ''}'.trim(),
          venue: (d['room'] ?? '').toString(),
          color: CourseUtils.colorFor(code),
          isClass: true,
        ),
      );
    }

    for (final doc in evDocs) {
      final d = doc.data();
      final baseYmd = (d['date'] ?? '').toString();
      final recurrence = (d['recurrence'] ?? 'none').toString();
      final matches = recurrence == 'none'
          ? baseYmd == dateKey
          : Recurrence.occursOn(baseYmd, recurrence, day);
      if (!matches) continue;
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
          docId: doc.id,
        ),
      );
    }

    for (final doc in remDocs) {
      final d = doc.data();
      if (d['done'] == true) continue;
      final baseYmd = (d['reminderDate'] ?? '').toString();
      final recurrence = (d['recurrence'] ?? 'none').toString();
      final matches = recurrence == 'none'
          ? baseYmd == dateKey
          : Recurrence.occursOn(baseYmd, recurrence, day);
      if (!matches) continue;
      final code = (d['courseCode'] ?? '').toString();
      items.add(
        _DayItem(
          start: (d['reminderTime'] ?? '').toString(),
          end: '',
          title: code.isEmpty
              ? (d['title'] ?? 'Reminder').toString()
              : '$code  ${d['title'] ?? 'Reminder'}',
          venue: (d['description'] ?? '').toString(),
          color: _typeMeta['reminder']!.$2,
          isClass: false,
          isReminder: true,
          type: 'reminder',
          docId: doc.id,
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
                              ? (item.isClass
                                  ? 'Class'
                                  : (item.isReminder ? 'Reminder' : item.type))
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
        trailing: _trailingFor(item),
      ),
    );
  }

  Widget? _trailingFor(_DayItem item) {
    if (item.isClass) {
      return item.venue.isEmpty
          ? null
          : IconButton(
              tooltip: 'Navigate',
              icon: const Icon(Icons.near_me),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LocationsScreen(initialQuery: item.venue),
                ),
              ),
            );
    }
    if (item.isReminder) {
      return PopupMenuButton<String>(
        onSelected: (v) async {
          if (v == 'done') {
            if (await _confirm('Mark "${item.title}" as done?',
                confirmLabel: 'Mark done')) {
              await _service.setReminderDone(item.docId!, true);
              await ReminderScheduler.instance.cancel(item.docId!);
            }
          } else if (v == 'edit') {
            if (await _confirm('Edit "${item.title}"?', confirmLabel: 'Edit')) {
              await _editReminder(item.docId!);
            }
          } else if (v == 'delete') {
            if (await _confirm('Delete "${item.title}"? This cannot be undone.',
                confirmLabel: 'Delete', destructive: true)) {
              await _deleteReminder(item.docId!);
            }
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'done', child: Text('Mark as done')),
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      );
    }
    return PopupMenuButton<String>(
      onSelected: (v) async {
        if (v == 'edit') {
          if (await _confirm('Edit "${item.title}"?', confirmLabel: 'Edit')) {
            await _editEvent(eventId: item.docId);
          }
        } else if (v == 'delete') {
          if (await _confirm('Delete "${item.title}"? This cannot be undone.',
              confirmLabel: 'Delete', destructive: true)) {
            await _deleteEvent(item.docId!);
          }
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }

  // ---------------- ACTIONS ----------------

  Future<void> _exportIcs() async {
    final entries = <IcsEntry>[];
    final tt = await _service.streamUserTimetable(_userId).first;
    final ev = await _service.streamUserCalendarEvents(_userId).first;
    final rem = await _service.streamUserReminders(_userId).first;
    final base = DateTime.now();

    DateTime? at(String ymd, String hm) {
      final d = DateTime.tryParse(ymd);
      if (d == null) return null;
      final p = hm.split(':');
      return DateTime(d.year, d.month, d.day,
          int.tryParse(p.isNotEmpty ? p[0] : '9') ?? 9,
          int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
    }

    for (final doc in ev.docs) {
      final d = doc.data();
      final start = at((d['date'] ?? '').toString(),
          (d['startTime'] ?? '09:00').toString());
      if (start == null) continue;
      final end = at((d['date'] ?? '').toString(),
          (d['endTime'] ?? '').toString());
      entries.add(IcsEntry(
        uid: doc.id,
        title: (d['title'] ?? 'Event').toString(),
        start: start,
        end: end,
        location: (d['location'] ?? '').toString(),
        description: (d['notes'] ?? '').toString(),
      ));
    }
    for (final doc in rem.docs) {
      final d = doc.data();
      if (d['done'] == true) continue;
      final start = at((d['reminderDate'] ?? '').toString(),
          (d['reminderTime'] ?? '09:00').toString());
      if (start == null) continue;
      entries.add(IcsEntry(
        uid: doc.id,
        title: (d['title'] ?? 'Reminder').toString(),
        start: start,
        description: (d['description'] ?? '').toString(),
      ));
    }
    // Timetable: export this week's occurrences only, to keep the file small.
    final startOfWeek = base.subtract(Duration(days: base.weekday - 1));
    for (final doc in tt.docs) {
      final d = doc.data();
      for (var i = 0; i < 7; i++) {
        final day = startOfWeek.add(Duration(days: i));
        if (DateFormat('EEEE').format(day) != (d['day'] ?? '').toString()) {
          continue;
        }
        final ymd = DateFormat('yyyy-MM-dd').format(day);
        final start = at(ymd, (d['startTime'] ?? '09:00').toString());
        if (start == null) continue;
        entries.add(IcsEntry(
          uid: '${doc.id}_$i',
          title: '${d['courseCode'] ?? ''} ${d['courseName'] ?? ''}'.trim(),
          start: start,
          end: at(ymd, (d['endTime'] ?? '').toString()),
          location: (d['room'] ?? '').toString(),
        ));
      }
    }

    if (entries.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing to export yet.')),
        );
      }
      return;
    }
    await IcsExport.share(entries);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime.now().subtract(const Duration(days: 180)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selected = picked;
        _visibleMonth = DateTime(picked.year, picked.month, 1);
      });
    }
  }

  Future<void> _deleteEvent(String id) async {
    await _service.deleteCalendarEvent(id);
    await ReminderScheduler.instance.cancel(id);
  }

  Future<void> _deleteReminder(String id) async {
    await _service.deleteReminder(id);
    await ReminderScheduler.instance.cancel(id);
  }

  Future<void> _addReminder() async {
    await _editReminder(null);
  }

  Future<void> _editReminder(String? reminderId) async {
    Map<String, dynamic> existing = {};
    if (reminderId != null) {
      final doc = await FirebaseFirestore.instance
          .collection('reminders')
          .doc(reminderId)
          .get();
      existing = doc.data() ?? {};
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalendarEntryEditor(
          isReminder: true,
          userId: _userId,
          initialDate: _selected,
          docId: reminderId,
          existing: existing.isEmpty ? null : existing,
        ),
      ),
    );
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
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalendarEntryEditor(
          isReminder: false,
          userId: _userId,
          initialDate: _selected,
          docId: eventId,
          existing: existing.isEmpty ? null : existing,
        ),
      ),
    );
  }

  /// Safely coerce a Firestore field (which may be null / num / String) to int.
  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? ''}') ?? 0;
  }
}

/// Collects the four Firestore streams the calendar needs and rebuilds when any
/// changes. Keeps the widget tree flat instead of deeply-nested StreamBuilders.
class _AllStreams extends StatelessWidget {
  const _AllStreams({
    required this.service,
    required this.userId,
    required this.builder,
  });

  final FirestoreService service;
  final String userId;
  final Widget Function(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> timetable,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> events,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> reminders,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> campusEvents,
  ) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.streamUserTimetable(userId),
      builder: (context, tt) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: service.streamUserCalendarEvents(userId),
          builder: (context, ev) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: service.streamUserReminders(userId),
              builder: (context, rem) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: service.streamCollection('events'),
                  builder: (context, campus) {
                    if (!tt.hasData || !ev.hasData || !rem.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return builder(
                      tt.data!.docs,
                      ev.data!.docs,
                      rem.data!.docs,
                      campus.data?.docs ?? const [],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
