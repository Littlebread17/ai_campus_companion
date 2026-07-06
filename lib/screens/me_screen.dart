import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'admin_panel_screen.dart';
import 'event_admin_panel_screen.dart';
import 'event_proposal_screen.dart';
import 'feedback_admin_screen.dart';
import 'feedback_screen.dart';
import 'my_results_screen.dart';
import 'notifications_screen.dart';
import 'timetable_upload_screen.dart';

class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final service = FirestoreService();
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'Student';

    return Scaffold(
      appBar: AppBar(title: const Text('Me')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: service.streamUserProfile(user?.uid ?? ''),
        builder: (context, snapshot) {
          final profile = snapshot.data?.data() ?? {};
          final role = (profile['role'] ?? 'student').toString();
          final name = (profile['name'] ?? email).toString();
          final isAdmin = role == 'admin';
          final isEventAdmin = role == 'event_admin' || isAdmin;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _profileCard(name, email, role, profile),
              const SizedBox(height: 16),
              _tile(
                context,
                Icons.upload_file,
                'Update my timetable',
                'Scan or edit your classes',
                const Color(0xff0891b2),
                () => _open(context, const TimetableUploadScreen()),
              ),
              _tile(
                context,
                Icons.school,
                'My results & CGPA',
                'Record grades and track CGPA',
                const Color(0xff16a34a),
                () => _open(context, const MyResultsScreen()),
              ),
              _tile(
                context,
                Icons.notifications,
                'Notifications',
                'Campus alerts and updates',
                const Color(0xff2563eb),
                () => _open(context, const NotificationsScreen()),
              ),
              _tile(
                context,
                Icons.assignment_add,
                'Event proposal',
                'Submit and track proposals',
                const Color(0xff9333ea),
                () => _open(context, const EventProposalScreen()),
              ),
              _tile(
                context,
                Icons.feedback_outlined,
                'Send feedback',
                'Share suggestions or report a bug',
                const Color(0xffea580c),
                () => _open(context, const FeedbackScreen()),
              ),
              if (isAdmin)
                _tile(
                  context,
                  Icons.reviews_outlined,
                  'View student feedback',
                  'Read all submitted feedback',
                  const Color(0xff0891b2),
                  () => _open(context, const FeedbackAdminScreen()),
                ),
              if (isEventAdmin)
                _tile(
                  context,
                  Icons.fact_check,
                  'Event admin',
                  'Review event proposals',
                  const Color(0xff7c3aed),
                  () => _open(context, const EventAdminPanelScreen()),
                ),
              if (isAdmin)
                _tile(
                  context,
                  Icons.admin_panel_settings,
                  'Main admin',
                  'Full campus management',
                  const Color(0xff0f172a),
                  () => _open(context, const AdminPanelScreen()),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => auth.logoutUser(),
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  'Log out',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _profileCard(
    String name,
    String email,
    String role,
    Map<String, dynamic> profile,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff2563eb), Color(0xff7c3aed)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'S',
              style: const TextStyle(
                color: Color(0xff2563eb),
                fontWeight: FontWeight.w900,
                fontSize: 24,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${profile['programme'] ?? role.replaceAll('_', ' ')}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
