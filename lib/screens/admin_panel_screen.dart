import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/firestore_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final service = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Main Admin Panel'),
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

  Future<void> _openPdf(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
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
          return status == 'event_admin_checked' ||
              status == 'approved_published' ||
              status == 'admin_rejected';
        }).toList();
        if (docs.isEmpty) {
          return const Center(child: Text('No proposals forwarded to admin.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final status = (data['status'] ?? '').toString();
            final canPublish = status == 'event_admin_checked';
            final pdfUrl = (data['proposalPdfUrl'] ?? '').toString();
            return Card(
              child: ExpansionTile(
                leading: const Icon(Icons.verified, color: Colors.green),
                title: Text(data['title'] ?? 'Untitled proposal'),
                subtitle: Text(
                  '${data['clubName'] ?? '-'} - ${status.replaceAll('_', ' ')}',
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
                        Text(
                          'Time: ${data['startTime'] ?? '-'}-${data['endTime'] ?? '-'}',
                        ),
                        Text('Venue: ${data['venue'] ?? '-'}'),
                        Text(
                          'Event Admin remark: ${data['eventAdminRemark'] ?? '-'}',
                        ),
                        if (pdfUrl.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => _openPdf(pdfUrl),
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('Open proposal PDF'),
                          ),
                        if (canPublish)
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () => _reject(context, doc.id),
                                child: const Text('Reject'),
                              ),
                              FilledButton.icon(
                                onPressed: () => _publish(context, doc),
                                icon: const Icon(Icons.publish),
                                label: const Text('Publish Event'),
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
