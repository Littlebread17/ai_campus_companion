import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/course_utils.dart';
import '../widgets/dashboard_card.dart';
import 'admin_panel_screen.dart';
import 'ai_agent_screen.dart';
import 'announcements_screen.dart';
import 'calendar_screen.dart';
import 'courses_screen.dart';
import 'events_screen.dart';
import 'event_admin_panel_screen.dart';
import 'event_proposal_screen.dart';
import 'locations_screen.dart';
import 'notifications_screen.dart';
import 'reminders_screen.dart';
import 'resources_screen.dart';
import 'timetable_screen.dart';
import 'timetable_upload_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final service = FirestoreService();
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'Student';
    final userId = user?.uid ?? '';

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: service.streamUserProfile(userId),
      builder: (context, snapshot) {
        final profile = snapshot.data?.data() ?? {};
        final role = (profile['role'] ?? 'student').toString();
        final name = (profile['name'] ?? email).toString();
        final isAdmin = role == 'admin';
        final isEventAdmin = role == 'event_admin' || isAdmin;

        return Scaffold(
          backgroundColor: const Color(0xfff4f7fb),
          floatingActionButton: FloatingActionButton(
            tooltip: 'Talk to Canva',
            onPressed: () => open(context, const AIAgentScreen()),
            backgroundColor: const Color(0xff0f172a),
            foregroundColor: Colors.white,
            child: const Icon(Icons.smart_toy),
          ),
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                    child: _Header(
                      name: name,
                      role: role,
                      onAdmin: isAdmin
                          ? () => open(context, const AdminPanelScreen())
                          : null,
                      onLogout: () async => authService.logoutUser(),
                    ),
                  ),
                ),

                // ---- Today's schedule ----
                _sectionTitle(
                  context,
                  'Today',
                  'Calendar',
                  () => open(context, const CalendarScreen()),
                ),
                SliverToBoxAdapter(
                  child: _TodaySchedule(service: service, userId: userId),
                ),

                // ---- My courses ----
                _sectionTitle(
                  context,
                  'My Courses',
                  'See all',
                  () => open(context, const CoursesScreen()),
                ),
                SliverToBoxAdapter(
                  child: _MyCoursesStrip(service: service, userId: userId),
                ),

                // ---- Due soon ----
                _sectionTitle(
                  context,
                  'Due Soon',
                  'Reminders',
                  () => open(context, const RemindersScreen()),
                ),
                SliverToBoxAdapter(
                  child: _DueSoon(service: service, userId: userId),
                ),

                // ---- Campus tools ----
                _sectionTitle(
                  context,
                  'Campus Tools',
                  'Notifications',
                  () => open(context, const NotificationsScreen()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.18,
                    ),
                    delegate: SliverChildListDelegate([
                      DashboardCard(
                        icon: Icons.upload_file,
                        title: 'Upload Timetable',
                        subtitle: 'Scan & edit',
                        color: const Color(0xff0891b2),
                        onTap: () =>
                            open(context, const TimetableUploadScreen()),
                      ),
                      DashboardCard(
                        icon: Icons.calendar_month,
                        title: 'Timetable',
                        subtitle: 'Class schedule',
                        color: const Color(0xff16a34a),
                        onTap: () => open(context, const TimetableScreen()),
                      ),
                      DashboardCard(
                        icon: Icons.folder,
                        title: 'Resources',
                        subtitle: 'IU Digital Hub',
                        color: const Color(0xfff59e0b),
                        onTap: () => open(context, const ResourcesScreen()),
                      ),
                      DashboardCard(
                        icon: Icons.campaign,
                        title: 'Announcements',
                        subtitle: 'Campus notices',
                        color: const Color(0xff2563eb),
                        onTap: () =>
                            open(context, const AnnouncementsScreen()),
                      ),
                      DashboardCard(
                        icon: Icons.event,
                        title: 'Events',
                        subtitle: 'Activities',
                        color: const Color(0xff0f766e),
                        onTap: () => open(context, const EventsScreen()),
                      ),
                      DashboardCard(
                        icon: Icons.map,
                        title: 'Navigation',
                        subtitle: 'Campus places',
                        color: const Color(0xff7c3aed),
                        onTap: () => open(context, const LocationsScreen()),
                      ),
                    ]),
                  ),
                ),

                // ---- Role workspace ----
                _sectionTitle(
                  context,
                  'Role Workspace',
                  isAdmin ? 'Admin' : 'Proposal',
                  () => open(
                    context,
                    isAdmin
                        ? const AdminPanelScreen()
                        : const EventProposalScreen(),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 96),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.18,
                    ),
                    delegate: SliverChildListDelegate([
                      DashboardCard(
                        icon: Icons.assignment_add,
                        title: 'Event Proposal',
                        subtitle: 'Submit and track',
                        color: const Color(0xff0891b2),
                        onTap: () =>
                            open(context, const EventProposalScreen()),
                      ),
                      if (isEventAdmin)
                        DashboardCard(
                          icon: Icons.fact_check,
                          title: 'Event Admin',
                          subtitle: 'Review proposals',
                          color: const Color(0xff9333ea),
                          onTap: () =>
                              open(context, const EventAdminPanelScreen()),
                        ),
                      if (isAdmin)
                        DashboardCard(
                          icon: Icons.admin_panel_settings,
                          title: 'Main Admin',
                          subtitle: 'Full management',
                          color: const Color(0xff0f172a),
                          onTap: () => open(context, const AdminPanelScreen()),
                        ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(
    BuildContext context,
    String title,
    String actionLabel,
    VoidCallback onAction,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 12, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String name;
  final String role;
  final VoidCallback? onAdmin;
  final VoidCallback onLogout;

  const _Header({
    required this.name,
    required this.role,
    required this.onAdmin,
    required this.onLogout,
  });

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff1d4ed8), Color(0xff2563eb)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'S',
              style: const TextStyle(
                color: Color(0xff2563eb),
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_greeting,',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  DateFormat('EEEE, d MMMM').format(DateTime.now()),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          if (onAdmin != null)
            IconButton(
              tooltip: 'Admin',
              onPressed: onAdmin,
              icon: const Icon(
                Icons.admin_panel_settings,
                color: Colors.white,
              ),
            ),
          IconButton(
            tooltip: 'Logout',
            onPressed: onLogout,
            icon: const Icon(Icons.logout, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Horizontal strip of today's classes + personal events, sorted by time.
class _TodaySchedule extends StatelessWidget {
  final FirestoreService service;
  final String userId;
  const _TodaySchedule({required this.service, required this.userId});

  @override
  Widget build(BuildContext context) {
    final weekday = DateFormat('EEEE').format(DateTime.now());
    final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.streamUserTimetable(userId),
      builder: (context, ttSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: service.streamUserCalendarEvents(userId),
          builder: (context, evSnap) {
            final items = <_Slot>[];
            for (final doc in ttSnap.data?.docs ?? []) {
              final d = doc.data();
              if ((d['day'] ?? '').toString() != weekday) continue;
              items.add(_Slot(
                start: (d['startTime'] ?? '').toString(),
                end: (d['endTime'] ?? '').toString(),
                title: (d['courseCode'] ?? d['courseName'] ?? 'Class')
                    .toString(),
                subtitle: (d['courseName'] ?? '').toString(),
                venue: (d['room'] ?? '').toString(),
                color: CourseUtils.colorFor((d['courseCode'] ?? '').toString()),
                isClass: true,
              ));
            }
            for (final doc in evSnap.data?.docs ?? []) {
              final d = doc.data();
              if ((d['date'] ?? '').toString() != dateKey) continue;
              items.add(_Slot(
                start: (d['startTime'] ?? '').toString(),
                end: (d['endTime'] ?? '').toString(),
                title: (d['title'] ?? 'Event').toString(),
                subtitle: (d['type'] ?? 'personal').toString(),
                venue: (d['location'] ?? '').toString(),
                color: const Color(0xff7c3aed),
                isClass: false,
              ));
            }
            items.sort((a, b) => a.start.compareTo(b.start));

            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: _EmptyCard(
                  icon: Icons.free_breakfast,
                  text: 'No classes or events today. Enjoy your day!',
                ),
              );
            }

            return SizedBox(
              height: 132,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(18, 10, 8, 0),
                itemCount: items.length,
                itemBuilder: (context, i) => _slotCard(context, items[i]),
              ),
            );
          },
        );
      },
    );
  }

  Widget _slotCard(BuildContext context, _Slot slot) {
    return Container(
      width: 210,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: slot.color, width: 5)),
        boxShadow: const [
          BoxShadow(color: Color(0x11000000), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${slot.start} - ${slot.end}',
            style: TextStyle(color: slot.color, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            slot.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          Text(
            slot.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xff64748b), fontSize: 12),
          ),
          const Spacer(),
          Row(
            children: [
              const Icon(Icons.place, size: 14, color: Color(0xff94a3b8)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  slot.venue.isEmpty ? 'No venue' : slot.venue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              if (slot.venue.isNotEmpty)
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LocationsScreen(initialQuery: slot.venue),
                    ),
                  ),
                  child: Icon(Icons.near_me, size: 18, color: slot.color),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Slot {
  final String start;
  final String end;
  final String title;
  final String subtitle;
  final String venue;
  final Color color;
  final bool isClass;
  const _Slot({
    required this.start,
    required this.end,
    required this.title,
    required this.subtitle,
    required this.venue,
    required this.color,
    required this.isClass,
  });
}

class _MyCoursesStrip extends StatelessWidget {
  final FirestoreService service;
  final String userId;
  const _MyCoursesStrip({required this.service, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.streamUserTimetable(userId),
      builder: (context, snapshot) {
        final courses = coursesFromTimetable(snapshot.data?.docs ?? []);
        if (courses.isEmpty) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(18, 10, 18, 0),
            child: _EmptyCard(
              icon: Icons.school,
              text: 'Upload your timetable to see your course cards here.',
            ),
          );
        }
        return SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(18, 10, 8, 0),
            itemCount: courses.length,
            itemBuilder: (context, i) => SizedBox(
              width: 150,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: CourseCard(course: courses[i]),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DueSoon extends StatelessWidget {
  final FirestoreService service;
  final String userId;
  const _DueSoon({required this.service, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.streamUserReminders(userId),
      builder: (context, snapshot) {
        final today = DateTime.now();
        final start = DateTime(today.year, today.month, today.day);
        final rows = (snapshot.data?.docs ?? [])
            .map((d) => d.data())
            .where((d) {
          final date = DateTime.tryParse((d['reminderDate'] ?? '').toString());
          return date != null && !date.isBefore(start);
        }).toList()
          ..sort((a, b) {
            final l = '${a['reminderDate']} ${a['reminderTime']}';
            final r = '${b['reminderDate']} ${b['reminderTime']}';
            return l.compareTo(r);
          });

        if (rows.isEmpty) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(18, 10, 18, 0),
            child: _EmptyCard(
              icon: Icons.check_circle,
              text: 'Nothing due soon. You are all caught up.',
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
          child: Column(
            children: rows.take(3).map((d) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.event, color: Color(0xffdc2626)),
                  title: Text((d['title'] ?? 'Reminder').toString()),
                  subtitle: Text(
                    '${d['reminderDate'] ?? '-'} at ${d['reminderTime'] ?? '-'}',
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffdfe7f3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xff94a3b8)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xff64748b)),
            ),
          ),
        ],
      ),
    );
  }
}
