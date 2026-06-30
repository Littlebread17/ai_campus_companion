import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

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
  final List<String> indoorSteps;

  const ArrowNavigationScreen({
    super.key,
    required this.destinationName,
    required this.destinationLatitude,
    required this.destinationLongitude,
    this.indoorSteps = const [],
  });

  @override
  State<ArrowNavigationScreen> createState() => _ArrowNavigationScreenState();
}

class _ArrowNavigationScreenState extends State<ArrowNavigationScreen> {
  static const double arrivalRadiusMeters = 15;
  static const double _walkingSpeedMps = 1.35; // ~4.9 km/h

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<CompassEvent>? _compassSub;

  LatLng? _userLatLng;
  double? _headingDegrees; // device facing direction, 0 = north
  double? _gpsCourse; // fallback heading from GPS movement
  double _gpsAccuracy = 0;
  String _status = 'Getting your location...';
  bool _arrived = false;

  LatLng get _destination =>
      LatLng(widget.destinationLatitude, widget.destinationLongitude);

  @override
  void initState() {
    super.initState();
    _startLocation();
    _startCompass();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _compassSub?.cancel();
    super.dispose();
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
        setState(() => _status = 'Location permission is required to guide you.');
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
              _userLatLng = LatLng(position.latitude, position.longitude);
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
    final x = math.cos(lat1) * math.sin(lat2) -
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
    if (_userLatLng == null) {
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
      _userLatLng!,
      _destination,
    );

    if (meters <= arrivalRadiusMeters) {
      _arrived = true;
    }
    if (_arrived) return _arrivedView(meters);

    final bearing = _bearingToDestination(_userLatLng!, _destination);
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
          const SizedBox(height: 24),
          if (_gpsAccuracy > 25)
            const Card(
              color: Color(0xfffff4e5),
              child: ListTile(
                leading: Icon(Icons.warning_amber, color: Colors.orange),
                title: Text('Weak GPS signal'),
                subtitle: Text(
                  'Move to an open area for a more accurate arrow.',
                ),
              ),
            ),
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
          child: const Icon(
            Icons.navigation,
            size: 140,
            color: Colors.blue,
          ),
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

  Widget _arrivedView(double meters) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.flag_circle, color: Colors.green, size: 96),
          const SizedBox(height: 12),
          Text(
            'You have reached ${widget.destinationName}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Now follow the indoor steps to your exact room.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          if (widget.indoorSteps.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('No indoor steps provided for this location.'),
              ),
            )
          else
            ...widget.indoorSteps.asMap().entries.map(
              (entry) => Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${entry.key + 1}')),
                  title: Text(entry.value),
                ),
              ),
            ),
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
