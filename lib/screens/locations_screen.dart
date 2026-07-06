import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../services/firestore_service.dart';
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
  late final TextEditingController search;

  String currentBlock = 'Academic Block A';
  String currentLevel = 'Ground floor';
  String selectedCategory = 'All';
  bool useLiftRoute = false;

  /// Coordinate for each campus block (used only to give the arrow guide a
  /// target bearing — there is no map view).
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

  static const categories = [
    'All',
    'Classroom',
    'Laboratory',
    'Faculty',
    'Support',
    'Office',
    'Study',
    'Facility',
    'Sports',
    'Residence',
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
    search.dispose();
    super.dispose();
  }

  LatLng? _coordFor(_CampusLocation location) {
    if (location.latitude != null && location.longitude != null) {
      return LatLng(location.latitude!, location.longitude!);
    }
    return buildingCoords[location.building];
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Classroom':
        return Icons.meeting_room;
      case 'Laboratory':
        return Icons.science;
      case 'Faculty':
        return Icons.school;
      case 'Support':
        return Icons.support_agent;
      case 'Office':
        return Icons.badge;
      case 'Study':
        return Icons.local_library;
      case 'Sports':
        return Icons.sports_soccer;
      case 'Residence':
        return Icons.hotel;
      default:
        return Icons.apartment;
    }
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
      (a, b) => '${a.category} ${a.name}'.compareTo('${b.category} ${b.name}'),
    );
    return locations;
  }

  bool _matches(_CampusLocation location) {
    final query = search.text.trim().toLowerCase();
    final categoryMatches =
        selectedCategory == 'All' || location.category == selectedCategory;
    if (!categoryMatches) return false;
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
      if (useLiftRoute)
        'Use lift-accessible paths where available and avoid stairs.',
      ...detailSteps,
      'Confirm the room label: ${location.room.isEmpty ? location.name : location.room}.',
    ];
  }

  Widget _searchBox() {
    return TextField(
      controller: search,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Search room, office, facility...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xffdbe5f2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xffdbe5f2)),
        ),
      ),
    );
  }

  Widget _categoryChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category == selectedCategory;
          return ChoiceChip(
            label: Text(category),
            selected: selected,
            showCheckmark: false,
            selectedColor: const Color(0xff2563eb),
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: selected ? Colors.white : const Color(0xff334155),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            side: BorderSide(
              color: selected
                  ? const Color(0xff2563eb)
                  : const Color(0xffdbe5f2),
            ),
            onSelected: (_) => setState(() => selectedCategory = category),
          );
        },
      ),
    );
  }

  Widget _startingPointPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.my_location, color: Color(0xff2563eb)),
          title: const Text(
            'Starting point',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '$currentBlock · $currentLevel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Set where you are so the indoor steps start correctly.',
                style: TextStyle(fontSize: 12, color: Color(0xff64748b)),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: currentBlock,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Block',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: blocks
                        .map(
                          (block) => DropdownMenuItem(
                            value: block,
                            child: Text(
                              block,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => currentBlock = value);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: currentLevel,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Level',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: levels
                        .map(
                          (level) => DropdownMenuItem(
                            value: level,
                            child: Text(
                              level,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => currentLevel = value);
                    },
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: useLiftRoute,
              onChanged: (v) => setState(() => useLiftRoute = v),
              title: const Text('Prefer lift route'),
              dense: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationRow(_CampusLocation location) {
    final color = const Color(0xff2563eb);
    final canGuide = _coordFor(location) != null;
    return InkWell(
      onTap: () => _openLocationSheet(location),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_categoryIcon(location.category), color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xff0f172a),
                    ),
                  ),
                  Text(
                    [
                      if (location.building.isNotEmpty) location.building,
                      if (location.level.isNotEmpty) location.level,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xff94a3b8),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Guide me',
              onPressed: canGuide ? () => _openArrowGuide(location) : null,
              icon: Icon(Icons.navigation, color: color),
            ),
          ],
        ),
      ),
    );
  }

  void _openLocationSheet(_CampusLocation location) {
    final steps = _directionSteps(location);
    final canGuide = _coordFor(location) != null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xffcbd5e1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xff2563eb).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _categoryIcon(location.category),
                    color: const Color(0xff2563eb),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        [
                          if (location.building.isNotEmpty) location.building,
                          if (location.level.isNotEmpty) location.level,
                          if (location.room.isNotEmpty) location.room,
                        ].join(' · '),
                        style: const TextStyle(color: Color(0xff64748b)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canGuide
                    ? () {
                        Navigator.pop(context);
                        _openArrowGuide(location);
                      }
                    : null,
                icon: const Icon(Icons.navigation),
                label: const Text('Start arrow guide'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Indoor directions',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 8),
            ...steps.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xffe0e7ff),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${entry.key + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xff4338ca),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(entry.value)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: const Color(0xfff6f8ff),
      appBar: AppBar(title: const Text('Campus Navigation')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.streamCollection('locations'),
        builder: (context, snapshot) {
          final loading = !snapshot.hasData && !snapshot.hasError;
          final docs = snapshot.data?.docs ?? [];
          final allLocations = _mergeLocations(docs);
          final locations = allLocations.where(_matches).toList();

          // Group filtered locations by category for section headers.
          final grouped = <String, List<_CampusLocation>>{};
          for (final loc in locations) {
            grouped.putIfAbsent(loc.category, () => []).add(loc);
          }
          final groupKeys = grouped.keys.toList()..sort();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _searchBox(),
              const SizedBox(height: 12),
              _NextClassShortcut(
                service: service,
                userId: userId,
                allLocations: allLocations,
                onNavigate: _openArrowGuide,
              ),
              const SizedBox(height: 12),
              _categoryChips(),
              const SizedBox(height: 12),
              _startingPointPanel(),
              const SizedBox(height: 8),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (locations.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.search_off, color: Color(0xff94a3b8)),
                        SizedBox(height: 8),
                        Text('No matching location found'),
                      ],
                    ),
                  ),
                )
              else
                ...groupKeys.map((category) {
                  final items = grouped[category]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
                        child: Text(
                          category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: Color(0xff94a3b8),
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xffe2e8f0)),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < items.length; i++) ...[
                              _locationRow(items[i]),
                              if (i != items.length - 1)
                                const Divider(height: 1),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _NextClassShortcut extends StatelessWidget {
  const _NextClassShortcut({
    required this.service,
    required this.userId,
    required this.allLocations,
    required this.onNavigate,
  });

  final FirestoreService service;
  final String userId;
  final List<_CampusLocation> allLocations;
  final ValueChanged<_CampusLocation> onNavigate;

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.streamUserTimetable(userId),
      builder: (context, snapshot) {
        final rows =
            snapshot.data?.docs
                .map((doc) => _ClassShortcutItem.fromMap(doc.data()))
                .whereType<_ClassShortcutItem>()
                .toList() ??
            const <_ClassShortcutItem>[];
        final nextClass = _nextUpcomingClass(rows);
        if (nextClass == null) return const SizedBox.shrink();

        final location = _findLocation(nextClass.room, allLocations);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff2563eb), Color(0xff7c3aed)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(Icons.bolt, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next: ${nextClass.courseCode}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${nextClass.startLabel} · ${nextClass.room.isEmpty ? nextClass.courseName : nextClass.room}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (location != null)
                FilledButton(
                  onPressed: () => onNavigate(location),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xff2563eb),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Text('Guide me'),
                ),
            ],
          ),
        );
      },
    );
  }

  static _ClassShortcutItem? _nextUpcomingClass(List<_ClassShortcutItem> rows) {
    if (rows.isEmpty) return null;
    final now = DateTime.now();
    final todayIndex = now.weekday - 1;

    _ClassShortcutItem? best;
    DateTime? bestTime;
    for (final row in rows) {
      final dayIndex = _dayIndex(row.day);
      final start = _parseTime(row.startTime);
      if (dayIndex == null || start == null) continue;

      var dayOffset = (dayIndex - todayIndex) % 7;
      var candidate = DateTime(
        now.year,
        now.month,
        now.day,
        start.hour,
        start.minute,
      ).add(Duration(days: dayOffset));
      if (!candidate.isAfter(now)) {
        candidate = candidate.add(const Duration(days: 7));
        dayOffset += 7;
      }

      if (bestTime == null || candidate.isBefore(bestTime)) {
        best = row.copyWith(startLabel: _formatStart(candidate, dayOffset));
        bestTime = candidate;
      }
    }
    return best;
  }

  static _CampusLocation? _findLocation(
    String rawRoom,
    List<_CampusLocation> locations,
  ) {
    final room = rawRoom.trim().toLowerCase();
    if (room.isEmpty) return null;
    final normalizedRoom = room.replaceAll(RegExp(r'[^a-z0-9]'), '');

    for (final location in locations) {
      final fields = [
        location.room,
        location.name,
        location.building,
      ].join(' ').toLowerCase();
      final normalizedFields = fields.replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (fields.contains(room) || normalizedFields.contains(normalizedRoom)) {
        return location;
      }
    }
    return null;
  }

  static int? _dayIndex(String day) {
    const days = {
      'monday': 0,
      'mon': 0,
      'tuesday': 1,
      'tue': 1,
      'wednesday': 2,
      'wed': 2,
      'thursday': 3,
      'thu': 3,
      'friday': 4,
      'fri': 4,
      'saturday': 5,
      'sat': 5,
      'sunday': 6,
      'sun': 6,
    };
    return days[day.trim().toLowerCase()];
  }

  static TimeOfDay? _parseTime(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    for (final pattern in ['HH:mm', 'H:mm', 'hh:mm a', 'h:mm a']) {
      try {
        final parsed = DateFormat(pattern).parseStrict(trimmed.toUpperCase());
        return TimeOfDay(hour: parsed.hour, minute: parsed.minute);
      } catch (_) {
        // Try the next common timetable format.
      }
    }
    return null;
  }

  static String _formatStart(DateTime value, int dayOffset) {
    final time = DateFormat('HH:mm').format(value);
    if (dayOffset == 0) return 'Today $time';
    if (dayOffset == 1) return 'Tomorrow $time';
    return '${DateFormat('EEE').format(value)} $time';
  }
}

class _ClassShortcutItem {
  const _ClassShortcutItem({
    required this.courseCode,
    required this.courseName,
    required this.day,
    required this.startTime,
    required this.room,
    this.startLabel = '',
  });

  final String courseCode;
  final String courseName;
  final String day;
  final String startTime;
  final String room;
  final String startLabel;

  static _ClassShortcutItem? fromMap(Map<String, dynamic> data) {
    final day = (data['day'] ?? '').toString();
    final startTime = (data['startTime'] ?? '').toString();
    if (day.trim().isEmpty || startTime.trim().isEmpty) return null;
    return _ClassShortcutItem(
      courseCode: (data['courseCode'] ?? 'Class').toString(),
      courseName: (data['courseName'] ?? '').toString(),
      day: day,
      startTime: startTime,
      room: (data['room'] ?? '').toString(),
    );
  }

  _ClassShortcutItem copyWith({String? startLabel}) {
    return _ClassShortcutItem(
      courseCode: courseCode,
      courseName: courseName,
      day: day,
      startTime: startTime,
      room: room,
      startLabel: startLabel ?? this.startLabel,
    );
  }
}
