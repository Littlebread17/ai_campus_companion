import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.streamNotifications(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs.where((doc) {
            final targetUserId = (doc.data()['targetUserId'] ?? '').toString();
            return targetUserId.isEmpty || targetUserId == userId;
          }).toList();
          if (docs.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final readBy = List<String>.from(data['readBy'] ?? []);
              final isRead = readBy.contains(userId);
              return Card(
                child: ListTile(
                  leading: Icon(
                    isRead ? Icons.notifications_none : Icons.notifications,
                    color: isRead ? Colors.grey : Colors.blue,
                  ),
                  title: Text(data['title'] ?? 'Campus notification'),
                  subtitle: Text(data['body'] ?? ''),
                  trailing: isRead ? null : const Chip(label: Text('New')),
                  onTap: () => service.markNotificationRead(
                    notificationId: doc.id,
                    userId: userId,
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
