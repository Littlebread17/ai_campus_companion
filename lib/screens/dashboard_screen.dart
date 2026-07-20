import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/course_utils.dart';
import '../widgets/event_poster.dart';
import '../widgets/ui_kit.dart';
import 'admin_panel_screen.dart';
import 'announcements_screen.dart';
import 'calendar_screen.dart';
import 'event_detail_screen.dart';
import 'events_screen.dart';

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

        return Scaffold(
          backgroundColor: AppColors.background,
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

                // ---- Today ----
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                    child: _TodayCard(
                      service: service,
                      userId: userId,
                      onOpenCalendar: () =>
                          open(context, const CalendarScreen()),
                    ),
                  ),
                ),

                // ---- What's new ----
                _sectionTitle(
                  context,
                  "What's New",
                  'Announcements',
                  () => open(context, const AnnouncementsScreen()),
                ),
                SliverToBoxAdapter(
                  child: _WhatsNewFeed(service: service, userId: userId),
                ),

                // ---- Featured events ----
                _sectionTitle(
                  context,
                  'Featured Events',
                  'See all',
                  () => open(context, const EventsScreen()),
                ),
                SliverToBoxAdapter(child: _FeaturedEvents(service: service)),

                // ---- Due soon ----
                _sectionTitle(
                  context,
                  'Due Soon',
                  'Reminders',
                  () => open(context, const CalendarScreen(initialTab: 2)),
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

                const SliverToBoxAdapter(child: SizedBox(height: 96)),
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
          colors: [AppColors.primary, AppColors.secondary, AppColors.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.prominentRadius),
        boxShadow: AppTheme.softShadow,
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
                    color: AppColors.primary,
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
                  if (data['done'] == true) continue; // match Calendar Tasks
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

/// Compact "Today" card: today's classes + events + reminders, plus a one-line
/// preview of tomorrow. Replaces the old 14-day picker (the Calendar tab now
/// owns date browsing).
class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.service,
    required this.userId,
    required this.onOpenCalendar,
  });

  final FirestoreService service;
  final String userId;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.streamUserTimetable(userId),
      builder: (context, ttSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: service.streamUserCalendarEvents(userId),
          builder: (context, evSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: service.streamUserReminders(userId),
              builder: (context, remSnap) {
                if (ttSnap.hasError || evSnap.hasError || remSnap.hasError) {
                  return const _InlineDashboardError(
                    message: 'Could not load your day.',
                  );
                }
                final all = _buildItems(
                  ttSnap.data?.docs ?? [],
                  evSnap.data?.docs ?? [],
                  remSnap.data?.docs ?? [],
                );
                final now = DateTime.now();
                final tomorrow = now.add(const Duration(days: 1));
                final todayItems =
                    all.where((i) => DateUtils.isSameDay(i.date, now)).toList()
                      ..sort((a, b) => a.start.compareTo(b.start));
                final tomorrowCount = all
                    .where((i) => DateUtils.isSameDay(i.date, tomorrow))
                    .length;

                return AppCard(
                  padding: const EdgeInsets.all(16),
                  onTap: onOpenCalendar,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Today',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  DateFormat('EEEE, d MMM').format(now),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.faint,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (todayItems.isEmpty)
                        const _EmptyCard(
                          icon: Icons.free_breakfast,
                          text: 'Nothing scheduled today. Enjoy the free day.',
                        )
                      else
                        ...todayItems
                            .take(4)
                            .map((i) => _DashboardPlanTile(item: i)),
                      if (todayItems.length > 4)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '+ ${todayItems.length - 4} more today',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          const Icon(
                            Icons.wb_twilight,
                            size: 16,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tomorrowCount == 0
                                ? 'Tomorrow · nothing scheduled'
                                : 'Tomorrow · $tomorrowCount item${tomorrowCount == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
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

  List<_DashboardDayItem> _buildItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> timetableDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> eventDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> reminderDocs,
  ) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    // Only need today + tomorrow.
    final days = [start, start.add(const Duration(days: 1))];
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
          color: AppColors.eventColor,
          icon: Icons.event,
        ),
      );
    }

    for (final doc in reminderDocs) {
      final data = doc.data();
      if (data['done'] == true) continue;
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
              ? AppColors.danger
              : AppColors.reminderColor,
          icon: Icons.assignment_turned_in,
        ),
      );
    }
    return items;
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

/// Merged "what's new" feed: recent announcements + upcoming course reminders,
/// newest first.
class _WhatsNewFeed extends StatelessWidget {
  final FirestoreService service;
  final String userId;
  const _WhatsNewFeed({required this.service, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.streamCollection(
        'announcements',
        orderBy: 'createdAt',
        descending: true,
      ),
      builder: (context, annSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: service.streamUserReminders(userId),
          builder: (context, remSnap) {
            final items = <_FeedItem>[];

            for (final doc in annSnap.data?.docs ?? []) {
              final d = doc.data();
              final code = (d['courseCode'] ?? '').toString();
              items.add(
                _FeedItem(
                  icon: Icons.campaign,
                  color: (d['priority'] ?? '') == 'high'
                      ? const Color(0xffef4444)
                      : const Color(0xff2563eb),
                  title: (d['title'] ?? 'Announcement').toString(),
                  subtitle: code.isEmpty
                      ? (d['category'] ?? 'Campus').toString()
                      : '${CourseUtils.baseCode(code)} · ${d['category'] ?? 'Course'}',
                  when: _dashboardDate(d['createdAt']),
                ),
              );
            }

            final today = DateTime.now();
            final start = DateTime(today.year, today.month, today.day);
            for (final doc in remSnap.data?.docs ?? []) {
              final d = doc.data();
              if (d['done'] == true) continue; // match Calendar Tasks
              final date = _dashboardDate(d['reminderDate']);
              if (date == null || date.isBefore(start)) continue;
              items.add(
                _FeedItem(
                  icon: Icons.assignment_turned_in,
                  color: const Color(0xfff97316),
                  title: (d['title'] ?? 'Task due').toString(),
                  subtitle:
                      'Due ${d['reminderDate'] ?? ''} ${d['reminderTime'] ?? ''}'
                          .trim(),
                  when: date,
                ),
              );
            }

            items.sort((a, b) {
              final at = a.when ?? DateTime(1970);
              final bt = b.when ?? DateTime(1970);
              return bt.compareTo(at);
            });

            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: _EmptyCard(
                  icon: Icons.notifications_none,
                  text: 'Nothing new right now. Updates will appear here.',
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Column(
                children: items.take(5).map((item) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xffe2e8f0)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: item.color.withValues(alpha: 0.12),
                          child: Icon(item.icon, size: 18, color: item.color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
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
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }
}

class _FeedItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final DateTime? when;
  const _FeedItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.when,
  });
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
              if (d['done'] == true) return false; // match Calendar Tasks
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

/// Horizontal carousel of upcoming published events for the home page.
class _FeaturedEvents extends StatelessWidget {
  const _FeaturedEvents({required this.service});

  final FirestoreService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.streamCollection('events'),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final events =
            snap.data!.docs
                .where(
                  (d) => (d.data()['status'] ?? 'published') == 'published',
                )
                .toList()
              ..sort(
                (a, b) => '${a.data()['eventDate'] ?? ''}'.compareTo(
                  '${b.data()['eventDate'] ?? ''}',
                ),
              );
        if (events.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Text(
              'No upcoming events yet.',
              style: TextStyle(color: Color(0xff94a3b8)),
            ),
          );
        }
        return SizedBox(
          height: 232,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            itemCount: events.length,
            itemBuilder: (context, i) {
              final doc = events[i];
              final data = doc.data();
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventDetailScreen(eventId: doc.id),
                  ),
                ),
                child: Container(
                  width: 260,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xffe2e8f0)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EventPoster(
                        title: (data['title'] ?? 'Event').toString(),
                        host: (data['clubName'] ?? '').toString(),
                        posterUrl: (data['posterUrl'] ?? '').toString(),
                        height: 120,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (data['title'] ?? 'Event').toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${data['eventDate'] ?? '-'} · ${data['startTime'] ?? ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xff64748b),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
