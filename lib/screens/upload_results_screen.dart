import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/firestore_service.dart';
import '../services/result_ocr_service.dart';
import '../utils/grade_utils.dart';

/// Upload/scan a result slip, review the extracted grades, edit, and save.
/// Mirrors the timetable upload flow; works manually on web (no OCR).
class UploadResultsScreen extends StatefulWidget {
  const UploadResultsScreen({super.key});

  @override
  State<UploadResultsScreen> createState() => _UploadResultsScreenState();
}

class _UploadResultsScreenState extends State<UploadResultsScreen> {
  final _picker = ImagePicker();
  final _ocr = ResultOcrService();
  final _service = FirestoreService();

  final List<ScannedResult> _rows = [];
  bool _scanning = false;
  bool _saving = false;
  String _note = ResultOcrService.isSupported
      ? 'Upload or photograph your result slip, then review each grade.'
      : 'Scanning works on the mobile app. On web, add your results manually.';

  Future<void> _pick(ImageSource source) async {
    if (!ResultOcrService.isSupported) {
      setState(() => _note = 'Scanning is only on mobile. Add results manually.');
      return;
    }
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 90);
      if (file == null) return;
      setState(() {
        _scanning = true;
        _note = 'Reading your results...';
      });
      final res = await _ocr.scan(file.path);
      if (!mounted) return;
      setState(() {
        _rows
          ..clear()
          ..addAll(res.results);
        _scanning = false;
        _note = res.results.isEmpty
            ? 'Could not detect results automatically. Add them manually below.'
            : 'Found ${res.results.length} results. Review and fix before saving.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _note = 'Scan failed: $e';
      });
    }
  }

  void _addRow() => setState(() => _rows.add(ScannedResult()));
  void _removeRow(int i) => setState(() => _rows.removeAt(i));

  Future<void> _save() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final entries = _rows
        .where((r) => r.courseCode.trim().isNotEmpty)
        .map((r) => {
              'courseCode': r.courseCode.trim(),
              'courseName': r.courseName.trim(),
              'semester': r.semester.trim(),
              'grade': r.grade,
              'gradePoint': GradeUtils.pointFor(r.grade),
              'creditHours': double.tryParse(r.creditHours.trim()) ?? 0,
            })
        .where((e) => (e['creditHours'] as double) > 0)
        .toList();

    if (entries.isEmpty) {
      _toast('Add at least one result with a course code and credit hours.');
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.saveGradesBatch(userId: userId, entries: entries);
      if (!mounted) return;
      _toast('Saved ${entries.length} results.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('Could not save: $e');
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Results')),
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
        label: Text(_saving ? 'Saving' : 'Save results'),
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
                        onPressed:
                            _scanning ? null : () => _pick(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Upload image'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            _scanning ? null : () => _pick(ImageSource.camera),
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
          if (_rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('No results yet. Scan a slip or add one below.'),
              ),
            )
          else
            ..._rows.asMap().entries.map((e) => _rowCard(e.key, e.value)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add),
            label: const Text('Add result manually'),
          ),
        ],
      ),
    );
  }

  Widget _rowCard(int index, ScannedResult row) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Result ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _removeRow(index),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
            _field('Course code', row.courseCode, (v) => row.courseCode = v),
            _field('Course name', row.courseName, (v) => row.courseName = v),
            _field('Semester (e.g. JAN2026)', row.semester,
                (v) => row.semester = v),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: GradeUtils.grades.contains(row.grade)
                        ? row.grade
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Grade',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: GradeUtils.grades
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (v) => setState(() => row.grade = v ?? ''),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field(
                    'Credit hrs',
                    row.creditHours,
                    (v) => row.creditHours = v,
                    number: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    String value,
    ValueChanged<String> onChanged, {
    bool number = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: value,
        keyboardType: number ? TextInputType.number : TextInputType.text,
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
