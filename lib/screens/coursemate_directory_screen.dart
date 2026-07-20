import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import 'chat_screen.dart';

/// Lists everyone who shares a course channel with the current user, so they
/// can start a direct message. Names come from the course channel's member
/// list (student user docs are not readable by other students).
class CoursemateDirectoryScreen extends StatefulWidget {
  const CoursemateDirectoryScreen({super.key});

  @override
  State<CoursemateDirectoryScreen> createState() =>
      _CoursemateDirectoryScreenState();
}

class _CoursemateDirectoryScreenState extends State<CoursemateDirectoryScreen> {
  final _chat = ChatService();
  final _search = TextEditingController();
  late Future<List<({String uid, String name})>> _future;
  String _myName = 'Student';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _chat.fetchCoursemates();
    _chat.currentUserProfile().then((p) {
      if (mounted) setState(() => _myName = p.name);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openDm(String uid, String name) async {
    final id = await _chat.openDm(
      otherUid: uid,
      otherName: name,
      myName: _myName,
    );
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(channelId: id, title: name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New message')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search coursemates…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xfff1f5f9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<({String uid, String name})>>(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snap.data!;
                final people = _query.isEmpty
                    ? all
                    : all
                        .where((p) => p.name.toLowerCase().contains(_query))
                        .toList();
                if (people.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No coursemates found yet.\nThey appear once they open Chats in a shared course.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xff64748b)),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: people.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = people[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xffdbeafe),
                        child: Text(
                          p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Color(0xff2563eb)),
                        ),
                      ),
                      title: Text(p.name),
                      trailing: const Icon(Icons.chat_bubble_outline, size: 18),
                      onTap: () => _openDm(p.uid, p.name),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
