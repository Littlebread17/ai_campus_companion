import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/firestore_service.dart';

class EventAdminPanelScreen extends StatelessWidget {
  const EventAdminPanelScreen({super.key});

  Future<void> _review(
    BuildContext context,
    FirestoreService service,
    String proposalId,
    String status,
  ) async {
    final remark = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(status.replaceAll('_', ' ')),
        content: TextField(
          controller: remark,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Remark / reason',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await service.eventAdminReviewProposal(
                proposalId: proposalId,
                status: status,
                remark: remark.text.trim(),
                reviewedBy: FirebaseAuth.instance.currentUser?.uid ?? '',
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    remark.dispose();
  }

  Future<void> _openPdf(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    return Scaffold(
      appBar: AppBar(title: const Text('Event Admin Panel')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.streamEventProposals(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs.where((doc) {
            final status = (doc.data()['status'] ?? '').toString();
            return status == 'submitted';
          }).toList();
          if (docs.isEmpty) {
            return const Center(
              child: Text('No proposals waiting for review.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final url = (data['proposalPdfUrl'] ?? '').toString();
              return Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.fact_check, color: Colors.purple),
                  title: Text(data['title'] ?? 'Untitled proposal'),
                  subtitle: Text(
                    '${data['clubName'] ?? '-'} - ${data['status'] ?? 'submitted'}',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['description'] ?? ''),
                          const SizedBox(height: 8),
                          Text('Date: ${data['eventDate'] ?? '-'}'),
                          Text('Venue: ${data['venue'] ?? '-'}'),
                          Text('Contact: ${data['contactPerson'] ?? '-'}'),
                          if (url.isNotEmpty)
                            TextButton.icon(
                              onPressed: () => _openPdf(url),
                              icon: const Icon(Icons.picture_as_pdf),
                              label: const Text('Open proposal PDF'),
                            ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () => _review(
                                  context,
                                  service,
                                  doc.id,
                                  'needs_changes',
                                ),
                                child: const Text('Request redo'),
                              ),
                              OutlinedButton(
                                onPressed: () => _review(
                                  context,
                                  service,
                                  doc.id,
                                  'event_admin_rejected',
                                ),
                                child: const Text('Reject'),
                              ),
                              FilledButton(
                                onPressed: () => _review(
                                  context,
                                  service,
                                  doc.id,
                                  'event_admin_checked',
                                ),
                                child: const Text('Forward to Admin'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
