import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/indoor_step.dart';
import '../services/live_positioning_service.dart';
import '../utils/campus_coords.dart';
import '../utils/location_search.dart';

/// Full-screen "follow the arrow" walking guide.
///
/// A large arrow rotates to point at the destination using the phone compass
/// (magnetometer) combined with live GPS. It shows the live distance, a walking
/// ETA, and a plain turn hint (go straight / turn left / turn right / arrived).
/// When the student gets within [arrivalRadiusMeters] of the destination, it
/// switches to the indoor step-by-step list.
class ArrowNavigationScreen extends StatefulWidget {
  final String destinationName;
  final double destinationLatitude;
  final double destinationLongitude;
  final List<IndoorStep> indoorSteps;

  /// Block/level of the destination, used to auto-detect indoor arrival from the
  /// WiFi fingerprint when GPS is unreliable indoors.
  final String destinationBlock;
  final String destinationLevel;
  final String destinationPlace;
  final String guidanceVia;

  const ArrowNavigationScreen({
    super.key,
    required this.destinationName,
    required this.destinationLatitude,
    required this.destinationLongitude,
    this.indoorSteps = const [],
    this.destinationBlock = '',
    this.destinationLevel = '',
    this.destinationPlace = '',
    this.guidanceVia = '',
  });

  @override
  State<ArrowNavigationScreen> createState() => _ArrowNavigationScreenState();
}

class _ArrowNavigationScreenState extends State<ArrowNavigationScreen> {
  static const double arrivalRadiusMeters = 15;
  static const double _walkingSpeedMps = 1.35; // ~4.9 km/h

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<CompassEvent>? _compassSub;
  StreamSubscription<LocationPrediction?>? _posSub;

  LatLng? _gpsLatLng;
  double? _headingDegrees; // device facing direction, 0 = north
  double? _gpsCourse; // fallback heading from GPS movement
  double _gpsAccuracy = 0;
  String _status = 'Getting your location...';
  bool _arrived = false;

  // Live indoor position from the WiFi fingerprint service.
  LocationPrediction? _livePos;
  int _reachedStep = -1; // highest indoor step index reached so far

  LatLng get _destination =>
      LatLng(widget.destinationLatitude, widget.destinationLongitude);

  bool get _usingWifiEstimate {
    final p = _livePos;
    return p != null &&
        p.confidence >= 0.7 &&
        CampusCoords.forBlock(p.block) != null &&
        (_gpsLatLng == null || _gpsAccuracy > 25);
  }

  LatLng? get _effectiveUserLatLng =>
      _usingWifiEstimate ? CampusCoords.forBlock(_livePos!.block) : _gpsLatLng;

  @override
  void initState() {
    super.initState();
    _startLocation();
    _startCompass();
    _startPositioning();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _compassSub?.cancel();
    _posSub?.cancel();
    LivePositioningService.instance.stop();
    super.dispose();
  }

  Future<void> _startPositioning() async {
    _posSub = LivePositioningService.instance.stream.listen(_onLivePosition);
    await LivePositioningService.instance.start();
  }

  void _onLivePosition(LocationPrediction? p) {
    if (!mounted || p == null) return;
    setState(() {
      _livePos = p;
      // Auto-arrival: predicted room matches the destination building/level.
      if (!_arrived && p.confidence >= 0.55 && _matchesDestination(p)) {
        _arrived = true;
      }
      // Auto-progress indoor steps.
      for (var i = 0; i < widget.indoorSteps.length; i++) {
        final step = widget.indoorSteps[i];
        if (step.hasTag &&
            step.matchedBy(
              block: p.block,
              level: p.level,
              place: p.placeName,
            ) &&
            i > _reachedStep) {
          _reachedStep = i;
        }
      }
    });
  }

  bool _matchesDestination(LocationPrediction p) {
    if (widget.destinationBlock.isEmpty) return false;
    if (p.block.toLowerCase() != widget.destinationBlock.toLowerCase()) {
      return false;
    }
    if (widget.destinationLevel.isNotEmpty) {
      if (normalizeLocationText(p.level) !=
          normalizeLocationText(widget.destinationLevel)) {
        return false;
      }
    }
    if (widget.destinationPlace.isNotEmpty) {
      return normalizeLocationText(p.placeName) ==
          normalizeLocationText(widget.destinationPlace);
    }
    return true;
  }

  Future<void> _startLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() => _status = 'Turn on location service to start guidance.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(
          () => _status = 'Location permission is required to guide you.',
        );
        return;
      }

      _positionSub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 1,
            ),
          ).listen((position) {
            if (!mounted) return;
            setState(() {
              _gpsLatLng = LatLng(position.latitude, position.longitude);
              _gpsAccuracy = position.accuracy;
              if (position.speed > 0.6) {
                // Only trust GPS course when actually moving.
                _gpsCourse = position.heading;
              }
              _status = '';
            });
          });
    } catch (e) {
      if (mounted) setState(() => _status = 'Location error: $e');
    }
  }

  void _startCompass() {
    final events = FlutterCompass.events;
    if (events == null) return; // No magnetometer (e.g. desktop/web).
    _compassSub = events.listen((event) {
      if (!mounted) return;
      final heading = event.heading;
      if (heading == null) return;
      setState(() => _headingDegrees = heading);
    });
  }

  /// Compass bearing from the user to the destination, 0-360 (0 = north).
  double _bearingToDestination(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  /// Normalize an angle to the range -180..180.
  double _relativeAngle(double bearing, double heading) {
    var diff = bearing - heading;
    while (diff > 180) {
      diff -= 360;
    }
    while (diff < -180) {
      diff += 360;
    }
    return diff;
  }

  String _turnHint(double relative) {
    final a = relative.abs();
    if (a <= 20) return 'Go straight ahead';
    if (a >= 150) return 'Turn around';
    if (relative > 0) {
      return a <= 75 ? 'Turn right' : 'Sharp right';
    }
    return a <= 75 ? 'Turn left' : 'Sharp left';
  }

  String _etaLabel(double meters) {
    final minutes = (meters / _walkingSpeedMps / 60).ceil();
    if (minutes <= 1) return '1 min';
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Guide: ${widget.destinationName}')),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    final userLocation = _effectiveUserLatLng;
    if (userLocation == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_status, textAlign: TextAlign.center),
            ),
          ],
        ),
      );
    }

    final meters = const Distance().as(
      LengthUnit.Meter,
      userLocation,
      _destination,
    );

    if (meters <= arrivalRadiusMeters) {
      _arrived = true;
    }
    if (_arrived) return _arrivedView(meters);

    final bearing = _bearingToDestination(userLocation, _destination);
    final heading = _headingDegrees ?? _gpsCourse;
    final hasHeading = heading != null;
    final relative = hasHeading ? _relativeAngle(bearing, heading) : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            hasHeading ? _turnHint(relative) : 'Point your phone forward',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            hasHeading
                ? 'Follow the arrow to ${widget.destinationName}'
                : 'Compass not available — arrow shows the compass direction',
            style: const TextStyle(color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _arrowDial(bearing, heading, relative),
          const SizedBox(height: 32),
          _metricsRow(meters),
          const SizedBox(height: 16),
          if (_livePos != null) _livePositionChip(),
          const SizedBox(height: 12),
          _positioningStatus(),
        ],
      ),
    );
  }

  Widget _arrowDial(double bearing, double? heading, double relative) {
    // Arrow points up when the destination is directly ahead. If we have no
    // heading, fall back to showing the absolute compass bearing.
    final rotationDegrees = heading != null ? relative : bearing;
    final rotationRadians = rotationDegrees * math.pi / 180;

    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xffeef3fb),
        border: Border.all(color: const Color(0xffc9d6ea), width: 6),
      ),
      child: Center(
        child: Transform.rotate(
          angle: rotationRadians,
          child: const Icon(Icons.navigation, size: 140, color: Colors.blue),
        ),
      ),
    );
  }

  Widget _metricsRow(double meters) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _metric(
          Icons.straighten,
          meters < 1000
              ? '${meters.round()} m'
              : '${(meters / 1000).toStringAsFixed(2)} km',
          'Distance',
        ),
        _metric(Icons.schedule, _etaLabel(meters), 'Walking ETA'),
      ],
    );
  }

  Widget _metric(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 28),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        Text(label, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }

  Widget _livePositionChip() {
    final p = _livePos!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xffe0f2fe),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.my_location, size: 16, color: Color(0xff0284c7)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'You are in ${p.display}  (${(p.confidence * 100).round()}%)',
              style: const TextStyle(fontSize: 12, color: Color(0xff0369a1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _positioningStatus() {
    if (_usingWifiEstimate) {
      return Card(
        color: const Color(0xffecfdf5),
        child: ListTile(
          leading: const Icon(Icons.wifi, color: Color(0xff16a34a)),
          title: const Text('Using WiFi indoor estimate'),
          subtitle: Text(
            _gpsAccuracy > 0
                ? 'GPS is weak (about +/- ${_gpsAccuracy.round()} m).'
                : 'GPS is unavailable.',
          ),
        ),
      );
    }
    if (_gpsAccuracy > 25) {
      return const Card(
        color: Color(0xfffff4e5),
        child: ListTile(
          leading: Icon(Icons.warning_amber, color: Colors.orange),
          title: Text('Weak GPS signal'),
          subtitle: Text('Move to an open area for a more accurate arrow.'),
        ),
      );
    }
    return Card(
      child: ListTile(
        leading: const Icon(Icons.gps_fixed, color: Color(0xff2563eb)),
        title: const Text('Using GPS'),
        subtitle: Text('Accuracy is about +/- ${_gpsAccuracy.round()} m.'),
      ),
    );
  }

  Widget _arrivedView(double meters) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.flag_circle, color: Colors.green, size: 96),
          const SizedBox(height: 12),
          Text(
            widget.guidanceVia.isEmpty
                ? 'You have reached ${widget.destinationName}'
                : 'You have reached ${widget.guidanceVia}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            widget.guidanceVia.isEmpty
                ? 'Now follow the indoor steps to your exact room.'
                : 'Continue with the remaining directions to ${widget.destinationName}.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          if (_livePos != null) ...[
            _livePositionChip(),
            const SizedBox(height: 12),
          ],
          if (widget.indoorSteps.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('No indoor steps provided for this location.'),
              ),
            )
          else
            ...widget.indoorSteps.asMap().entries.map((entry) {
              final done = entry.key <= _reachedStep;
              final active = entry.key == _reachedStep + 1;
              return Card(
                color: done ? const Color(0xffecfdf5) : null,
                shape: active
                    ? RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(
                          color: Color(0xff2563eb),
                          width: 1.5,
                        ),
                      )
                    : null,
                child: ListTile(
                  leading: done
                      ? const CircleAvatar(
                          backgroundColor: Color(0xff16a34a),
                          child: Icon(Icons.check, color: Colors.white),
                        )
                      : CircleAvatar(
                          backgroundColor: active
                              ? const Color(0xff2563eb)
                              : const Color(0xffe2e8f0),
                          foregroundColor: active
                              ? Colors.white
                              : Colors.black54,
                          child: Text('${entry.key + 1}'),
                        ),
                  title: Text(
                    entry.value.text,
                    style: TextStyle(
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? const Color(0xff64748b) : null,
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => setState(() => _arrived = false),
            icon: const Icon(Icons.navigation),
            label: const Text('Back to arrow guide'),
          ),
        ],
      ),
    );
  }
}
