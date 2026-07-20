import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/firestore_service.dart';
import '../services/reminder_scheduler.dart';
import '../utils/recurrence.dart';

/// Full-screen editor for a calendar Event or a Reminder.
///
/// Events have a start + end (time block) and a type; reminders are a single
/// moment. An "all-day" toggle hides the time pickers and stores empty times.
class CalendarEntryEditor extends StatefulWidget {
  const CalendarEntryEditor({
    super.key,
    required this.isReminder,
    required this.userId,
    required this.initialDate,
    this.docId,
    this.existing,
  });

  final bool isReminder;
  final String userId;
  final DateTime initialDate;
  final String? docId;
  final Map<String, dynamic>? existing;

  @override
  State<CalendarEntryEditor> createState() => _CalendarEntryEditorState();
}

class _CalendarEntryEditorState extends State<CalendarEntryEditor> {
  final _service = FirestoreService();

  late final TextEditingController _title;
  late final TextEditingController _notes;
  late final TextEditingController _course;
  late final TextEditingController _location;

  late DateTime _date;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);
  bool _allDay = false;
  String _type = 'meeting';
  String _recurrence = 'none';
  int _lead = 0;

  static const _typeChips = [
    ('meeting', 'Meeting', Icons.groups, Color(0xff7c3aed)),
    ('study', 'Study', Icons.menu_book, Color(0xff16a34a)),
    ('assignment', 'Assignment', Icons.assignment_turned_in, Color(0xffdc2626)),
    ('personal', 'Personal', Icons.event_note, Color(0xff0891b2)),
  ];

  bool get _isEvent => !widget.isReminder;

  @override
  void initState() {
    super.initState();
    final e = widget.existing ?? {};
    _title = TextEditingController(text: e['title'] ?? '');
    _notes = TextEditingController(
      text: (widget.isReminder ? e['description'] : e['notes']) ?? '',
    );
    _course = TextEditingController(text: e['courseCode'] ?? '');
    _location = TextEditingController(text: e['location'] ?? '');
    _type = (e['type'] ?? 'meeting').toString();
    _recurrence = (e['recurrence'] ?? 'none').toString();
    _lead = _asInt(e['leadTimeMinutes']);

    // Date.
    final dateStr = (widget.isReminder ? e['reminderDate'] : e['date'])
        ?.toString();
    _date = DateTime.tryParse(dateStr ?? '') ?? widget.initialDate;

    // Times + smart defaults.
    final startStr =
        (widget.isReminder ? e['reminderTime'] : e['startTime'])?.toString() ??
            '';
    final endStr = (e['endTime'] ?? '').toString();
    if (widget.docId == null) {
      // New entry: default to the next round hour, end = +1h.
      final now = DateTime.now();
      final next = TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);
      _start = next;
      _end = TimeOfDay(hour: (next.hour + 1) % 24, minute: 0);
    } else {
      _allDay = startStr.isEmpty;
      _start = _parseTod(startStr, _start);
      _end = _parseTod(endStr, _end);
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _notes, _course, _location]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final noun = widget.isReminder ? 'reminder' : 'event';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.docId == null ? 'New $noun' : 'Edit $noun',
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: widget.isReminder ? 'Reminder title' : 'Event title',
              border: InputBorder.none,
            ),
          ),
          const Divider(),

          if (_isEvent) ...[
            _label('Type'),
            Wrap(
              spacing: 8,
              children: _typeChips.map((c) {
                final selected = _type == c.$1;
                return ChoiceChip(
                  avatar: Icon(
                    c.$3,
                    size: 18,
                    color: selected ? Colors.white : c.$4,
                  ),
                  label: Text(c.$2),
                  selected: selected,
                  selectedColor: c.$4,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                  ),
                  onSelected: (_) => setState(() => _type = c.$1),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('All day'),
            value: _allDay,
            onChanged: (v) => setState(() => _allDay = v),
          ),

          _pickerRow(
            icon: Icons.event,
            label: 'Date',
            value: DateFormat('EEE, d MMM yyyy').format(_date),
            onTap: _pickDate,
          ),

          if (!_allDay) ...[
            _pickerRow(
              icon: Icons.schedule,
              label: widget.isReminder ? 'Time' : 'Start',
              value: _start.format(context),
              onTap: () => _pickTime(isStart: true),
            ),
            if (_isEvent) ...[
              _pickerRow(
                icon: Icons.schedule_outlined,
                label: 'End',
                value: _end.format(context),
                onTap: () => _pickTime(isStart: false),
              ),
              _label('Duration'),
              Wrap(
                spacing: 8,
                children: [30, 60, 120].map((mins) {
                  return ActionChip(
                    label: Text(mins < 60
                        ? '${mins}m'
                        : '${mins ~/ 60}h'),
                    onPressed: () => _applyDuration(mins),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
          ],

          if (_isEvent)
            _plainField(_location, 'Location / venue', Icons.place_outlined),
          _plainField(_course, 'Course code (optional)', Icons.tag),

          _label('Repeat'),
          DropdownButtonFormField<String>(
            initialValue: _recurrence,
            decoration: const InputDecoration(isDense: true),
            items: Recurrence.options.entries
                .map((e) =>
                    DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _recurrence = v ?? 'none'),
          ),
          const SizedBox(height: 12),

          if (!_allDay) ...[
            _label('Notify'),
            DropdownButtonFormField<int>(
              initialValue: _lead,
              decoration: const InputDecoration(isDense: true),
              items: Recurrence.leadTimeOptions.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _lead = v ?? 0),
            ),
            const SizedBox(height: 12),
          ],

          _plainField(
            _notes,
            widget.isReminder ? 'Description (optional)' : 'Notes (optional)',
            Icons.notes,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  // ---------------- UI helpers ----------------

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xff475569),
          ),
        ),
      );

  Widget _pickerRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xff2563eb)),
      title: Text(label),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
      onTap: onTap,
    );
  }

  Widget _plainField(
    TextEditingController c,
    String label,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          isDense: true,
        ),
      ),
    );
  }

  // ---------------- Actions ----------------

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
        // Keep end after start for events.
        if (_isEvent && _toMinutes(_end) <= _toMinutes(_start)) {
          _end = TimeOfDay(hour: (picked.hour + 1) % 24, minute: picked.minute);
        }
      } else {
        _end = picked;
      }
    });
  }

  void _applyDuration(int minutes) {
    final total = _toMinutes(_start) + minutes;
    setState(() {
      _end = TimeOfDay(hour: (total ~/ 60) % 24, minute: total % 60);
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title.')),
      );
      return;
    }
    final navigator = Navigator.of(context);
    final ymd = DateFormat('yyyy-MM-dd').format(_date);
    final startStr = _allDay ? '' : _hm(_start);
    final endStr = _allDay ? '' : _hm(_end);
    String docId;

    if (widget.isReminder) {
      if (widget.docId == null) {
        final ref = await _service.createReminder(
          userId: widget.userId,
          title: _title.text.trim(),
          description: _notes.text.trim(),
          courseCode: _course.text.trim().toUpperCase(),
          reminderDate: ymd,
          reminderTime: startStr,
          recurrence: _recurrence,
          leadTimeMinutes: _allDay ? 0 : _lead,
        );
        docId = ref.id;
      } else {
        await _service.updateReminder(
          reminderId: widget.docId!,
          title: _title.text.trim(),
          description: _notes.text.trim(),
          courseCode: _course.text.trim().toUpperCase(),
          reminderDate: ymd,
          reminderTime: startStr,
          recurrence: _recurrence,
          leadTimeMinutes: _allDay ? 0 : _lead,
        );
        docId = widget.docId!;
      }
    } else {
      if (widget.docId == null) {
        final ref = await _service.addCalendarEvent(
          userId: widget.userId,
          title: _title.text.trim(),
          date: ymd,
          startTime: startStr,
          endTime: endStr,
          location: _location.text.trim(),
          type: _type,
          courseCode: _course.text.trim().toUpperCase(),
          notes: _notes.text.trim(),
          recurrence: _recurrence,
          leadTimeMinutes: _allDay ? 0 : _lead,
        );
        docId = ref.id;
      } else {
        await _service.updateCalendarEvent(
          id: widget.docId!,
          title: _title.text.trim(),
          date: ymd,
          startTime: startStr,
          endTime: endStr,
          location: _location.text.trim(),
          type: _type,
          courseCode: _course.text.trim().toUpperCase(),
          notes: _notes.text.trim(),
          recurrence: _recurrence,
          leadTimeMinutes: _allDay ? 0 : _lead,
        );
        docId = widget.docId!;
      }
    }

    // Schedule a local notification. All-day items fire at 09:00.
    final fireHour = _allDay ? 9 : _start.hour;
    final fireMin = _allDay ? 0 : _start.minute;
    await ReminderScheduler.instance.schedule(
      docId: docId,
      title: _title.text.trim(),
      body: widget.isReminder
          ? (_course.text.trim().isEmpty ? 'Reminder' : _course.text.trim())
          : (_location.text.trim().isEmpty ? _type : _location.text.trim()),
      when: DateTime(_date.year, _date.month, _date.day, fireHour, fireMin),
      leadMinutes: _allDay ? 0 : _lead,
    );

    navigator.pop(true);
  }

  // ---------------- utils ----------------

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? ''}') ?? 0;
  }

  static int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  static String _hm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static TimeOfDay _parseTod(String s, TimeOfDay fallback) {
    final p = s.split(':');
    if (p.length < 2) return fallback;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return fallback;
    return TimeOfDay(hour: h, minute: m);
  }
}
