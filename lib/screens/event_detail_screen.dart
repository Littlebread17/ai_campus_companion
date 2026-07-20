import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import '../services/firestore_service.dart';
import '../utils/event_category.dart';
import '../widgets/event_poster.dart';
import 'chat_screen.dart';
import 'locations_screen.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen>
    with SingleTickerProviderStateMixin {
  final _service = FirestoreService();
  final _chat = ChatService();
  late final TabController _tabs;
  bool _busy = false;
  String _myName = 'Student';

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _chat.currentUserProfile().then((p) {
      if (mounted) setState(() => _myName = p.name);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _toggleRsvp(Map<String, dynamic> data, bool going) async {
    setState(() => _busy = true);
    try {
      if (going) {
        await _service.leaveEvent(eventId: widget.eventId, userId: _uid);
      } else {
        await _service.joinEvent(
          eventId: widget.eventId,
          userId: _uid,
          event: data,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("You're going — added to your calendar."),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openChat(Map<String, dynamic> data) async {
    final id = await _chat.ensureEventChannel(
      eventId: widget.eventId,
      eventTitle: (data['title'] ?? 'Event').toString(),
      userName: _myName,
    );
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          channelId: id,
          title: '${data['title'] ?? 'Event'} · Chat',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _service.streamEvent(widget.eventId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!.data() ?? {};
          if (data.isEmpty) {
            return const Center(child: Text('This event no longer exists.'));
          }
          final attendees = (data['attendees'] as List?) ?? [];
          final going = attendees.contains(_uid);

          return Column(
            children: [
              Expanded(
                child: NestedScrollView(
                  headerSliverBuilder: (context, innerScrolled) => [
                    SliverAppBar(
                      pinned: true,
                      expandedHeight: 220,
                      flexibleSpace: FlexibleSpaceBar(
                        background: EventPoster(
                          title: (data['title'] ?? 'Event').toString(),
                          host: (data['clubName'] ?? '').toString(),
                          posterUrl: (data['posterUrl'] ?? '').toString(),
                          height: 220,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _titleRow(data),
                            const SizedBox(height: 12),
                            _tagChips(data),
                            const SizedBox(height: 12),
                            _metaStrip(data),
                          ],
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _TabBarDelegate(
                        TabBar(
                          controller: _tabs,
                          labelColor: const Color(0xff2563eb),
                          unselectedLabelColor: const Color(0xff334155),
                          indicatorColor: const Color(0xff2563eb),
                          tabs: const [
                            Tab(text: 'Overview'),
                            Tab(text: 'Chat'),
                          ],
                        ),
                      ),
                    ),
                  ],
                  body: TabBarView(
                    controller: _tabs,
                    children: [_overview(data), _chatTab(data)],
                  ),
                ),
              ),
              _bottomBar(data, going),
            ],
          );
        },
      ),
    );
  }

  Widget _titleRow(Map<String, dynamic> data) {
    final hostType = (data['hostType'] ?? 'club').toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          (data['title'] ?? 'Event').toString(),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              hostType == 'school' ? Icons.account_balance : Icons.groups,
              size: 16,
              color: const Color(0xff64748b),
            ),
            const SizedBox(width: 6),
            Text(
              hostType == 'school'
                  ? 'Hosted by INTI'
                  : 'Hosted by ${data['clubName'] ?? 'a campus club'}',
              style: const TextStyle(color: Color(0xff64748b)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metaStrip(Map<String, dynamic> data) {
    final venue = (data['venue'] ?? '').toString();
    return Column(
      children: [
        _metaRow(Icons.calendar_today, (data['eventDate'] ?? '-').toString()),
        _metaRow(
          Icons.schedule,
          '${data['startTime'] ?? '-'} - ${data['endTime'] ?? '-'}',
        ),
        if (venue.isNotEmpty)
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LocationsScreen(initialQuery: venue),
              ),
            ),
            child: _metaRow(Icons.place, venue, action: 'Open map'),
          ),
      ],
    );
  }

  Widget _metaRow(IconData icon, String text, {String? action}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xff2563eb)),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
          if (action != null)
            Text(
              action,
              style: const TextStyle(
                color: Color(0xff2563eb),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _tagChips(Map<String, dynamic> data) {
    final category = EventCategory.resolve(data);
    final host = (data['hostType'] ?? 'club').toString() == 'school'
        ? 'INTI'
        : (data['clubName'] ?? 'Campus').toString();
    final capacity = (data['capacity'] as num?)?.toInt() ?? 0;
    final tags = <String>[
      category,
      host,
      if (capacity <= 0) 'Open entry',
      'Free',
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags
          .where((t) => t.trim().isNotEmpty)
          .map(
            (t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xffeef2ff),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xffdbe2fb)),
              ),
              child: Text(
                t,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff4338ca),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _overview(Map<String, dynamic> data) {
    final description = (data['description'] ?? '').toString().trim();
    final hostType = (data['hostType'] ?? 'club').toString();
    final host = hostType == 'school'
        ? 'INTI International University'
        : (data['clubName'] ?? 'Campus club').toString();
    final contact = (data['contactPerson'] ?? '').toString();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const Text(
          'About this event',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Text(
          description.isEmpty
              ? 'The organiser has not added a full description for this event '
                    'yet. Check the details below, and tap Join Event to add it to '
                    'your calendar and open the event chat.'
              : description,
          style: const TextStyle(height: 1.5),
        ),
        const SizedBox(height: 20),
        const Text(
          'Event details',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 8),
        _detailRow(Icons.category, 'Category', EventCategory.resolve(data)),
        _detailRow(Icons.groups, 'Organiser', host),
        _detailRow(
          Icons.calendar_today,
          'Date',
          (data['eventDate'] ?? '-').toString(),
        ),
        _detailRow(
          Icons.schedule,
          'Time',
          '${data['startTime'] ?? '-'} - ${data['endTime'] ?? '-'}',
        ),
        _detailRow(
          Icons.place,
          'Venue',
          (data['venue'] ?? 'To be announced').toString(),
        ),
        if (contact.isNotEmpty) _detailRow(Icons.person, 'Contact', contact),
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xff64748b)),
          const SizedBox(width: 12),
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xff64748b),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _chatTab(Map<String, dynamic> data) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.forum_outlined,
              size: 44,
              color: Color(0xff94a3b8),
            ),
            const SizedBox(height: 12),
            const Text(
              'Event group chat',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'Chat with everyone interested in this event.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xff64748b)),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openChat(data),
              icon: const Icon(Icons.chat),
              label: const Text('Open event chat'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar(Map<String, dynamic> data, bool going) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xffe2e8f0))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (data['eventDate'] ?? '').toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    going ? "You're going" : 'Open to join',
                    style: TextStyle(
                      fontSize: 12,
                      color: going
                          ? const Color(0xff16a34a)
                          : const Color(0xff64748b),
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: _busy ? null : () => _toggleRsvp(data, going),
              style: FilledButton.styleFrom(
                backgroundColor: going
                    ? const Color(0xff16a34a)
                    : const Color(0xff1e293b),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(going ? "Going ✓  (tap to leave)" : 'Join Event'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps the Overview/Chat TabBar pinned below the collapsing header.
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: const Color(0xfff6f8ff), child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) =>
      oldDelegate.tabBar != tabBar;
}
