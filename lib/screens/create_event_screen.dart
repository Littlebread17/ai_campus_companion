import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/firestore_service.dart';
import '../utils/event_category.dart';
import '../widgets/event_poster.dart';

/// Admin-only screen to publish a campus event directly, with an optional
/// poster image. Students still use the proposal flow; this is the fast path.
class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _service = FirestoreService();
  final _title = TextEditingController();
  final _club = TextEditingController();
  final _date = TextEditingController();
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _venue = TextEditingController();
  final _desc = TextEditingController();
  final _capacity = TextEditingController(text: '40');

  String _hostType = 'club';
  String _category = EventCategory.options.first;
  XFile? _poster;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_title, _club, _date, _start, _end, _venue, _desc, _capacity]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPoster() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _poster = picked);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (d != null) {
      _date.text =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _pickTime(TextEditingController c) async {
    final t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (t != null) {
      c.text =
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _date.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and date are required.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final ref = await _service.createEvent(
        title: _title.text.trim(),
        description: _desc.text.trim(),
        clubName: _club.text.trim(),
        hostType: _hostType,
        eventDate: _date.text.trim(),
        startTime: _start.text.trim(),
        endTime: _end.text.trim(),
        venue: _venue.text.trim(),
        capacity: int.tryParse(_capacity.text.trim()) ?? 0,
        posterUrl: '',
        createdBy: uid,
        category: _category,
      );
      if (_poster != null) {
        final bytes = await _poster!.readAsBytes();
        final storageRef =
            FirebaseStorage.instance.ref('event_posters/${ref.id}.jpg');
        await storageRef.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        final url = await storageRef.getDownloadURL();
        await _service.setEventPoster(ref.id, url);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event published.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not publish: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Event'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Publish', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _pickPoster,
            child: _poster == null
                ? EventPoster(
                    title: _title.text.isEmpty ? 'Poster preview' : _title.text,
                    posterUrl: '',
                    height: 160,
                    borderRadius: 12,
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FutureBuilder(
                      future: _poster!.readAsBytes(),
                      builder: (c, s) => s.hasData
                          ? Image.memory(s.data!,
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover)
                          : const SizedBox(height: 160),
                    ),
                  ),
          ),
          Center(
            child: TextButton.icon(
              onPressed: _pickPoster,
              icon: const Icon(Icons.image),
              label: Text(_poster == null ? 'Add poster' : 'Change poster'),
            ),
          ),
          _field(_title, 'Event title'),
          DropdownButtonFormField<String>(
            initialValue: _hostType,
            decoration: const InputDecoration(labelText: 'Host', isDense: true),
            items: const [
              DropdownMenuItem(value: 'club', child: Text('A campus club')),
              DropdownMenuItem(value: 'school', child: Text('INTI (school)')),
            ],
            onChanged: (v) => setState(() => _hostType = v ?? 'club'),
          ),
          _field(_club, _hostType == 'school' ? 'Department (optional)' : 'Club name'),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: EventCategory.options
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _category = v ?? EventCategory.options.first),
            ),
          ),
          Row(
            children: [
              Expanded(child: _tapField(_date, 'Date', _pickDate)),
              const SizedBox(width: 8),
              Expanded(child: _tapField(_start, 'Start', () => _pickTime(_start))),
              const SizedBox(width: 8),
              Expanded(child: _tapField(_end, 'End', () => _pickTime(_end))),
            ],
          ),
          _field(_venue, 'Venue'),
          _field(_capacity, 'Capacity (0 = unlimited)',
              keyboard: TextInputType.number),
          _field(_desc, 'Description', maxLines: 4),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.publish),
            label: const Text('Publish event'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {int maxLines = 1, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboard,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _tapField(TextEditingController c, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TextField(
        controller: c,
        readOnly: true,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
