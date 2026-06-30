import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import 'locations_screen.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

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

  void _openVenue(BuildContext context, String venue) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LocationsScreen(initialQuery: venue)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.streamCollection('events'),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = _publishedEvents(snapshot.data!.docs);
          if (docs.isEmpty) {
            return const Center(child: Text('No events available.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final venue = (data['venue'] ?? '').toString();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xffe0f2f1),
                            child: Icon(Icons.event, color: Colors.teal),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['title'] ?? 'Untitled Event',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(data['clubName'] ?? 'Campus event'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(data['description'] ?? ''),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            avatar: const Icon(Icons.calendar_today, size: 16),
                            label: Text(data['eventDate'] ?? '-'),
                          ),
                          Chip(
                            avatar: const Icon(Icons.schedule, size: 16),
                            label: Text(
                              '${data['startTime'] ?? '-'} - ${data['endTime'] ?? '-'}',
                            ),
                          ),
                          if (venue.isNotEmpty)
                            ActionChip(
                              avatar: const Icon(Icons.place, size: 16),
                              label: Text(venue),
                              onPressed: () => _openVenue(context, venue),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
