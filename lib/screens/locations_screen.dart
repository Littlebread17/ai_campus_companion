import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/firestore_service.dart';
import '../services/routing_service.dart';
import 'arrow_navigation_screen.dart';

class LocationsScreen extends StatefulWidget {
  final String initialQuery;

  const LocationsScreen({super.key, this.initialQuery = ''});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _CampusLocation {
  final String name;
  final String building;
  final String level;
  final String room;
  final String category;
  final String directionText;
  final List<String> keywords;

  /// Optional precise coordinate from Firestore. When null we fall back to the
  /// building's coordinate so older location records still appear on the map.
  final double? latitude;
  final double? longitude;

  const _CampusLocation({
    required this.name,
    required this.building,
    required this.level,
    required this.room,
    required this.category,
    required this.directionText,
    this.keywords = const [],
    this.latitude,
    this.longitude,
  });
}

class _LocationsScreenState extends State<LocationsScreen> {
  final service = FirestoreService();
  final routing = RoutingService();
  final mapController = MapController();
  late final TextEditingController search;

  String currentBlock = 'Academic Block A';
  String currentLevel = 'Ground floor';
  String locationNote =
      'Tap "Use GPS" to place yourself on the map, then pick a destination.';
  bool locating = false;

  LatLng? userLatLng;
  StreamSubscription<Position>? _positionSub;

  _CampusLocation? destination;
  List<LatLng> routePoints = [];
  String? routeSummary;
  bool routingInProgress = false;

  /// Campus centre used as the initial map focus (real surveyed point).
  static const campusCenter = LatLng(2.813998189213002, 101.75827328655846);

  /// Coordinate for each campus block, clustered around the real campus centre.
  /// These are approximate offsets — set a precise latitude/longitude per room
  /// in the admin Location form (or here) by copying the point from Google Maps
  /// for the most accurate arrow guidance.
  static const Map<String, LatLng> buildingCoords = {
    'Academic Block A': LatLng(2.814000, 101.758273),
    'Academic Block B': LatLng(2.814300, 101.758500),
    'Academic Block C': LatLng(2.813700, 101.758600),
    'Academic Block D': LatLng(2.813600, 101.758000),
    'Academic Block E': LatLng(2.813400, 101.758400),
    'Learning Resource Centre': LatLng(2.814400, 101.758100),
    'Student Centre': LatLng(2.813300, 101.758800),
    'Sports Complex': LatLng(2.814600, 101.758700),
    'Hall of Residence': LatLng(2.813100, 101.759000),
    'Service Building': LatLng(2.813800, 101.757800),
  };

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

  static const starterLocations = [
    _CampusLocation(
      name: 'Library',
      building: 'Learning Resource Centre',
      level: 'Level 1 and Level 2',
      room: 'LRC',
      category: 'Study',
      directionText:
          'Go to the Learning Resource Centre beside Academic Block; enter through the main LRC entrance; follow the library signs to Level 1 or Level 2.',
      keywords: ['library', 'lrc', 'study'],
    ),
    _CampusLocation(
      name: 'Lecture Theatre A and B',
      building: 'Learning Resource Centre',
      level: 'Level 1 and Level 2',
      room: 'LT A, LT B',
      category: 'Classroom',
      directionText:
          'Go to the Learning Resource Centre; enter from the campus side entrance; follow the lecture theatre signs near the library area.',
      keywords: ['lecture theatre', 'theatre', 'lta', 'ltb'],
    ),
    _CampusLocation(
      name: 'Reception',
      building: 'Academic Block A',
      level: 'Level 1',
      room: 'Reception',
      category: 'Support',
      directionText:
          'Head to Academic Block A; use the main entrance facing the assembly point; reception is on Level 1 near the entrance lobby.',
      keywords: ['reception', 'block a'],
    ),
    _CampusLocation(
      name: 'CPS Classrooms',
      building: 'Academic Block A',
      level: 'Level 1',
      room: 'Classrooms 3-12',
      category: 'Classroom',
      directionText:
          'Head to Academic Block A Level 1; follow classroom signs from reception; check the room number beside each classroom door.',
      keywords: ['cps', 'classroom', 'classrooms 3-12'],
    ),
    _CampusLocation(
      name: 'Lecture Room A1-01',
      building: 'Academic Block A',
      level: 'Level 1',
      room: 'A1-01',
      category: 'Classroom',
      directionText:
          'Head to Academic Block A Level 1; follow the corridor from reception; look for room A1-01.',
      keywords: ['a1-01', 'lecture room'],
    ),
    _CampusLocation(
      name: 'IT Services',
      building: 'Academic Block A',
      level: 'Level 2',
      room: 'IT Services',
      category: 'Support',
      directionText:
          'Go to Academic Block A; take the staircase or lift to Level 2; follow the IT Services signs.',
      keywords: ['it services', 'support'],
    ),
    _CampusLocation(
      name: 'Faculty of Data Science and Information Technology',
      building: 'Academic Block A',
      level: 'Level 3',
      room: 'A3-F01 to A3-F22',
      category: 'Faculty',
      directionText:
          'Go to Academic Block A; take the staircase or lift to Level 3; follow the faculty room number signs A3-F01 to A3-F22.',
      keywords: ['fdsit', 'data science', 'information technology', 'a3'],
    ),
    _CampusLocation(
      name: 'Lecture Theatre 1 and 2',
      building: 'Academic Block B',
      level: 'Level 1',
      room: 'Lecture Theatre 1, Lecture Theatre 2',
      category: 'Classroom',
      directionText:
          'Head to Academic Block B; enter from the Academic Block walkway; lecture theatres are on Level 1.',
      keywords: ['block b', 'lecture theatre 1', 'lecture theatre 2'],
    ),
    _CampusLocation(
      name: 'Lecture Rooms B3-03 to B3-15',
      building: 'Academic Block B',
      level: 'Level 3',
      room: 'B3-03 to B3-15',
      category: 'Classroom',
      directionText:
          'Head to Academic Block B; go to Level 3; follow the B3 corridor room labels.',
      keywords: ['b3-03', 'b3-15', 'block b'],
    ),
    _CampusLocation(
      name: 'Lecture Rooms B5-01 to B5-13',
      building: 'Academic Block B',
      level: 'Level 5',
      room: 'B5-01 to B5-13',
      category: 'Classroom',
      directionText:
          'Head to Academic Block B; go to Level 5; follow the B5 corridor room labels.',
      keywords: ['b5-01', 'b5-13', 'block b'],
    ),
    _CampusLocation(
      name: 'Surau',
      building: 'Academic Block C',
      level: 'Level 1',
      room: 'Prayer Room',
      category: 'Facility',
      directionText:
          'Head to Academic Block C Level 1; follow the Surau or prayer room signs.',
      keywords: ['surau', 'prayer', 'block c'],
    ),
    _CampusLocation(
      name: 'Physics Laboratory',
      building: 'Academic Block C',
      level: 'Level 2',
      room: 'Physics Laboratory 1 and 2',
      category: 'Laboratory',
      directionText:
          'Head to Academic Block C; take the stairs or lift to Level 2; follow laboratory signs for Physics Laboratory 1 and 2.',
      keywords: ['physics', 'lab', 'block c'],
    ),
    _CampusLocation(
      name: 'Faculty of Business and Communications',
      building: 'Academic Block C',
      level: 'Level 3',
      room: 'Faculty Rooms',
      category: 'Faculty',
      directionText:
          'Head to Academic Block C; go to Level 3; follow signs to Faculty of Business and Communications.',
      keywords: ['business', 'communications', 'faculty', 'block c'],
    ),
    _CampusLocation(
      name: 'Engineering Laboratories',
      building: 'Academic Block C',
      level: 'Level 4',
      room: 'Engineering Laboratories',
      category: 'Laboratory',
      directionText:
          'Head to Academic Block C; go to Level 4; follow the engineering laboratory signs.',
      keywords: ['engineering lab', 'bim', 'block c'],
    ),
    _CampusLocation(
      name: 'Admission and Counselling Office',
      building: 'Academic Block D',
      level: 'Level 1',
      room: 'Admission and Counselling Office',
      category: 'Support',
      directionText:
          'Head to Academic Block D Level 1; follow the signs for Admission and Counselling Office near the administrative area.',
      keywords: ['admission', 'counselling', 'block d'],
    ),
    _CampusLocation(
      name: 'Office of Admissions and Record',
      building: 'Academic Block D',
      level: 'Level 2',
      room: 'OAR',
      category: 'Support',
      directionText:
          'Head to Academic Block D; go to Level 2; follow signs to Office of Admissions and Record.',
      keywords: ['oar', 'admissions', 'record'],
    ),
    _CampusLocation(
      name: 'Lecture Room D3-01',
      building: 'Academic Block D',
      level: 'Level 3',
      room: 'D3-01',
      category: 'Classroom',
      directionText:
          'Head to Academic Block D; go to Level 3; follow the corridor labels to D3-01.',
      keywords: ['d3-01', 'block d'],
    ),
    _CampusLocation(
      name: 'Human Resources Office',
      building: 'Academic Block D',
      level: 'Level 4',
      room: 'Human Resources Office',
      category: 'Office',
      directionText:
          'Head to Academic Block D; go to Level 4; follow signs for Human Resources Office.',
      keywords: ['hr', 'human resources'],
    ),
    _CampusLocation(
      name: 'Engineering Laboratories',
      building: 'Academic Block E',
      level: 'Level 3 and Level 4',
      room: 'Engineering Laboratories',
      category: 'Laboratory',
      directionText:
          'Head to Academic Block E; use the stairs or lift to Level 3 or Level 4; follow engineering laboratory signs.',
      keywords: ['block e', 'engineering', 'lab'],
    ),
    _CampusLocation(
      name: 'Student Centre',
      building: 'Student Centre',
      level: 'Lower Ground to Rooftop',
      room: 'Student Centre',
      category: 'Facility',
      directionText:
          'Head to the Student Centre beside the swimming pool; choose the listed floor for cafeteria, clinic, student activity room, gym, or pool.',
      keywords: ['student centre', 'cafeteria', 'clinic', 'gym', 'pool'],
    ),
    _CampusLocation(
      name: 'Sports Complex',
      building: 'Sports Complex',
      level: 'Ground floor',
      room: 'Sports Complex',
      category: 'Sports',
      directionText:
          'Head to the sports complex beside the Learning Resource Centre; use the entrance facing the courts.',
      keywords: ['sports', 'court', 'basketball', 'football'],
    ),
    _CampusLocation(
      name: 'Hall of Residence',
      building: 'Hall of Residence',
      level: 'Ground floor',
      room: 'Accommodation blocks',
      category: 'Residence',
      directionText:
          'Head to the Hall of Residence area opposite the Student Centre; follow the residence block name signs.',
      keywords: ['hostel', 'residence', 'accommodation'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    search = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    search.dispose();
    super.dispose();
  }

  /// Resolve a location to a map coordinate: prefer its own lat/lng, then its
  /// building coordinate, otherwise null (not shown on the map).
  LatLng? _coordFor(_CampusLocation location) {
    if (location.latitude != null && location.longitude != null) {
      return LatLng(location.latitude!, location.longitude!);
    }
    return buildingCoords[location.building];
  }

  Future<void> detectPosition() async {
    setState(() {
      locating = true;
      locationNote = 'Checking phone GPS...';
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          locationNote =
              'Location service is off. Confirm your block manually.';
          locating = false;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          locationNote =
              'Location permission was not allowed. Confirm your block manually.';
          locating = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (!mounted) return;
      final here = LatLng(position.latitude, position.longitude);
      setState(() {
        userLatLng = here;
        locationNote =
            'Live GPS active (about ${position.accuracy.round()}m accuracy). Pick a destination to draw the walking route.';
        locating = false;
      });
      mapController.move(here, 17);
      _startLiveTracking();
      // Re-route from the new position if a destination is already chosen.
      if (destination != null) _route(destination!);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        locationNote =
            'Unable to read GPS now. Confirm your block and level manually.';
        locating = false;
      });
    }
  }

  void _startLiveTracking() {
    _positionSub?.cancel();
    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 3,
          ),
        ).listen((position) {
          if (!mounted) return;
          setState(() {
            userLatLng = LatLng(position.latitude, position.longitude);
          });
        });
  }

  Future<void> _route(_CampusLocation target) async {
    final destCoord = _coordFor(target);
    setState(() {
      destination = target;
      routeSummary = null;
      routePoints = [];
      routingInProgress = userLatLng != null && destCoord != null;
    });

    if (destCoord == null) {
      setState(() {
        routeSummary = 'No map coordinate for this place yet. '
            'Use the indoor steps below.';
      });
      return;
    }
    if (userLatLng == null) {
      setState(() {
        routeSummary = 'Tap "Use GPS" first to draw a route from where you are.';
      });
      mapController.move(destCoord, 17);
      return;
    }

    final route = await routing.getWalkingRoute(userLatLng!, destCoord);
    if (!mounted) return;

    if (route == null) {
      // Fallback: straight line if the routing server is unreachable.
      final straight = const Distance().as(
        LengthUnit.Meter,
        userLatLng!,
        destCoord,
      );
      setState(() {
        routePoints = [userLatLng!, destCoord];
        routeSummary =
            'Approx ${straight.round()} m (straight line — routing offline).';
        routingInProgress = false;
      });
    } else {
      setState(() {
        routePoints = route.points;
        routeSummary = '${route.distanceLabel} · ${route.etaLabel}';
        routingInProgress = false;
      });
    }
    _fitRoute(destCoord);
  }

  void _fitRoute(LatLng destCoord) {
    final pts = routePoints.isNotEmpty ? routePoints : [userLatLng!, destCoord];
    final bounds = LatLngBounds.fromPoints(pts);
    mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
    );
  }

  void _openArrowGuide(_CampusLocation location) {
    final coord = _coordFor(location);
    if (coord == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArrowNavigationScreen(
          destinationName: location.name,
          destinationLatitude: coord.latitude,
          destinationLongitude: coord.longitude,
          indoorSteps: _directionSteps(location),
        ),
      ),
    );
  }

  void _clearRoute() {
    setState(() {
      destination = null;
      routePoints = [];
      routeSummary = null;
    });
  }

  _CampusLocation _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final rawKeywords = data['keywords'];
    final keywords = rawKeywords is List
        ? rawKeywords.map((item) => item.toString()).toList()
        : <String>[];
    return _CampusLocation(
      name: (data['name'] ?? 'Location').toString(),
      building: (data['building'] ?? '').toString(),
      level: (data['level'] ?? '').toString(),
      room: (data['room'] ?? '').toString(),
      category: (data['category'] ?? 'Facility').toString(),
      directionText: (data['directionText'] ?? '').toString(),
      keywords: keywords,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
    );
  }

  List<_CampusLocation> _mergeLocations(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final locations = docs.map(_fromDoc).toList();
    for (final fallback in starterLocations) {
      final exists = locations.any(
        (item) =>
            item.name.toLowerCase() == fallback.name.toLowerCase() &&
            item.room.toLowerCase() == fallback.room.toLowerCase(),
      );
      if (!exists) locations.add(fallback);
    }
    locations.sort(
      (a, b) => '${a.building} ${a.name}'.compareTo('${b.building} ${b.name}'),
    );
    return locations;
  }

  bool _matches(_CampusLocation location) {
    final query = search.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    final haystack = [
      location.name,
      location.building,
      location.level,
      location.room,
      location.category,
      ...location.keywords,
    ].join(' ').toLowerCase();
    return haystack.contains(query);
  }

  List<String> _directionSteps(_CampusLocation location) {
    final detailSteps = location.directionText
        .split(';')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    return [
      'Start from $currentBlock, $currentLevel.',
      ...detailSteps,
      'Confirm the room label: ${location.room.isEmpty ? location.name : location.room}.',
    ];
  }

  IconData _stepIcon(int index, int lastIndex) {
    if (index == 0) return Icons.my_location;
    if (index == lastIndex) return Icons.flag;
    if (index == 1) return Icons.directions_walk;
    if (index == 2) return Icons.stairs;
    return Icons.arrow_forward;
  }

  Widget _liveMap(List<_CampusLocation> locations) {
    final markers = <Marker>[];

    for (final location in locations) {
      final coord = _coordFor(location);
      if (coord == null) continue;
      final isDestination = identical(location, destination) ||
          (destination != null &&
              location.name == destination!.name &&
              location.room == destination!.room);
      markers.add(
        Marker(
          point: coord,
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => _route(location),
            child: Icon(
              Icons.location_on,
              color: isDestination ? Colors.red : Colors.purple,
              size: isDestination ? 40 : 30,
            ),
          ),
        ),
      );
    }

    if (userLatLng != null) {
      markers.add(
        Marker(
          point: userLatLng!,
          width: 26,
          height: 26,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4),
              ],
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 300,
        child: FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: userLatLng ?? campusCenter,
            initialZoom: 17,
            minZoom: 14,
            maxZoom: 19,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.ai_campus_companion',
              maxZoom: 19,
            ),
            if (routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routePoints,
                    strokeWidth: 5,
                    color: Colors.blue,
                  ),
                ],
              ),
            MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }

  Widget _routeBanner() {
    if (destination == null) return const SizedBox.shrink();
    return Card(
      color: const Color(0xffe8f0fe),
      child: ListTile(
        leading: routingInProgress
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.directions_walk, color: Colors.blue),
        title: Text(
          'To ${destination!.name}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(routeSummary ?? 'Finding the best walking route...'),
        trailing: IconButton(
          tooltip: 'Clear route',
          icon: const Icon(Icons.close),
          onPressed: _clearRoute,
        ),
      ),
    );
  }

  Widget _currentLocationPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.my_location, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Current starting point',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: locating ? null : detectPosition,
                  icon: locating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.gps_fixed, size: 18),
                  label: Text(locating ? 'Locating' : 'Use GPS'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(locationNote),
            const SizedBox(height: 12),
            const Text(
              'Indoor handoff: confirm the block and level you are on so the '
              'step-by-step indoor directions start correctly.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: currentBlock,
              decoration: const InputDecoration(
                labelText: 'Block',
                border: OutlineInputBorder(),
              ),
              items: blocks
                  .map(
                    (block) =>
                        DropdownMenuItem(value: block, child: Text(block)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => currentBlock = value);
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: currentLevel,
              decoration: const InputDecoration(
                labelText: 'Level',
                border: OutlineInputBorder(),
              ),
              items: levels
                  .map(
                    (level) =>
                        DropdownMenuItem(value: level, child: Text(level)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => currentLevel = value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationCard(_CampusLocation location) {
    final steps = _directionSteps(location);
    final hasCoord = _coordFor(location) != null;
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.place, color: Colors.purple),
        title: Text(location.name),
        subtitle: Text(
          [
            if (location.building.isNotEmpty) location.building,
            if (location.level.isNotEmpty) location.level,
            if (location.room.isNotEmpty) location.room,
          ].join(' - '),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            avatar: const Icon(Icons.category, size: 16),
                            label: Text(location.category),
                          ),
                          Chip(
                            avatar: const Icon(Icons.near_me, size: 16),
                            label: Text('From $currentBlock'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (hasCoord)
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _openArrowGuide(location),
                        icon: const Icon(Icons.navigation),
                        label: const Text('Arrow guide'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _route(location),
                        icon: const Icon(Icons.map),
                        label: const Text('Show on map'),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Indoor steps',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                ...steps.asMap().entries.map((entry) {
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(_stepIcon(entry.key, steps.length - 1)),
                    title: Text(entry.value),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campus Navigation')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.streamCollection('locations'),
        builder: (context, snapshot) {
          final hasError = snapshot.hasError;
          final loading = !snapshot.hasData && !hasError;
          final docs = snapshot.data?.docs ?? [];
          final allLocations = _mergeLocations(docs);
          final locations = allLocations.where(_matches).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _liveMap(allLocations),
              const SizedBox(height: 10),
              _routeBanner(),
              const SizedBox(height: 4),
              TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Search room, block, or facility',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          onPressed: () {
                            search.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close),
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              _currentLocationPanel(),
              if (hasError)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Using built-in campus locations'),
                    subtitle: Text('${snapshot.error}'),
                  ),
                ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!loading && locations.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.search_off),
                    title: Text('No matching location found'),
                  ),
                )
              else if (!loading)
                ...locations.map(_locationCard),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}
