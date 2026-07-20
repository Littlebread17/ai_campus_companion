import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/firestore_service.dart';

class EventProposalScreen extends StatefulWidget {
  const EventProposalScreen({super.key});

  @override
  State<EventProposalScreen> createState() => _EventProposalScreenState();
}

class _EventProposalScreenState extends State<EventProposalScreen> {
  final service = FirestoreService();
  final pageScroll = ScrollController();
  final title = TextEditingController();
  final club = TextEditingController();
  final date = TextEditingController();
  final start = TextEditingController();
  final end = TextEditingController();
  final venue = TextEditingController();
  final desc = TextEditingController();
  final contact = TextEditingController();

  PlatformFile? selectedPdf;
  XFile? selectedPoster;
  String? existingPosterUrl;
  String? editingProposalId;
  String? existingPdfUrl;
  String? existingPdfFileName;
  bool isSubmitting = false;

  bool get isEditing => editingProposalId != null;

  Future<void> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => selectedPdf = result.files.single);
  }

  Future<void> pickPoster() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) setState(() => selectedPoster = picked);
  }

  Future<void> submitProposal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if ([
      title,
      club,
      date,
      start,
      end,
      venue,
      desc,
      contact,
    ].any((c) => c.text.trim().isEmpty)) {
      showMessage('Please fill in all event details.');
      return;
    }
    if (!isEditing && (selectedPdf == null || selectedPdf!.path == null)) {
      showMessage('Please upload the proposal PDF.');
      return;
    }
    if (isEditing &&
        selectedPdf == null &&
        (existingPdfUrl == null || existingPdfUrl!.isEmpty)) {
      showMessage('Please upload the proposal PDF.');
      return;
    }

    setState(() => isSubmitting = true);
    try {
      var proposalPdfUrl = existingPdfUrl ?? '';
      var proposalFileName =
          existingPdfFileName ?? selectedPdf?.name ?? 'proposal.pdf';

      if (selectedPdf != null && selectedPdf!.path != null) {
        final safeName = selectedPdf!.name.replaceAll(
          RegExp(r'[^A-Za-z0-9_.-]'),
          '_',
        );
        final storagePath =
            'event_proposals/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_$safeName';
        final ref = FirebaseStorage.instance.ref(storagePath);
        await ref.putFile(
          File(selectedPdf!.path!),
          SettableMetadata(contentType: 'application/pdf'),
        );
        proposalPdfUrl = await ref.getDownloadURL();
        proposalFileName = selectedPdf!.name;
      }

      // Optional event poster upload.
      var posterUrl = existingPosterUrl ?? '';
      if (selectedPoster != null) {
        final bytes = await selectedPoster!.readAsBytes();
        final posterRef = FirebaseStorage.instance.ref(
          'event_posters/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await posterRef.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        posterUrl = await posterRef.getDownloadURL();
      }

      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final studentName = (profile.data()?['name'] ?? user.email ?? 'Student')
          .toString();

      if (isEditing) {
        await service.resubmitEventProposal(
          proposalId: editingProposalId!,
          submittedBy: user.uid,
          title: title.text.trim(),
          clubName: club.text.trim(),
          eventDate: date.text.trim(),
          startTime: start.text.trim(),
          endTime: end.text.trim(),
          venue: venue.text.trim(),
          description: desc.text.trim(),
          contactPerson: contact.text.trim(),
          proposalPdfUrl: proposalPdfUrl,
          proposalFileName: proposalFileName,
          posterUrl: posterUrl,
        );
      } else {
        await service.submitEventProposal(
          submittedBy: user.uid,
          studentName: studentName,
          title: title.text.trim(),
          clubName: club.text.trim(),
          eventDate: date.text.trim(),
          startTime: start.text.trim(),
          endTime: end.text.trim(),
          venue: venue.text.trim(),
          description: desc.text.trim(),
          contactPerson: contact.text.trim(),
          proposalPdfUrl: proposalPdfUrl,
          proposalFileName: proposalFileName,
          posterUrl: posterUrl,
        );
      }

      final message = isEditing
          ? 'Event proposal resubmitted.'
          : 'Event proposal submitted.';
      clearForm();
      showMessage(message);
    } catch (e) {
      showMessage('Unable to submit proposal: $e');
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  void clearForm() {
    for (final c in [title, club, date, start, end, venue, desc, contact]) {
      c.clear();
    }
    selectedPdf = null;
    selectedPoster = null;
    existingPosterUrl = null;
    editingProposalId = null;
    existingPdfUrl = null;
    existingPdfFileName = null;
  }

  void editProposal(String proposalId, Map<String, dynamic> data) {
    title.text = (data['title'] ?? '').toString();
    club.text = (data['clubName'] ?? '').toString();
    date.text = (data['eventDate'] ?? '').toString();
    start.text = (data['startTime'] ?? '').toString();
    end.text = (data['endTime'] ?? '').toString();
    venue.text = (data['venue'] ?? '').toString();
    desc.text = (data['description'] ?? '').toString();
    contact.text = (data['contactPerson'] ?? '').toString();
    setState(() {
      editingProposalId = proposalId;
      existingPdfUrl = (data['proposalPdfUrl'] ?? '').toString();
      existingPdfFileName = (data['proposalFileName'] ?? '').toString();
      existingPosterUrl = (data['posterUrl'] ?? '').toString();
      selectedPdf = null;
      selectedPoster = null;
    });
    if (pageScroll.hasClients) {
      pageScroll.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget input(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    pageScroll.dispose();
    for (final c in [title, club, date, start, end, venue, desc, contact]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Event Proposal')),
      body: ListView(
        controller: pageScroll,
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isEditing ? 'Redo Proposal' : 'Submit Proposal',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isEditing)
                TextButton(
                  onPressed: () => setState(clearForm),
                  child: const Text('Cancel redo'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          input(title, 'Event title', Icons.event),
          input(club, 'Club / society', Icons.groups),
          input(date, 'Date e.g. 2026-07-20', Icons.calendar_month),
          Row(
            children: [
              Expanded(child: input(start, 'Start e.g. 10:00', Icons.schedule)),
              const SizedBox(width: 10),
              Expanded(child: input(end, 'End e.g. 12:00', Icons.schedule)),
            ],
          ),
          input(venue, 'Venue', Icons.place),
          input(contact, 'Contact person', Icons.person),
          input(desc, 'Short description', Icons.description),
          OutlinedButton.icon(
            onPressed: isSubmitting ? null : pickPdf,
            icon: const Icon(Icons.picture_as_pdf),
            label: Text(
              selectedPdf?.name ?? existingPdfFileName ?? 'Upload proposal PDF',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: isSubmitting ? null : pickPoster,
            icon: const Icon(Icons.image),
            label: Text(
              selectedPoster != null
                  ? 'Poster selected ✓'
                  : (existingPosterUrl != null && existingPosterUrl!.isNotEmpty
                        ? 'Change event poster'
                        : 'Upload event poster (optional)'),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: isSubmitting ? null : submitProposal,
            icon: isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(
              isSubmitting
                  ? 'Submitting...'
                  : isEditing
                  ? 'Resubmit Proposal'
                  : 'Submit Proposal',
            ),
          ),
          const Divider(height: 36),
          const Text(
            'My Proposals',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: service.streamEventProposals(submittedBy: userId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Card(
                  child: ListTile(title: Text('No proposals submitted yet.')),
                );
              }
              return Column(
                children: docs.map((doc) {
                  final data = doc.data();
                  return Card(
                    child: ExpansionTile(
                      leading: const Icon(Icons.assignment),
                      title: Text(data['title'] ?? 'Untitled proposal'),
                      subtitle: Text(
                        _statusText(data['status'] ?? 'submitted'),
                      ),
                      children: [
                        ListTile(
                          title: Text(data['description'] ?? ''),
                          subtitle: Text(
                            'Date: ${data['eventDate'] ?? '-'}\nVenue: ${data['venue'] ?? '-'}\nEvent Admin: ${data['eventAdminRemark'] ?? '-'}\nMain Admin: ${data['mainAdminRemark'] ?? '-'}',
                          ),
                        ),
                        if ((data['status'] ?? '').toString() ==
                            'needs_changes')
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FilledButton.icon(
                                onPressed: () => editProposal(doc.id, data),
                                icon: const Icon(Icons.edit_note),
                                label: const Text('Edit and resubmit'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  String _statusText(Object status) {
    return proposalStatusText(status);
  }
}

String proposalStatusText(Object status) {
  return switch (status.toString()) {
    'submitted' => 'Pending review',
    'needs_changes' => 'Pending edit',
    'approved_published' => 'Approved and published',
    'admin_rejected' || 'event_admin_rejected' => 'Rejected',
    final value =>
      value
          .replaceAll('_', ' ')
          .replaceFirstMapped(RegExp(r'^\w'), (m) => m.group(0)!.toUpperCase()),
  };
}
