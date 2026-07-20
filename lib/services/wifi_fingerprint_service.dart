import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_scan/wifi_scan.dart';

/// One WiFi observation captured at a moment in time: which access points were
/// visible and their signal strength in dBm.
class WifiSample {
  /// map from BSSID (MAC address) to signal strength (RSSI, dBm, negative).
  final Map<String, int> readings;
  const WifiSample(this.readings);

  int get length => readings.length;
}

/// Separator used to build a composite vote key from block/level/place.
const String _sep = '␟';

/// A stored training sample tagged with a structured campus location
/// (block + level + place name). Older flat samples (a single `location`
/// string) still load, with empty block/level.
class Fingerprint {
  final String block;
  final String level;
  final String placeName;
  final Map<String, int> readings;

  const Fingerprint({
    required this.block,
    required this.level,
    required this.placeName,
    required this.readings,
  });

  /// Composite key used for voting.
  String get key => '$block$_sep$level$_sep$placeName';

  /// Human display, e.g. "Academic Block C · Level 2 · Physics Lab".
  String get display =>
      [block, level, placeName].where((s) => s.trim().isNotEmpty).join(' · ');

  factory Fingerprint.fromMap(Map<String, dynamic> data) {
    final raw = data['wifis'];
    final map = <String, int>{};
    if (raw is List) {
      for (final entry in raw) {
        if (entry is Map) {
          final bssid = (entry['bssid'] ?? '').toString();
          final rssi = (entry['rssi'] as num?)?.toInt();
          if (bssid.isNotEmpty && rssi != null) map[bssid] = rssi;
        }
      }
    }
    var block = (data['block'] ?? '').toString().trim();
    var level = (data['level'] ?? '').toString().trim();
    var placeName = (data['placeName'] ?? data['location'] ?? '')
        .toString()
        .trim();
    // Recover older flat entries such as "Block A Level 3 Rest Place".
    if (block.isEmpty && level.isEmpty) {
      final legacy = RegExp(
        r'^block\s+([a-e])\s+level\s+(\d+)\s+(.+)$',
        caseSensitive: false,
      ).firstMatch(placeName);
      if (legacy != null) {
        block = 'Academic Block ${legacy.group(1)!.toUpperCase()}';
        level = 'Level ${legacy.group(2)}';
        placeName = legacy.group(3)!.trim();
      }
    }
    return Fingerprint(
      block: block,
      level: level,
      placeName: placeName,
      readings: map,
    );
  }
}

/// Prediction of the current location from a live WiFi scan.
class LocationPrediction {
  final String block;
  final String level;
  final String placeName;
  final double confidence; // 0..1
  final Map<String, double> voteShare; // for showing runner-ups (by display)

  const LocationPrediction({
    required this.block,
    required this.level,
    required this.placeName,
    required this.confidence,
    required this.voteShare,
  });

  String get display =>
      [block, level, placeName].where((s) => s.trim().isNotEmpty).join(' · ');
}

/// A distinct trained place with how many samples back it.
class TrainedPlace {
  final String block;
  final String level;
  final String placeName;
  final int samples;
  const TrainedPlace({
    required this.block,
    required this.level,
    required this.placeName,
    required this.samples,
  });

  String get key => '$block$_sep$level$_sep$placeName';
  String get display =>
      [block, level, placeName].where((s) => s.trim().isNotEmpty).join(' · ');
}

/// Scans WiFi, stores fingerprints in Firestore, and does client-side k-nearest
/// neighbours matching to predict the current room. Deliberately kept simple
/// so the algorithm is defensible in a VIVA.
class WifiFingerprintService {
  static const int _k = 5; // k nearest neighbours
  static const int _missingRssiPenalty = -95; // dBm when a BSSID is seen in
  // only one of the pair
  final _db = FirebaseFirestore.instance;
  final _wifi = WiFiScan.instance;

  /// Location permission is required on Android for WiFi scan results to be
  /// populated. Silently no-ops on other platforms.
  Future<bool> ensurePermissions() async {
    if (kIsWeb) return false;
    try {
      final loc = await Permission.locationWhenInUse.request();
      return loc.isGranted;
    } catch (e) {
      debugPrint('wifi permission error: $e');
      return false;
    }
  }

  /// Triggers a fresh scan and returns the current WiFi readings.
  Future<WifiSample?> scanOnce() async {
    if (kIsWeb) return null;
    try {
      final canStart = await _wifi.canStartScan();
      if (canStart == CanStartScan.yes) {
        await _wifi.startScan();
      }
      final canGet = await _wifi.canGetScannedResults();
      if (canGet != CanGetScannedResults.yes) {
        debugPrint('wifi_scan canGetScannedResults: $canGet');
        return null;
      }
      final results = await _wifi.getScannedResults();
      final map = <String, int>{};
      for (final r in results) {
        if (r.bssid.isNotEmpty) map[r.bssid.toLowerCase()] = r.level;
      }
      return WifiSample(map);
    } catch (e) {
      debugPrint('wifi scanOnce failed: $e');
      return null;
    }
  }

  /// Saves a training sample tagged with a structured location.
  Future<void> saveSample({
    required String userId,
    required String block,
    required String level,
    required String placeName,
    required WifiSample sample,
  }) async {
    if (sample.readings.isEmpty) return;
    final display = [
      block,
      level,
      placeName,
    ].where((s) => s.trim().isNotEmpty).join(' · ');
    await _db.collection('wifiFingerprints').add({
      'userId': userId,
      'block': block,
      'level': level,
      'placeName': placeName,
      // keep a flat `location` string for backward compatibility + easy delete.
      'location': display,
      'wifis': sample.readings.entries
          .map((e) => {'bssid': e.key, 'rssi': e.value})
          .toList(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Loads the shared campus fingerprint map maintained by administrators.
  Future<List<Fingerprint>> loadFingerprints() async {
    final snap = await _db.collection('wifiFingerprints').get();
    return snap.docs.map((d) => Fingerprint.fromMap(d.data())).toList();
  }

  /// Distinct trained places with sample counts, for a coverage summary.
  Future<List<TrainedPlace>> trainedPlaces() async {
    final fps = await loadFingerprints();
    return _summarize(fps);
  }

  Stream<List<TrainedPlace>> streamTrainedPlaces() {
    return _db
        .collection('wifiFingerprints')
        .snapshots()
        .map(
          (snap) => _summarize(
            snap.docs.map((doc) => Fingerprint.fromMap(doc.data())).toList(),
          ),
        );
  }

  List<TrainedPlace> _summarize(List<Fingerprint> fps) {
    final counts = <String, int>{};
    final meta = <String, Fingerprint>{};
    for (final fp in fps) {
      counts[fp.key] = (counts[fp.key] ?? 0) + 1;
      meta[fp.key] = fp;
    }
    final places =
        meta.entries
            .map(
              (e) => TrainedPlace(
                block: e.value.block,
                level: e.value.level,
                placeName: e.value.placeName,
                samples: counts[e.key] ?? 0,
              ),
            )
            .toList()
          ..sort((a, b) => a.display.compareTo(b.display));
    return places;
  }

  /// Deletes every training sample tagged with [display] location.
  Future<void> deleteLocation({required String location}) async {
    final snap = await _db
        .collection('wifiFingerprints')
        .where('location', isEqualTo: location)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Convenience: scan + load this user's fingerprints + predict, in one call.
  /// Returns null when scanning isn't possible or there is no training data.
  Future<LocationPrediction?> detectCurrent() async {
    final sample = await scanOnce();
    if (sample == null || sample.readings.isEmpty) return null;
    final trained = await loadFingerprints();
    return predict(sample, trained);
  }

  /// Simple k-NN prediction. Distance = sqrt(mean squared RSSI diff) over the
  /// union of BSSIDs; a missing BSSID on either side is treated as
  /// [_missingRssiPenalty] so an unseen strong router hurts a lot.
  LocationPrediction? predict(WifiSample live, List<Fingerprint> trained) {
    if (trained.isEmpty || live.readings.isEmpty) return null;

    final distances = <_Scored>[];
    for (final fp in trained) {
      final bssids = <String>{...live.readings.keys, ...fp.readings.keys};
      double sum = 0;
      for (final bssid in bssids) {
        final a = live.readings[bssid] ?? _missingRssiPenalty;
        final b = fp.readings[bssid] ?? _missingRssiPenalty;
        final d = (a - b).toDouble();
        sum += d * d;
      }
      distances.add(_Scored(fp, math.sqrt(sum / bssids.length)));
    }
    distances.sort((a, b) => a.distance.compareTo(b.distance));
    final top = distances.take(_k).toList();

    // Weighted vote: closer neighbours count more (1 / (distance + 1)).
    final votes = <String, double>{};
    final byKey = <String, Fingerprint>{};
    for (final s in top) {
      votes[s.fp.key] = (votes[s.fp.key] ?? 0) + 1 / (s.distance + 1);
      byKey[s.fp.key] = s.fp;
    }
    final totalVotes = votes.values.fold<double>(0, (a, b) => a + b);
    final ordered = votes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final winnerKey = ordered.first.key;
    final winner = byKey[winnerKey]!;
    final voteShare = {
      for (final e in ordered) byKey[e.key]!.display: (e.value / totalVotes),
    };
    return LocationPrediction(
      block: winner.block,
      level: winner.level,
      placeName: winner.placeName,
      confidence: (ordered.first.value / totalVotes).clamp(0, 1),
      voteShare: voteShare,
    );
  }
}

class _Scored {
  final Fingerprint fp;
  final double distance;
  const _Scored(this.fp, this.distance);
}
