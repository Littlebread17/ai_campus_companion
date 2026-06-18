import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../widgets/dashboard_card.dart';
import 'announcements_screen.dart'; import 'resources_screen.dart'; import 'timetable_screen.dart'; import 'reminders_screen.dart'; import 'locations_screen.dart'; import 'events_screen.dart'; import 'ai_agent_screen.dart'; import 'admin_panel_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  void open(BuildContext context, Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  @override Widget build(BuildContext context) {
    final authService = AuthService(); final user = FirebaseAuth.instance.currentUser;
    return Scaffold(appBar: AppBar(title: const Text('AI Campus Companion'), actions: [IconButton(tooltip:'Admin Panel', onPressed: () => open(context, const AdminPanelScreen()), icon: const Icon(Icons.admin_panel_settings)), IconButton(tooltip:'Logout', onPressed: () async => authService.logoutUser(), icon: const Icon(Icons.logout))]), body: SingleChildScrollView(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Welcome, ${user?.email ?? 'Student'}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 6), const Text('Access campus information, resources, reminders and AI support.'), const SizedBox(height: 20),
      GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 2, crossAxisSpacing: 12, mainAxisSpacing: 12, children: [
        DashboardCard(icon: Icons.campaign, title: 'Announcements', subtitle: 'Campus updates', onTap: () => open(context, const AnnouncementsScreen())),
        DashboardCard(icon: Icons.folder, title: 'Resources', subtitle: 'Materials & links', onTap: () => open(context, const ResourcesScreen())),
        DashboardCard(icon: Icons.calendar_month, title: 'Timetable', subtitle: 'Class schedule', onTap: () => open(context, const TimetableScreen())),
        DashboardCard(icon: Icons.notifications, title: 'Reminders', subtitle: 'Personal alerts', onTap: () => open(context, const RemindersScreen())),
        DashboardCard(icon: Icons.map, title: 'Navigation', subtitle: 'Campus direction', onTap: () => open(context, const LocationsScreen())),
        DashboardCard(icon: Icons.event, title: 'Events', subtitle: 'Activities', onTap: () => open(context, const EventsScreen())),
        DashboardCard(icon: Icons.smart_toy, title: 'AI Agent', subtitle: 'Limited campus agent', onTap: () => open(context, const AIAgentScreen())),
        DashboardCard(icon: Icons.admin_panel_settings, title: 'Admin', subtitle: 'Add content', onTap: () => open(context, const AdminPanelScreen())),
      ]),
    ])));
  }
}
