import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/firestore_service.dart';
import '../services/timetable_ocr_service.dart';

/// Lets a student upload/scan a timetable screenshot, review the extracted
/// classes, edit them, and save. Works without OCR too (manual entry).
class TimetableUploadScreen extends StatefulWidget {
  const TimetableUploadScreen({super.key});

  @override
  State<TimetableUploadScreen> createState() => _TimetableUploadScreenState();
}

class _TimetableUploadScreenState extends State<TimetableUploadScreen> {
  final _picker = ImagePicker();
  final _ocr = TimetableOcrService();
  final _service = FirestoreService();

  final List<ScannedClass> _rows = [];
  bool _scanning = false;
  bool _saving = false;
  bool _replaceExisting = true;
  String _note = TimetableOcrService.isSupported
      ? 'Upload or photograph your timetable, then review and edit each class.'
      : 'Scanning works on the mobile app. On web, add your classes manually below.';

  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  Future<void> _pick(ImageSource source) async {
    if (!TimetableOcrService.isSupported) {
      setState(() => _note =
          'Scanning is only available on the mobile app. Add classes manually.');
      return;
    }
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 90);
      if (file == null) return;
      setState(() {
        _scanning = true;
        _note = 'Reading your timetable...';
      });

      final result = await _ocr.scan(file.path);
      if (!mounted) return;
      setState(() {
        _rows
          ..clear()
          ..addAll(result.classes);
        _scanning = false;
        _note = result.classes.isEmpty
            ? 'Could not detect classes automatically. Add them manually below.'
            : 'Found ${result.classes.length} classes. Please review and fix any mistakes before saving.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _note = 'Scan failed: $e';
      });
    }
  }

  void _addRow() => setState(() => _rows.add(ScannedClass()));

  void _removeRow(int index) => setState(() => _rows.removeAt(index));

  Future<void> _save() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final valid = _rows
        .where((r) =>
            r.courseCode.trim().isNotEmpty || r.courseName.trim().isNotEmpty)
        .map((r) => r.toMap())
        .toList();

    if (valid.isEmpty) {
      _toast('Add at least one class with a course code or name.');
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.saveTimetableBatch(
        userId: userId,
        entries: valid,
        replaceExisting: _replaceExisting,
      );
      if (!mounted) return;
      _toast('Saved ${valid.length} classes to your timetable.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('Could not save: $e');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Timetable')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _save,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save),
        label: Text(_saving ? 'Saving' : 'Save timetable'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Card(
            color: const Color(0xffeef3fb),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.document_scanner, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _note,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _scanning ? null : () => _pick(
                              ImageSource.gallery,
                            ),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Upload image'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _scanning ? null : () => _pick(
                              ImageSource.camera,
                            ),
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('Take photo'),
                      ),
                    ],
                  ),
                  if (_scanning)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _replaceExisting,
            onChanged: (v) => setState(() => _replaceExisting = v),
            title: const Text('Replace my current timetable'),
            subtitle: const Text(
              'Turn off to add these classes on top of existing ones.',
            ),
          ),
          const Divider(),
          if (_rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('No classes yet. Scan an image or add one below.'),
              ),
            )
          else
            ..._rows.asMap().entries.map((e) => _rowCard(e.key, e.value)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add),
            label: const Text('Add class manually'),
          ),
        ],
      ),
    );
  }

  Widget _rowCard(int index, ScannedClass row) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Class ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: () => _removeRow(index),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
            _field('Course code (e.g. PRG4201.1G1.JAN2026)', row.courseCode,
                (v) => row.courseCode = v),
            _field('Course name', row.courseName, (v) => row.courseName = v),
            DropdownButtonFormField<String>(
              initialValue: _days.contains(row.day) ? row.day : null,
              decoration: const InputDecoration(
                labelText: 'Day',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _days
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) => setState(() => row.day = v ?? ''),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _field('Start (HH:MM)', row.startTime,
                      (v) => row.startTime = v),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child:
                      _field('End (HH:MM)', row.endTime, (v) => row.endTime = v),
                ),
              ],
            ),
            _field('Room / venue', row.room, (v) => row.room = v),
            _field('Lecturer', row.lecturer, (v) => row.lecturer = v),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, String value, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
