import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'wifi_fingerprint_service.dart';
export 'wifi_fingerprint_service.dart' show LocationPrediction, Fingerprint;

/// Live, app-wide indoor positioning.
///
/// Wraps [WifiFingerprintService]'s k-NN with an invisible spatial model so the
/// published position is stable instead of flickering between neighbouring
/// rooms. The model has three layers, none of which are shown to the student:
///
///  1. Plausibility filter — a new raw prediction is only accepted if it is the
///     current room, on the same/adjacent floor of the same block, or a learned
///     adjacency edge. A physically-impossible "teleport" is rejected unless the
///     new reading is overwhelmingly confident.
///  2. Temporal smoothing — the last few accepted readings vote (weighted by
///     confidence); the majority room is published.
///  3. Auto-learned adjacency — real room→room transitions are recorded to the
///     shared `spatialAdjacency` collection and loaded back to widen the graph
///     beyond the same-block/floor rule (e.g. sky-bridges between blocks).
class LivePositioningService {
  LivePositioningService._();
  static final LivePositioningService instance = LivePositioningService._();

  final WifiFingerprintService _wifi = WifiFingerprintService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final StreamController<LocationPrediction?> _controller =
      StreamController<LocationPrediction?>.broadcast();

  Timer? _timer;
  int _refCount = 0;
  bool _loaded = false;

  List<Fingerprint> _trained = [];
  // Learned adjacency, keyed by place display -> set of neighbouring displays.
  final Map<String, Set<String>> _learned = {};

  // Smoothing window of recently accepted raw predictions.
  final List<LocationPrediction> _window = [];
  static const int _windowSize = 5;

  LocationPrediction? _published;

  Stream<LocationPrediction?> get stream => _controller.stream;
  LocationPrediction? get current => _published;

  /// Begin scanning (ref-counted so multiple screens share one scan loop).
  Future<void> start() async {
    _refCount++;
    if (_timer != null) {
      // Already running — replay the last known position to the new listener.
      if (_published != null) _controller.add(_published);
      return;
    }
    await _ensureLoaded();
    if (_trained.isEmpty) {
      _controller.add(null);
      return;
    }
    final ok = await _wifi.ensurePermissions();
    if (!ok) return;
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _tick());
  }

  /// Release one hold; stops scanning when no screen is watching.
  void stop() {
    _refCount = (_refCount - 1).clamp(0, 1 << 30);
    if (_refCount == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Force a fresh reload of training data + learned edges (after training).
  Future<void> refreshTraining() async {
    _loaded = false;
    await _ensureLoaded();
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _trained = await _wifi.loadFingerprints();
    await _loadLearnedAdjacency();
    _loaded = true;
  }

  Future<void> _loadLearnedAdjacency() async {
    try {
      final snap = await _db.collection('spatialAdjacency').get();
      _learned.clear();
      for (final doc in snap.docs) {
        final from = (doc.data()['from'] ?? '').toString();
        final to = (doc.data()['to'] ?? '').toString();
        if (from.isEmpty || to.isEmpty) continue;
        _learned.putIfAbsent(from, () => {}).add(to);
        _learned.putIfAbsent(to, () => {}).add(from); // bidirectional
      }
    } catch (e) {
      debugPrint('load adjacency failed: $e');
    }
  }

  Future<void> _tick() async {
    final sample = await _wifi.scanOnce();
    if (sample == null || sample.readings.isEmpty) return;
    final raw = _wifi.predict(sample, _trained);
    if (raw == null) return;
    _consume(raw);
  }

  /// Apply the plausibility filter + smoothing to a raw prediction and publish.
  void _consume(LocationPrediction raw) {
    final plausible = _isPlausible(raw);
    // Reject an implausible jump unless it is overwhelmingly confident.
    if (!plausible && raw.confidence < 0.9 && _published != null) {
      return; // treated as noise; keep the last published position
    }

    // Auto-learn a genuine, confident transition between two different rooms.
    if (_published != null &&
        _published!.display != raw.display &&
        plausible &&
        raw.confidence >= 0.7) {
      _recordEdge(_published!.display, raw.display);
    }

    _window.add(raw);
    if (_window.length > _windowSize) _window.removeAt(0);
    _published = _smoothed();
    _controller.add(_published);
  }

  /// A raw prediction is plausible relative to the currently-published one.
  bool _isPlausible(LocationPrediction raw) {
    final prev = _published;
    if (prev == null) return true;
    if (prev.display == raw.display) return true;
    // Same block, same floor → walkable.
    if (prev.block == raw.block && prev.level == raw.level) return true;
    // Same block, one floor apart → via stairs/lift.
    if (prev.block == raw.block) {
      final a = _levelIndex(prev.level);
      final b = _levelIndex(raw.level);
      if (a != null && b != null && (a - b).abs() <= 1) return true;
    }
    // A previously-observed real transition.
    if (_learned[prev.display]?.contains(raw.display) ?? false) return true;
    return false;
  }

  /// Confidence-weighted majority room over the smoothing window.
  LocationPrediction _smoothed() {
    final votes = <String, double>{};
    final byKey = <String, LocationPrediction>{};
    for (final p in _window) {
      votes[p.display] = (votes[p.display] ?? 0) + p.confidence;
      byKey[p.display] = p;
    }
    final ordered = votes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = votes.values.fold<double>(0, (a, b) => a + b);
    final winner = byKey[ordered.first.key]!;
    final share = total == 0 ? winner.confidence : ordered.first.value / total;
    return LocationPrediction(
      block: winner.block,
      level: winner.level,
      placeName: winner.placeName,
      confidence: share.clamp(0, 1),
      voteShare: winner.voteShare,
    );
  }

  Future<void> _recordEdge(String from, String to) async {
    // Update local graph immediately.
    _learned.putIfAbsent(from, () => {}).add(to);
    _learned.putIfAbsent(to, () => {}).add(from);
    try {
      final id = _edgeId(from, to);
      await _db.collection('spatialAdjacency').doc(id).set({
        'from': from,
        'to': to,
        'weight': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('record edge failed: $e');
    }
  }

  /// Deterministic, order-independent edge id.
  String _edgeId(String a, String b) {
    final pair = [a, b]..sort();
    final raw = '${pair[0]}__${pair[1]}';
    return raw.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
  }

  /// Map a level label to a floor index for adjacency maths.
  int? _levelIndex(String level) {
    final l = level.toLowerCase().trim();
    if (l.contains('ground')) return 0;
    if (l.contains('rooftop') || l.contains('roof')) return 99;
    final m = RegExp(r'(\d+)').firstMatch(l);
    if (m != null) return int.tryParse(m.group(1)!);
    return null;
  }
}
