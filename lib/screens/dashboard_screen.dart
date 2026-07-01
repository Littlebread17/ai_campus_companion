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
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final email = user.email ?? 'Student';
    final userId = user.uid;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: service.streamUserProfile(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: _DashboardError(message: 'Could not load your profile.'),
          );
        }
        final profile = snapshot.data?.data() ?? {};
        final role = (profile['role'] ?? 'student').toString();
        final name = (profile['name'] ?? email).toString();
        final isAdmin = role == 'admin';
        final isEventAdmin = role == 'event_admin' || isAdmin;

        return Scaffold(
          backgroundColor: const Color(0xfff6f8ff),
          floatingActionButton: FloatingActionButton(
            tooltip: 'Talk to Canva',
            onPressed: () => open(context, const AIAgentScreen()),
            backgroundColor: const Color(0xff7c3aed),
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

                SliverToBoxAdapter(
                  child: _SummaryChips(service: service, userId: userId),
                ),

                // ---- Calendar planner ----
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                    child: _DashboardCalendarPlanner(
                      service: service,
                      userId: userId,
                      onOpenCalendar: () =>
                          open(context, const CalendarScreen()),
                    ),
                  ),
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

                // ---- Announcements preview ----
                _sectionTitle(
                  context,
                  'Announcements',
                  'See all',
                  () => open(context, const AnnouncementsScreen()),
                ),
                SliverToBoxAdapter(
                  child: _AnnouncementsPreview(service: service),
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
                  sliver: SliverToBoxAdapter(
                    child: _CompactTools(
                      tools: [
                        _ToolItem(
                          icon: Icons.upload_file,
                          label: 'Upload',
                          color: const Color(0xff0891b2),
                          onTap: () =>
                              open(context, const TimetableUploadScreen()),
                        ),
                        _ToolItem(
                          icon: Icons.calendar_month,
                          label: 'Timetable',
                          color: const Color(0xff16a34a),
                          onTap: () => open(context, const TimetableScreen()),
                        ),
                        _ToolItem(
                          icon: Icons.folder,
                          label: 'Resources',
                          color: const Color(0xfff59e0b),
                          onTap: () => open(context, const ResourcesScreen()),
                        ),
                        _ToolItem(
                          icon: Icons.event,
                          label: 'Events',
                          color: const Color(0xff0f766e),
                          onTap: () => open(context, const EventsScreen()),
                        ),
                        _ToolItem(
                          icon: Icons.map,
                          label: 'Navigation',
                          color: const Color(0xff7c3aed),
                          onTap: () => open(context, const LocationsScreen()),
                        ),
                        _ToolItem(
                          icon: Icons.smart_toy,
                          label: 'Canva',
                          color: const Color(0xffec4899),
                          onTap: () => open(context, const AIAgentScreen()),
                        ),
                      ],
                    ),
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
                        onTap: () => open(context, const EventProposalScreen()),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff2563eb), Color(0xff7c3aed), Color(0xff06b6d4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'S',
                  style: const TextStyle(
                    color: Color(0xff2563eb),
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
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
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, d MMMM').format(DateTime.now()),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
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
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _HeaderBadge(icon: Icons.calendar_today, label: 'Planner'),
              _HeaderBadge(icon: Icons.auto_awesome, label: 'AI support'),
              _HeaderBadge(icon: Icons.school, label: 'Courses'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeaderBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

DateTime? _dashboardDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

class _DashboardError extends StatelessWidget {
  final String message;
  const _DashboardError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 42, color: Color(0xffef4444)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineDashboardError extends StatelessWidget {
  final String message;
  const _InlineDashboardError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xfffff1f2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xffffcdd2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xffef4444)),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _SummaryChips extends StatelessWidget {
  final FirestoreService service;
  final String userId;
  const _SummaryChips({required this.service, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.streamUserReminders(userId),
      builder: (context, reminderSnap) {
        if (reminderSnap.hasError) {
          return const _InlineDashboardError(
            message: 'Could not load reminder summary.',
          );
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: service.streamUserTimetable(userId),
          builder: (context, timetableSnap) {
            if (timetableSnap.hasError) {
              return const _InlineDashboardError(
                message: 'Could not load timetable summary.',
              );
            }
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: service.streamUserCalendarEvents(userId),
              builder: (context, eventSnap) {
                if (eventSnap.hasError) {
                  return const _InlineDashboardError(
                    message: 'Could not load calendar summary.',
                  );
                }
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final endOfWeek = today.add(
                  Duration(days: DateTime.sunday - today.weekday),
                );
                var todayCount = 0;
                var overdueCount = 0;
                var weekCount = 0;

                for (final doc in reminderSnap.data?.docs ?? []) {
                  final data = doc.data();
                  final date = _dashboardDate(data['reminderDate']);
                  if (date == null) continue;
                  final day = DateTime(date.year, date.month, date.day);
                  if (day == today) todayCount++;
                  if (day.isBefore(today)) overdueCount++;
                  if (!day.isBefore(today) && !day.isAfter(endOfWeek)) {
                    weekCount++;
                  }
                }

                final weekday = DateFormat('EEEE').format(now);
                for (final doc in timetableSnap.data?.docs ?? []) {
                  if ((doc.data()['day'] ?? '').toString() == weekday) {
                    todayCount++;
                    weekCount++;
                  }
                }

                final dateKey = DateFormat('yyyy-MM-dd').format(now);
                for (final doc in eventSnap.data?.docs ?? []) {
                  final date = (doc.data()['date'] ?? '').toString();
                  if (date == dateKey) todayCount++;
                }

                return Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SummaryPill(
                          label: 'Today',
                          value: todayCount,
                          color: const Color(0xfff97316),
                          icon: Icons.today,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SummaryPill(
                          label: 'Overdue',
                          value: overdueCount,
                          color: const Color(0xffef4444),
                          icon: Icons.warning_amber,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SummaryPill(
                          label: 'This Week',
                          value: weekCount,
                          color: const Color(0xff2563eb),
                          icon: Icons.date_range,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  const _SummaryPill({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 5),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DashboardCalendarPlanner extends StatefulWidget {
  final FirestoreService service;
  final String userId;
  final VoidCallback onOpenCalendar;
  const _DashboardCalendarPlanner({
    required this.service,
    required this.userId,
    required this.onOpenCalendar,
  });

  @override
  State<_DashboardCalendarPlanner> createState() =>
      _DashboardCalendarPlannerState();
}

class _DashboardCalendarPlannerState extends State<_DashboardCalendarPlanner> {
  DateTime selected = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.service.streamUserTimetable(widget.userId),
      builder: (context, ttSnap) {
        if (ttSnap.hasError) {
          return const _InlineDashboardError(
            message: 'Could not load timetable planner.',
          );
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: widget.service.streamUserCalendarEvents(widget.userId),
          builder: (context, evSnap) {
            if (evSnap.hasError) {
              return const _InlineDashboardError(
                message: 'Could not load calendar planner.',
              );
            }
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: widget.service.streamUserReminders(widget.userId),
              builder: (context, reminderSnap) {
                if (reminderSnap.hasError) {
                  return const _InlineDashboardError(
                    message: 'Could not load assignment planner.',
                  );
                }
                final allItems = _buildDashboardItems(
                  ttSnap.data?.docs ?? [],
                  evSnap.data?.docs ?? [],
                  reminderSnap.data?.docs ?? [],
                );
                final selectedItems =
                    allItems
                        .where(
                          (item) => DateUtils.isSameDay(item.date, selected),
                        )
                        .toList()
                      ..sort((a, b) => a.start.compareTo(b.start));

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xffe2e8f0)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x0f000000), blurRadius: 12),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Calendar',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: widget.onOpenCalendar,
                            child: const Text('Open'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _TwoWeekDashboardRow(
                        selected: selected,
                        items: allItems,
                        onSelect: (day) => setState(() => selected = day),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _selectedTitle(selected),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (selectedItems.isEmpty)
                        const _EmptyCard(
                          icon: Icons.free_breakfast,
                          text:
                              'No classes, assignments, or events for this day.',
                        )
                      else
                        ...selectedItems
                            .take(4)
                            .map((item) => _DashboardPlanTile(item: item)),
                      if (selectedItems.length > 4)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: widget.onOpenCalendar,
                            child: Text('View all ${selectedItems.length}'),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  List<_DashboardDayItem> _buildDashboardItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> timetableDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> eventDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> reminderDocs,
  ) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final days = List.generate(14, (index) => start.add(Duration(days: index)));
    final items = <_DashboardDayItem>[];

    for (final doc in timetableDocs) {
      final data = doc.data();
      final dayName = (data['day'] ?? '').toString();
      final code = (data['courseCode'] ?? '').toString();
      for (final day in days) {
        if (DateFormat('EEEE').format(day) != dayName) continue;
        items.add(
          _DashboardDayItem(
            date: day,
            start: (data['startTime'] ?? '').toString(),
            title: code.isEmpty
                ? (data['courseName'] ?? 'Class').toString()
                : code,
            subtitle: (data['courseName'] ?? 'Class').toString(),
            type: 'Class',
            color: CourseUtils.colorFor(code),
            icon: Icons.school,
          ),
        );
      }
    }

    for (final doc in eventDocs) {
      final data = doc.data();
      final date = _dashboardDate(data['date'] ?? data['eventDate']);
      if (date == null) continue;
      items.add(
        _DashboardDayItem(
          date: DateTime(date.year, date.month, date.day),
          start: (data['startTime'] ?? '').toString(),
          title: (data['title'] ?? 'Event').toString(),
          subtitle: (data['location'] ?? data['type'] ?? 'Personal').toString(),
          type: 'Event',
          color: const Color(0xff7c3aed),
          icon: Icons.event,
        ),
      );
    }

    for (final doc in reminderDocs) {
      final data = doc.data();
      final date = _dashboardDate(data['reminderDate']);
      if (date == null) continue;
      items.add(
        _DashboardDayItem(
          date: DateTime(date.year, date.month, date.day),
          start: (data['reminderTime'] ?? '').toString(),
          title: (data['title'] ?? 'Assignment').toString(),
          subtitle: (data['courseCode'] ?? 'Reminder').toString(),
          type: 'Task',
          color: date.isBefore(start)
              ? const Color(0xffef4444)
              : const Color(0xfff97316),
          icon: Icons.assignment_turned_in,
        ),
      );
    }
    return items;
  }

  String _selectedTitle(DateTime value) {
    final today = DateTime.now();
    if (DateUtils.isSameDay(value, today)) {
      return 'Today - ${DateFormat('d MMM').format(value)}';
    }
    if (DateUtils.isSameDay(value, today.add(const Duration(days: 1)))) {
      return 'Tomorrow - ${DateFormat('d MMM').format(value)}';
    }
    return DateFormat('EEEE, d MMM').format(value);
  }
}

class _TwoWeekDashboardRow extends StatelessWidget {
  final DateTime selected;
  final List<_DashboardDayItem> items;
  final ValueChanged<DateTime> onSelect;
  const _TwoWeekDashboardRow({
    required this.selected,
    required this.items,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final days = List.generate(14, (index) => start.add(Duration(days: index)));

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = DateUtils.isSameDay(day, selected);
          final isToday = DateUtils.isSameDay(day, today);
          final count = items
              .where((item) => DateUtils.isSameDay(item.date, day))
              .length;
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onSelect(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 58,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xff2563eb)
                    : const Color(0xfff8fbff),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isToday
                      ? const Color(0xff2563eb)
                      : const Color(0xffe2e8f0),
                  width: isToday ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(day),
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? Colors.white70
                          : const Color(0xff64748b),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xff0f172a),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: count > 0
                          ? (isSelected
                                ? Colors.white
                                : const Color(0xfff97316))
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DashboardPlanTile extends StatelessWidget {
  final _DashboardDayItem item;
  const _DashboardPlanTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: item.color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              item.start.isEmpty ? '--:--' : item.start,
              style: TextStyle(color: item.color, fontWeight: FontWeight.w900),
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: item.color.withValues(alpha: 0.14),
            child: Icon(item.icon, size: 18, color: item.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xff64748b),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            flex: 0,
            child: Chip(
              label: Text(
                item.type,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              labelStyle: TextStyle(color: item.color, fontSize: 11),
              side: BorderSide.none,
              backgroundColor: item.color.withValues(alpha: 0.12),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardDayItem {
  final DateTime date;
  final String start;
  final String title;
  final String subtitle;
  final String type;
  final Color color;
  final IconData icon;
  const _DashboardDayItem({
    required this.date,
    required this.start,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.color,
    required this.icon,
  });
}

class _AnnouncementsPreview extends StatelessWidget {
  final FirestoreService service;
  const _AnnouncementsPreview({required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.streamCollection(
        'announcements',
        orderBy: 'createdAt',
        descending: true,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _InlineDashboardError(
            message: 'Could not load announcements.',
          );
        }
        final rows = snapshot.data?.docs ?? [];
        if (rows.isEmpty) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(18, 10, 18, 0),
            child: _EmptyCard(
              icon: Icons.campaign,
              text: 'No campus announcements right now.',
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
          child: Column(
            children: rows.take(3).map((doc) {
              final data = doc.data();
              final priority = (data['priority'] ?? 'normal').toString();
              final color = priority == 'high'
                  ? const Color(0xffef4444)
                  : const Color(0xff2563eb);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xffe2e8f0)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.12),
                      child: Icon(Icons.campaign, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (data['title'] ?? 'Announcement').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            (data['description'] ?? '').toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xff64748b),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _CompactTools extends StatelessWidget {
  final List<_ToolItem> tools;
  const _CompactTools({required this.tools});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: tools
          .map(
            (tool) => SizedBox(
              width: 112,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: tool.onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xffe2e8f0)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: tool.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(tool.icon, color: tool.color),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          tool.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ToolItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ToolItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
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
        if (snapshot.hasError) {
          return const _InlineDashboardError(
            message: 'Could not load due soon reminders.',
          );
        }
        final today = DateTime.now();
        final start = DateTime(today.year, today.month, today.day);
        final rows =
            (snapshot.data?.docs ?? []).map((d) => d.data()).where((d) {
              final date = _dashboardDate(d['reminderDate']);
              return date != null && !date.isBefore(start);
            }).toList()..sort((a, b) {
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
            child: Text(text, style: const TextStyle(color: Color(0xff64748b))),
          ),
        ],
      ),
    );
  }
}
