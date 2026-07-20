import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/live_positioning_service.dart';
import '../services/wifi_fingerprint_service.dart';

/// Lets the student build the WiFi fingerprint map used by Indoor Radar.
/// Walk to a room, type its name, tap "Capture sample" ~20 times to build a
/// solid training set for that location.
class IndoorTrainingScreen extends StatefulWidget {
  const IndoorTrainingScreen({super.key});

  @override
  State<IndoorTrainingScreen> createState() => _IndoorTrainingScreenState();
}

class _IndoorTrainingScreenState extends State<IndoorTrainingScreen> {
  final _service = WifiFingerprintService();
  final _place = TextEditingController();
  bool _capturing = false;
  int _samplesInSession = 0;
  int _lastReadings = 0;
  String _status = 'Set the block, level and place, then Capture sample.';

  // Same block / level lists as the Campus Navigation screen, so a detected
  // place maps cleanly onto the navigation starting-point dropdowns.
  static const blocks = [
    'Academic Block A',
    'Academic Block B',
    'Academic Block C',
    'Academic Block D',
    'Academic Block E',
    'Learning Resource Centre',
    'Student Centre',
    'Sports Complex',
    'Hall of Residence',
    'Service Building',
  ];
  static const levels = [
    'Ground floor',
    'Level 1',
    'Level 2',
    'Level 3',
    'Level 4',
    'Level 5',
    'Rooftop',
  ];

  String _block = blocks.first;
  String _level = levels.first;

  // Live prediction, used to offer a one-tap "add sample to this known room".
  LocationPrediction? _livePos;
  StreamSubscription<LocationPrediction?>? _posSub;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _posSub = LivePositioningService.instance.stream.listen((p) {
      if (mounted) setState(() => _livePos = p);
    });
    LivePositioningService.instance.start();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    LivePositioningService.instance.stop();
    _place.dispose();
    super.dispose();
  }

  /// One-tap capture that reuses the confidently-detected known room, instead of
  /// re-typing block/level/place.
  Future<void> _quickCapture(LocationPrediction p) async {
    setState(() {
      _capturing = true;
      _status = 'Adding a sample to ${p.display}…';
    });
    final ok = await _service.ensurePermissions();
    if (!ok) {
      setState(() {
        _capturing = false;
        _status = 'Location permission is required for WiFi scanning.';
      });
      return;
    }
    final sample = await _service.scanOnce();
    if (sample == null || sample.readings.isEmpty) {
      setState(() {
        _capturing = false;
        _status = 'No WiFi readings captured. Try again.';
      });
      return;
    }
    await _service.saveSample(
      userId: _uid,
      block: p.block,
      level: p.level,
      placeName: p.placeName,
      sample: sample,
    );
    await LivePositioningService.instance.refreshTraining();
    if (!mounted) return;
    setState(() {
      _samplesInSession += 1;
      _lastReadings = sample.length;
      _capturing = false;
      _status = 'Added sample to ${p.display}.';
    });
  }

  Future<void> _capture() async {
    final place = _place.text.trim();
    if (place.isEmpty) {
      _toast('Type a place name first (e.g. Physics Lab).');
      return;
    }
    setState(() {
      _capturing = true;
      _status = 'Scanning WiFi…';
    });

    final ok = await _service.ensurePermissions();
    if (!ok) {
      setState(() {
        _capturing = false;
        _status = 'Location permission is required for WiFi scanning.';
      });
      return;
    }

    final sample = await _service.scanOnce();
    if (sample == null || sample.readings.isEmpty) {
      setState(() {
        _capturing = false;
        _status =
            'No WiFi readings captured. Try again — make sure WiFi is on.';
      });
      return;
    }

    await _service.saveSample(
      userId: _uid,
      block: _block,
      level: _level,
      placeName: place,
      sample: sample,
    );
    await LivePositioningService.instance.refreshTraining();
    if (!mounted) return;
    setState(() {
      _samplesInSession += 1;
      _lastReadings = sample.length;
      _capturing = false;
      _status =
          'Sample captured (${sample.length} WiFi points) for '
          '$_block · $_level · $place.';
    });
  }

  Future<void> _delete(String location) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "$location"?'),
        content: const Text('All samples for this location will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _service.deleteLocation(location: location);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// When the live positioning is very confident of a room the student has
  /// already trained, offer a one-tap button to grow that room's coverage.
  Widget _quickTagCard() {
    final p = _livePos;
    if (p == null || p.confidence < 0.9 || p.placeName.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xffecfdf5),
          border: Border.all(color: const Color(0xffa7f3d0)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.my_location, color: Color(0xff059669)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "You seem to be in ${p.display} "
                "(${(p.confidence * 100).round()}%).",
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _capturing ? null : () => _quickCapture(p),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff059669),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Add sample'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Indoor Training')),
      body: Column(
        children: [
          Container(
            color: const Color(0xffeef2ff),
            padding: const EdgeInsets.all(14),
            child: const Text(
              'Walk to each room. Set its block, level and place name, then tap '
              '"Capture sample" 15–20 times, standing at slightly different '
              'spots in the room.',
              style: TextStyle(color: Color(0xff334155)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _block,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Block',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: blocks
                        .map(
                          (b) => DropdownMenuItem(
                            value: b,
                            child: Text(b, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _block = v ?? _block),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _level,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Level',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: levels
                        .map(
                          (l) => DropdownMenuItem(
                            value: l,
                            child: Text(l, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _level = v ?? _level),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _place,
              decoration: const InputDecoration(
                labelText: 'Place name',
                hintText: 'e.g. Physics Laboratory, Corridor near A1-01',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _capturing ? null : _capture,
                icon: _capturing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.wifi_find),
                label: Text(_capturing ? 'Scanning…' : 'Capture sample'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          _quickTagCard(),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xffe2e8f0)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xff64748b)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$_status\nSession: $_samplesInSession samples '
                      '· last scan saw $_lastReadings WiFi points.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Trained locations',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('wifiFingerprints')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final counts = <String, int>{};
                for (final doc in snapshot.data!.docs) {
                  final loc = (doc.data()['location'] ?? '').toString();
                  if (loc.isEmpty) continue;
                  counts[loc] = (counts[loc] ?? 0) + 1;
                }
                if (counts.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No locations trained yet.'),
                    ),
                  );
                }
                final entries = counts.entries.toList()
                  ..sort((a, b) => a.key.compareTo(b.key));
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final e in entries)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.place),
                          title: Text(e.key),
                          subtitle: Text('${e.value} samples'),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () => _delete(e.key),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
