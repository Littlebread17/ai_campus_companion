import 'package:flutter/material.dart';

import '../widgets/dashboard_card.dart';
import 'ai_agent_screen.dart';
import 'events_screen.dart';
import 'locations_screen.dart';
import 'resources_screen.dart';

/// Campus tab: navigation + campus-wide utilities.
class CampusTab extends StatelessWidget {
  const CampusTab({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campus')),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.05,
        children: [
          DashboardCard(
            icon: Icons.navigation,
            title: 'Navigation',
            subtitle: 'Arrow guide & map',
            color: const Color(0xff7c3aed),
            onTap: () => _open(context, const LocationsScreen()),
          ),
          DashboardCard(
            icon: Icons.folder,
            title: 'Resources',
            subtitle: 'IU Digital Hub',
            color: const Color(0xfff59e0b),
            onTap: () => _open(context, const ResourcesScreen()),
          ),
          DashboardCard(
            icon: Icons.event,
            title: 'Events',
            subtitle: 'Campus activities',
            color: const Color(0xff0f766e),
            onTap: () => _open(context, const EventsScreen()),
          ),
          DashboardCard(
            icon: Icons.smart_toy,
            title: 'Canva Assistant',
            subtitle: 'Ask anything',
            color: const Color(0xffec4899),
            onTap: () => _open(context, const AIAgentScreen()),
          ),
        ],
      ),
    );
  }
}
