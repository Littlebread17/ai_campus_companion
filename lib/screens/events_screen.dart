import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../widgets/event_poster.dart';
import 'event_detail_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final _service = FirestoreService();
  bool _joinedOnly = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _publishedEvents(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final events = docs.where((doc) {
      final status = (doc.data()['status'] ?? 'published').toString();
      return status == 'published';
    }).toList();
    events.sort((a, b) {
      final left =
          '${a.data()['eventDate'] ?? ''} ${a.data()['startTime'] ?? ''}';
      final right =
          '${b.data()['eventDate'] ?? ''} ${b.data()['startTime'] ?? ''}';
      return left.compareTo(right);
    });
    return events;
  }

  bool _isJoined(Map<String, dynamic> data) {
    final attendees = (data['attendees'] as List?) ?? [];
    return attendees.contains(_uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _service.streamCollection('events'),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = _publishedEvents(snapshot.data!.docs);
          final joinedCount = all.where((d) => _isJoined(d.data())).length;
          final docs =
              _joinedOnly ? all.where((d) => _isJoined(d.data())).toList() : all;

          return Column(
            children: [
              _filterBar(all.length, joinedCount),
              Expanded(
                child: docs.isEmpty
                    ? Center(
                        child: Text(
                          _joinedOnly
                              ? "You haven't joined any events yet."
                              : 'No events available.',
                          style: const TextStyle(color: Color(0xff64748b)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) =>
                            _eventCard(docs[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterBar(int allCount, int joinedCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          ChoiceChip(
            label: Text('All ($allCount)'),
            selected: !_joinedOnly,
            onSelected: (_) => setState(() => _joinedOnly = false),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text('Joined ($joinedCount)'),
            selected: _joinedOnly,
            onSelected: (_) => setState(() => _joinedOnly = true),
          ),
        ],
      ),
    );
  }

  Widget _eventCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final attendees = (data['attendees'] as List?) ?? [];
    final joined = attendees.contains(_uid);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EventDetailScreen(eventId: doc.id),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                EventPoster(
                  title: (data['title'] ?? 'Event').toString(),
                  host: (data['clubName'] ?? '').toString(),
                  posterUrl: (data['posterUrl'] ?? '').toString(),
                  height: 150,
                ),
                if (joined)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xff16a34a),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Joined',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (data['title'] ?? 'Untitled Event').toString(),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 14, color: Color(0xff64748b)),
                      const SizedBox(width: 6),
                      Text('${data['eventDate'] ?? '-'}'),
                      const SizedBox(width: 14),
                      const Icon(Icons.schedule,
                          size: 14, color: Color(0xff64748b)),
                      const SizedBox(width: 6),
                      Text('${data['startTime'] ?? ''}'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
