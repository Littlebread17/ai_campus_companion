import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/firestore_service.dart';

/// Admin/supervisor view of all student feedback submissions.
class FeedbackAdminScreen extends StatelessWidget {
  const FeedbackAdminScreen({super.key});

  static const _categoryColors = {
    'Suggestion': Color(0xff2563eb),
    'Bug': Color(0xffdc2626),
    'Praise': Color(0xff16a34a),
    'Other': Color(0xff64748b),
  };

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    return Scaffold(
      appBar: AppBar(title: const Text('Student Feedback')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.streamFeedback(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No feedback submitted yet.'),
              ),
            );
          }

          final avg = docs
                  .map((d) => (d.data()['rating'] as num?)?.toDouble() ?? 0)
                  .fold<double>(0, (a, b) => a + b) /
              docs.length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _summary(docs.length, avg),
              const SizedBox(height: 12),
              ...docs.map((doc) => _card(doc.data())),
            ],
          );
        },
      ),
    );
  }

  Widget _summary(int count, double avg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff2563eb), Color(0xff7c3aed)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Average rating',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                avg.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'submissions',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> d) {
    final rating = (d['rating'] as num?)?.toInt() ?? 0;
    final category = (d['category'] ?? 'Other').toString();
    final color = _categoryColors[category] ?? const Color(0xff64748b);
    final ts = d['createdAt'];
    final when = ts is Timestamp
        ? DateFormat('d MMM yyyy, h:mm a').format(ts.toDate())
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 16,
                      color: const Color(0xfff59e0b),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text((d['message'] ?? '').toString()),
            const SizedBox(height: 8),
            Text(
              '${d['name'] ?? 'Student'} · ${d['email'] ?? ''}',
              style: const TextStyle(fontSize: 12, color: Color(0xff64748b)),
            ),
            if (when.isNotEmpty)
              Text(
                when,
                style: const TextStyle(fontSize: 11, color: Color(0xff94a3b8)),
              ),
          ],
        ),
      ),
    );
  }
}
