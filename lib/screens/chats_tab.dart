import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/chat_service.dart';
import '../services/firestore_service.dart';
import '../utils/course_utils.dart';
import 'browse_groups_screen.dart';
import 'chat_screen.dart';
import 'coursemate_directory_screen.dart';

class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  final _chat = ChatService();
  final _service = FirestoreService();
  final _ensured = <String>{};
  String _myName = 'Student';

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _chat.currentUserProfile().then((p) {
      if (mounted) setState(() => _myName = p.name);
    });
  }

  void _ensureCourseChannels(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> ttDocs,
  ) {
    // Collect one course name per base code (timetable often has 3 rows per
    // course; any of them carries the same courseName).
    final names = <String, String>{};
    for (final d in ttDocs) {
      final code = CourseUtils.baseCode((d.data()['courseCode'] ?? '').toString());
      if (code.isEmpty) continue;
      names.putIfAbsent(code, () => (d.data()['courseName'] ?? '').toString());
    }
    for (final entry in names.entries) {
      if (_ensured.add(entry.key)) {
        _chat.ensureCourseChannel(entry.key, _myName, courseName: entry.value);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            tooltip: 'Browse groups',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BrowseGroupsScreen()),
            ),
            icon: const Icon(Icons.group_add),
          ),
        ],
      ),
      // Bottom-left so it never overlaps the bottom-right Canva bubble.
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'chats-new-dm',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CoursemateDirectoryScreen(),
          ),
        ),
        icon: const Icon(Icons.edit),
        label: const Text('New DM'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _service.streamUserTimetable(_uid),
        builder: (context, ttSnap) {
          if (ttSnap.hasData) _ensureCourseChannels(ttSnap.data!.docs);

          return StreamBuilder<
              List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            stream: _chat.streamMyChannels(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!;
              if (docs.isEmpty) {
                return _empty();
              }

              // Group channels by course; collect DMs separately.
              final byCourse = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
              final dms = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              for (final doc in docs) {
                final type = (doc.data()['type'] ?? '').toString();
                if (type == 'dm') {
                  dms.add(doc);
                } else {
                  final code = (doc.data()['courseCode'] ?? 'Other').toString();
                  byCourse.putIfAbsent(code, () => []).add(doc);
                }
              }
              final courseCodes = byCourse.keys.toList()..sort();

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  for (final code in courseCodes) ...[
                    _sectionHeader(code),
                    _channelGroup(byCourse[code]!),
                    const SizedBox(height: 12),
                  ],
                  if (dms.isNotEmpty) ...[
                    _sectionHeader('Direct messages'),
                    _channelGroup(dms),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: Color(0xff94a3b8),
        ),
      ),
    );
  }

  Widget _channelGroup(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    docs.sort((a, b) {
      final at = a.data()['lastAt'];
      final bt = b.data()['lastAt'];
      final av = at is Timestamp ? at.millisecondsSinceEpoch : 0;
      final bv = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
      return bv.compareTo(av);
    });
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Column(
        children: [
          for (var i = 0; i < docs.length; i++) ...[
            _channelRow(docs[i]),
            if (i != docs.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Widget _channelRow(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final type = (d['type'] ?? '').toString();
    final isDm = type == 'dm';
    final isCourse = type == 'course';

    String title;
    if (isDm) {
      final names = (d['names'] as Map?) ?? {};
      // Show the other participant's name (avoid generic firstWhere typing
      // issues on the dynamic Firestore map).
      title = 'Direct message';
      names.forEach((k, v) {
        if (k.toString() != _uid) title = v.toString();
      });
    } else if (isCourse) {
      final code = (d['courseCode'] ?? '').toString();
      final courseName = (d['courseName'] ?? '').toString();
      title = courseName.isEmpty
          ? '$code · General'
          : '$code $courseName · General';
    } else {
      title = (d['name'] ?? 'Group').toString();
    }

    final last = (d['lastMessage'] ?? '').toString();
    final lastSender = (d['lastSender'] ?? '').toString();
    final preview = last.isEmpty
        ? 'No messages yet'
        : (lastSender.isEmpty ? last : '$lastSender: $last');
    final ts = d['lastAt'];
    final time = ts is Timestamp ? _shortTime(ts.toDate()) : '';

    // Unread / mention state from per-user markers on the channel doc.
    final readMarkers = (d['readMarkers'] as Map?) ?? {};
    final mentionMarkers = (d['mentionMarkers'] as Map?) ?? {};
    final myRead = readMarkers[_uid];
    final lastAtMs = ts is Timestamp ? ts.millisecondsSinceEpoch : 0;
    final myReadMs = myRead is Timestamp ? myRead.millisecondsSinceEpoch : 0;
    final unread = lastAtMs > myReadMs + 500; // small skew guard
    final mentioned = mentionMarkers[_uid] != null;

    final (icon, color) = isDm
        ? (Icons.person, const Color(0xff0891b2))
        : isCourse
            ? (Icons.tag, const Color(0xff2563eb))
            : (Icons.groups, const Color(0xff7c3aed));

    final subtitle = isCourse
        ? ''
        : isDm
            ? ''
            : '${((d['memberIds'] as List?)?.length ?? 0)} members';

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: unread ? const Color(0xff0f172a) : const Color(0xff64748b),
          fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (time.isNotEmpty)
            Text(
              time,
              style: TextStyle(
                fontSize: 11,
                color: unread
                    ? const Color(0xff2563eb)
                    : const Color(0xff94a3b8),
              ),
            ),
          const SizedBox(height: 4),
          if (mentioned)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xffdc2626),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '@',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else if (unread)
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xff2563eb),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            channelId: doc.id,
            title: title,
            subtitle: subtitle,
          ),
        ),
      ),
    );
  }

  String _shortTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return DateFormat('HH:mm').format(dt);
    }
    if (now.difference(dt).inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('d MMM').format(dt);
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.forum_outlined, size: 48, color: Color(0xff94a3b8)),
            const SizedBox(height: 12),
            const Text(
              'No chats yet.',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'Upload your timetable to get course channels, or browse and join a group.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xff64748b)),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BrowseGroupsScreen()),
              ),
              icon: const Icon(Icons.group_add),
              label: const Text('Browse groups'),
            ),
          ],
        ),
      ),
    );
  }
}
