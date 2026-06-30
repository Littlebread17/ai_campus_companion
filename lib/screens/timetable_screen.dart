import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'locations_screen.dart';

class TimetableScreen extends StatelessWidget {
  const TimetableScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final service = FirestoreService();
    return Scaffold(
      appBar: AppBar(title: const Text('Timetable')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.streamUserTimetable(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty)
            return const Center(
              child: Text('No timetable found for this user.'),
            );
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final d = docs[index].data();
              final room = (d['room'] ?? '').toString();
              return Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.calendar_month,
                    color: Colors.green,
                  ),
                  title: Text(
                    '${d['courseCode'] ?? ''} - ${d['courseName'] ?? ''}',
                  ),
                  subtitle: Text(
                    '${d['day'] ?? '-'} | ${d['startTime'] ?? '-'} - ${d['endTime'] ?? '-'}\nRoom: ${d['room'] ?? '-'}\nLecturer: ${d['lecturer'] ?? '-'}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Navigate',
                    onPressed: room.isEmpty
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    LocationsScreen(initialQuery: room),
                              ),
                            );
                          },
                    icon: const Icon(Icons.near_me),
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
