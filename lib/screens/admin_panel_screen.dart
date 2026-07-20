import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/demo_seeder_service.dart';
import '../services/firestore_service.dart';
import '../widgets/event_poster.dart';
import 'proposal_pdf_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final service = FirestoreService();
  final seeder = DemoSeederService();
  bool _seeding = false;

  Future<void> _seedDemo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Seed demo data?'),
        content: const Text(
          'This will populate your account and the app with realistic demo '
          'content — timetable, courses, announcements, events, resources, '
          'notifications, calendar events and past-semester grades. '
          'Running again just updates the same records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Seed now'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _seeding = true);
    try {
      String name = user.email ?? 'Student';
      try {
        final profile = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        name = (profile.data()?['name'] ?? name).toString();
      } catch (_) {}

      final result = await seeder.seedAll(
        userId: user.uid,
        userName: name,
        userEmail: user.email ?? '',
      );

      if (!mounted) return;
      final summary = result.counts.entries
          .map((e) => '${e.key}: ${e.value}')
          .join('\n');
      final accounts = DemoSeederService.demoAccounts
          .map(
            (a) =>
                '${(a['role'] == 'admin' ? '[ADMIN] ' : '[STUDENT] ')}${a['email']}',
          )
          .join('\n');
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Demo data seeded'),
          content: SingleChildScrollView(
            child: Text(
              '${result.elapsedMs} ms\n\n$summary\n\n'
              'Pre-approved emails (create these in Firebase Auth to sign in):\n$accounts',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Seeding failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Main Admin Panel'),
          actions: [
            IconButton(
              tooltip: 'Seed demo data',
              onPressed: _seeding ? null : _seedDemo,
              icon: _seeding
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_fix_high),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Approvals'),
              Tab(text: 'Announcements'),
              Tab(text: 'Resources'),
              Tab(text: 'Locations'),
              Tab(text: 'Users'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ApprovalsTab(service: service),
            _AnnouncementsAdminTab(service: service),
            _ResourcesAdminTab(service: service),
            _LocationsAdminTab(service: service),
            _UsersAdminTab(service: service),
          ],
        ),
      ),
    );
  }
}

class _ApprovalsTab extends StatelessWidget {
  final FirestoreService service;

  const _ApprovalsTab({required this.service});

  Future<void> _requestChanges(BuildContext context, String proposalId) async {
    final remark = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Request Changes'),
        content: TextField(
          controller: remark,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Tell the student what to change',
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
              if (remark.text.trim().isEmpty) return;
              await service.adminRequestProposalChanges(
                proposalId: proposalId,
                remark: remark.text.trim(),
                reviewedBy: FirebaseAuth.instance.currentUser?.uid ?? '',
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Send to Student'),
          ),
        ],
      ),
    );
    remark.dispose();
  }

  Future<void> _publish(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    try {
      await service.publishApprovedProposal(
        proposalId: doc.id,
        proposal: doc.data(),
        approvedBy: FirebaseAuth.instance.currentUser?.uid ?? '',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event published to students.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to publish event: $e')));
      }
    }
  }

  Future<void> _reject(BuildContext context, String proposalId) async {
    final remark = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Proposal'),
        content: TextField(
          controller: remark,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Main admin reason',
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
              await service.adminRejectProposal(
                proposalId: proposalId,
                remark: remark.text.trim(),
                reviewedBy: FirebaseAuth.instance.currentUser?.uid ?? '',
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    remark.dispose();
  }

  void _openPdf(BuildContext context, String url, String fileName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProposalPdfScreen(url: url, fileName: fileName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.streamEventProposals(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs.where((doc) {
          final status = (doc.data()['status'] ?? '').toString();
          return status == 'submitted' ||
              status == 'needs_changes' ||
              status == 'event_admin_checked' ||
              status == 'approved_published' ||
              status == 'admin_rejected';
        }).toList();
        if (docs.isEmpty) {
          return const Center(child: Text('No event proposals found.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final status = (data['status'] ?? '').toString();
            final statusLabel = switch (status) {
              'submitted' => 'pending review',
              'needs_changes' => 'pending edit',
              'approved_published' => 'approved and published',
              'admin_rejected' => 'rejected',
              _ => status.replaceAll('_', ' '),
            };
            final isPendingReview =
                status == 'submitted' || status == 'event_admin_checked';
            final pdfUrl = (data['proposalPdfUrl'] ?? '').toString();
            final pdfFileName = (data['proposalFileName'] ?? 'Proposal.pdf')
                .toString();
            final canApprove = canApproveEventProposal(status, pdfUrl);
            final posterUrl = (data['posterUrl'] ?? '').toString();
            return Card(
              child: ExpansionTile(
                leading: const Icon(Icons.verified, color: Colors.green),
                title: Text(data['title'] ?? 'Untitled proposal'),
                subtitle: Text('${data['clubName'] ?? '-'} - $statusLabel'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (posterUrl.isNotEmpty) ...[
                          EventPoster(
                            title: (data['title'] ?? 'Event').toString(),
                            posterUrl: posterUrl,
                            height: 260,
                            borderRadius: 6,
                            showOverlayText: false,
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(data['description'] ?? ''),
                        const SizedBox(height: 8),
                        Text('Student: ${data['studentName'] ?? '-'}'),
                        Text(
                          'Date: ${data['eventDate'] ?? '-'}${(data['eventEndDate'] ?? '').toString().isEmpty ? '' : ' - ${data['eventEndDate']}'}',
                        ),
                        Text(
                          'Time: ${data['startTime'] ?? '-'}-${data['endTime'] ?? '-'}',
                        ),
                        Text('Venue: ${data['venue'] ?? '-'}'),
                        Text('Contact: ${data['contactPerson'] ?? '-'}'),
                        Text(
                          'Event Admin remark: ${data['eventAdminRemark'] ?? '-'}',
                        ),
                        Text(
                          'Main Admin remark: ${data['mainAdminRemark'] ?? '-'}',
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: pdfUrl.isEmpty
                                ? const Color(0xfffff7ed)
                                : const Color(0xfff8fafc),
                            border: Border.all(
                              color: pdfUrl.isEmpty
                                  ? const Color(0xfffb923c)
                                  : const Color(0xffcbd5e1),
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                pdfUrl.isEmpty
                                    ? Icons.warning_amber
                                    : Icons.picture_as_pdf,
                                color: pdfUrl.isEmpty
                                    ? const Color(0xffc2410c)
                                    : const Color(0xffdc2626),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Proposal Document',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      pdfUrl.isEmpty
                                          ? 'No proposal PDF uploaded'
                                          : pdfFileName,
                                    ),
                                  ],
                                ),
                              ),
                              if (pdfUrl.isNotEmpty)
                                FilledButton.icon(
                                  onPressed: () =>
                                      _openPdf(context, pdfUrl, pdfFileName),
                                  icon: const Icon(Icons.visibility),
                                  label: const Text('View PDF'),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (isPendingReview)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () =>
                                    _requestChanges(context, doc.id),
                                child: const Text('Request Changes'),
                              ),
                              OutlinedButton(
                                onPressed: () => _reject(context, doc.id),
                                child: const Text('Reject'),
                              ),
                              FilledButton.icon(
                                onPressed: canApprove
                                    ? () => _publish(context, doc)
                                    : null,
                                icon: const Icon(Icons.publish),
                                label: const Text('Approve and Publish'),
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
    );
  }
}

bool canApproveEventProposal(String status, String pdfUrl) {
  return (status == 'submitted' || status == 'event_admin_checked') &&
      pdfUrl.trim().isNotEmpty;
}

class _AnnouncementsAdminTab extends StatelessWidget {
  final FirestoreService service;

  const _AnnouncementsAdminTab({required this.service});

  Future<void> _editAnnouncement(
    BuildContext context, {
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final data = doc?.data() ?? {};
    final title = TextEditingController(text: data['title'] ?? '');
    final desc = TextEditingController(text: data['description'] ?? '');
    final category = TextEditingController(text: data['category'] ?? 'General');
    final priority = TextEditingController(text: data['priority'] ?? 'normal');
    final target = TextEditingController(
      text: data['targetProgramme'] ?? 'All',
    );
    final courseCode = TextEditingController(text: data['courseCode'] ?? '');

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(doc == null ? 'Add Announcement' : 'Edit Announcement'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              _input(title, 'Title'),
              _input(desc, 'Description'),
              _input(category, 'Category'),
              _input(priority, 'Priority'),
              _input(target, 'Target programme'),
              _input(courseCode, 'Course code (optional, e.g. PRG4201)'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (doc == null) {
                await service.addAnnouncement(
                  title: title.text.trim(),
                  description: desc.text.trim(),
                  category: category.text.trim(),
                  priority: priority.text.trim(),
                  targetProgramme: target.text.trim(),
                  courseCode: courseCode.text.trim(),
                  createdBy: FirebaseAuth.instance.currentUser?.uid ?? '',
                );
              } else {
                await service.updateAnnouncement(
                  id: doc.id,
                  title: title.text.trim(),
                  description: desc.text.trim(),
                  category: category.text.trim(),
                  priority: priority.text.trim(),
                  targetProgramme: target.text.trim(),
                  courseCode: courseCode.text.trim(),
                );
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    for (final c in [title, desc, category, priority, target, courseCode]) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editAnnouncement(context),
        icon: const Icon(Icons.add),
        label: const Text('Announcement'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.streamCollection(
          'announcements',
          orderBy: 'createdAt',
          descending: true,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('${snapshot.error}'));
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No announcements.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.campaign, color: Colors.blue),
                  title: Text(data['title'] ?? 'Announcement'),
                  subtitle: Text(
                    '${data['category'] ?? '-'} - ${data['priority'] ?? '-'}',
                  ),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        onPressed: () => _editAnnouncement(context, doc: doc),
                        icon: const Icon(Icons.edit),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: () => service.deleteAnnouncement(doc.id),
                        icon: const Icon(Icons.delete),
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

class _ResourcesAdminTab extends StatelessWidget {
  final FirestoreService service;

  const _ResourcesAdminTab({required this.service});

  Future<void> _editResource(
    BuildContext context, {
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final data = doc?.data() ?? {};
    final title = TextEditingController(text: data['title'] ?? '');
    final desc = TextEditingController(text: data['description'] ?? '');
    final category = TextEditingController(text: data['category'] ?? 'General');
    final course = TextEditingController(text: data['courseCode'] ?? '');
    final link = TextEditingController(text: data['linkUrl'] ?? '');
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(doc == null ? 'Add Resource' : 'Edit Resource'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              _input(title, 'Title'),
              _input(desc, 'Description'),
              _input(category, 'Category'),
              _input(course, 'Course code'),
              _input(link, 'Link URL'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (doc == null) {
                await service.addResource(
                  title: title.text.trim(),
                  description: desc.text.trim(),
                  category: category.text.trim(),
                  courseCode: course.text.trim().toUpperCase(),
                  linkUrl: link.text.trim(),
                  uploadedBy: FirebaseAuth.instance.currentUser?.uid ?? '',
                );
              } else {
                await service.updateResource(
                  id: doc.id,
                  title: title.text.trim(),
                  description: desc.text.trim(),
                  category: category.text.trim(),
                  courseCode: course.text.trim().toUpperCase(),
                  linkUrl: link.text.trim(),
                );
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    for (final c in [title, desc, category, course, link]) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editResource(context),
        icon: const Icon(Icons.add),
        label: const Text('Resource'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.streamCollection(
          'resources',
          orderBy: 'createdAt',
          descending: true,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('${snapshot.error}'));
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No resources.'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.folder, color: Colors.orange),
                  title: Text(data['title'] ?? 'Untitled'),
                  subtitle: Text(
                    '${data['category'] ?? '-'} ${data['courseCode'] ?? ''}',
                  ),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        onPressed: () => _editResource(context, doc: doc),
                        icon: const Icon(Icons.edit),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: () => service.deleteResource(doc.id),
                        icon: const Icon(Icons.delete),
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

class _LocationsAdminTab extends StatelessWidget {
  final FirestoreService service;

  const _LocationsAdminTab({required this.service});

  Future<void> _editLocation(
    BuildContext context, {
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final data = doc?.data() ?? {};
    final name = TextEditingController(text: data['name'] ?? '');
    final building = TextEditingController(text: data['building'] ?? '');
    final level = TextEditingController(text: data['level'] ?? '');
    final room = TextEditingController(text: data['room'] ?? '');
    final category = TextEditingController(
      text: data['category'] ?? 'Facility',
    );
    final direction = TextEditingController(text: data['directionText'] ?? '');
    final nearest = TextEditingController(
      text: data['nearestTrainedPlace'] ?? '',
    );
    final keywords = TextEditingController(
      text: (data['keywords'] is List)
          ? List<String>.from(data['keywords']).join(', ')
          : '',
    );
    final latitude = TextEditingController(
      text: data['latitude'] != null ? '${data['latitude']}' : '',
    );
    final longitude = TextEditingController(
      text: data['longitude'] != null ? '${data['longitude']}' : '',
    );

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(doc == null ? 'Add Location' : 'Edit Location'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              _input(name, 'Name'),
              _input(building, 'Building / block'),
              _input(level, 'Level'),
              _input(room, 'Room'),
              _input(category, 'Category'),
              _input(direction, 'Direction steps'),
              _input(nearest, 'Nearest trained place (optional, e.g. A2-05)'),
              _input(keywords, 'Keywords, comma separated'),
              _input(latitude, 'Latitude (optional, e.g. 2.81380)'),
              _input(longitude, 'Longitude (optional, e.g. 101.78160)'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final lat = double.tryParse(latitude.text.trim());
              final lng = double.tryParse(longitude.text.trim());
              if (doc == null) {
                await service.addLocation(
                  name: name.text.trim(),
                  building: building.text.trim(),
                  level: level.text.trim(),
                  room: room.text.trim(),
                  category: category.text.trim(),
                  directionText: direction.text.trim(),
                  keywords: keywords.text.trim(),
                  nearestTrainedPlace: nearest.text.trim(),
                  latitude: lat,
                  longitude: lng,
                );
              } else {
                await service.updateLocation(
                  id: doc.id,
                  name: name.text.trim(),
                  building: building.text.trim(),
                  level: level.text.trim(),
                  room: room.text.trim(),
                  category: category.text.trim(),
                  directionText: direction.text.trim(),
                  keywords: keywords.text.trim(),
                  nearestTrainedPlace: nearest.text.trim(),
                  latitude: lat,
                  longitude: lng,
                );
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    for (final c in [
      name,
      building,
      level,
      room,
      category,
      direction,
      nearest,
      keywords,
      latitude,
      longitude,
    ]) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editLocation(context),
        icon: const Icon(Icons.add_location),
        label: const Text('Location'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.streamCollection('locations'),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('${snapshot.error}'));
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No locations.'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.map, color: Colors.purple),
                  title: Text(data['name'] ?? 'Location'),
                  subtitle: Text(
                    '${data['building'] ?? '-'} - ${data['level'] ?? '-'} - ${data['room'] ?? '-'}',
                  ),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        onPressed: () => _editLocation(context, doc: doc),
                        icon: const Icon(Icons.edit),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: () => service.deleteLocation(doc.id),
                        icon: const Icon(Icons.delete),
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

class _UsersAdminTab extends StatelessWidget {
  final FirestoreService service;

  const _UsersAdminTab({required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.streamUsers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No users found.'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final role = (data['role'] ?? 'student').toString();
            return Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(data['name'] ?? data['email'] ?? 'User'),
                subtitle: Text(
                  '${data['email'] ?? '-'}\n${data['studentId'] ?? ''}',
                ),
                isThreeLine: true,
                trailing: DropdownButton<String>(
                  value: ['student', 'event_admin', 'admin'].contains(role)
                      ? role
                      : 'student',
                  items: const [
                    DropdownMenuItem(value: 'student', child: Text('Student')),
                    DropdownMenuItem(
                      value: 'event_admin',
                      child: Text('Event Admin'),
                    ),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (value) {
                    if (value != null) service.updateUserRole(doc.id, value);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

Widget _input(TextEditingController controller, String label) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}
