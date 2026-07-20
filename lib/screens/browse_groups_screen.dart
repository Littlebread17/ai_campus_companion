import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import '../services/firestore_service.dart';
import '../utils/course_utils.dart';
import 'chat_screen.dart';

class BrowseGroupsScreen extends StatefulWidget {
  const BrowseGroupsScreen({super.key});

  @override
  State<BrowseGroupsScreen> createState() => _BrowseGroupsScreenState();
}

class _BrowseGroupsScreenState extends State<BrowseGroupsScreen> {
  final _chat = ChatService();
  final _service = FirestoreService();
  String? _course;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Browse groups')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _service.streamUserTimetable(_uid),
        builder: (context, ttSnap) {
          if (!ttSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final codes = <String>{};
          for (final d in ttSnap.data!.docs) {
            final c = CourseUtils.baseCode(
              (d.data()['courseCode'] ?? '').toString(),
            );
            if (c.isNotEmpty) codes.add(c);
          }
          final courseList = codes.toList()..sort();
          if (courseList.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Upload your timetable first to see course groups.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          _course ??= courseList.first;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<String>(
                  initialValue: _course,
                  decoration: const InputDecoration(
                    labelText: 'Course',
                    border: OutlineInputBorder(),
                  ),
                  items: courseList
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _course = v),
                ),
              ),
              Expanded(child: _groupList(_course!)),
            ],
          );
        },
      ),
      floatingActionButton: _course == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _createGroupDialog(_course!),
              icon: const Icon(Icons.add),
              label: const Text('Create group'),
            ),
    );
  }

  Widget _groupList(String course) {
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: _chat.streamGroupsForCourse(course),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!;
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No groups yet for this course.\nBe the first to create one.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: docs.map((doc) {
            final d = doc.data();
            final members = List<String>.from(d['memberIds'] ?? []);
            final joined = members.contains(_uid);
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xffede9fe),
                  child: const Icon(Icons.groups, color: Color(0xff7c3aed)),
                ),
                title: Text((d['name'] ?? 'Group').toString()),
                subtitle: Text('${members.length} members'),
                trailing: joined
                    ? OutlinedButton(
                        onPressed: () => _open(doc.id, d),
                        child: const Text('Open'),
                      )
                    : FilledButton(
                        onPressed: () async {
                          await _chat.joinGroup(doc.id);
                          if (!mounted) return;
                          _open(doc.id, d);
                        },
                        child: const Text('Join'),
                      ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _open(String id, Map<String, dynamic> d) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          channelId: id,
          title: (d['name'] ?? 'Group').toString(),
          subtitle: '${d['courseCode'] ?? ''} group',
        ),
      ),
    );
  }

  Future<void> _createGroupDialog(String course) async {
    final name = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('New group in $course'),
        content: TextField(
          controller: name,
          decoration: const InputDecoration(
            labelText: 'Group name',
            hintText: 'e.g. Group A · Project',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              final nav = Navigator.of(context);
              await _chat.createGroup(course, name.text.trim());
              nav.pop();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    name.dispose();
  }
}
