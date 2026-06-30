import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/firestore_service.dart';
import '../services/iu_digital_hub_service.dart';

class ResourcesScreen extends StatefulWidget {
  final String initialKeyword;

  const ResourcesScreen({super.key, this.initialKeyword = ''});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  final service = FirestoreService();
  final searchController = TextEditingController();
  String keyword = '';

  @override
  void initState() {
    super.initState();
    keyword = widget.initialKeyword;
    searchController.text = widget.initialKeyword;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<DigitalHubResource> _mergeResources(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final byKey = <String, DigitalHubResource>{};

    for (final item in IUDigitalHubService.fallbackResources) {
      byKey[_keyFor(item)] = item;
    }

    for (final doc in docs) {
      final item = DigitalHubResource.fromMap(doc.data());
      if (item.url.trim().isEmpty) continue;
      byKey[_keyFor(item)] = item;
    }

    final items = byKey.values.where((item) => item.matches(keyword)).toList();
    items.sort((a, b) {
      final category = a.category.compareTo(b.category);
      return category == 0 ? a.title.compareTo(b.title) : category;
    });
    return items;
  }

  String _keyFor(DigitalHubResource item) {
    return '${item.title.toLowerCase()}|${item.url.toLowerCase()}';
  }

  Future<void> _openResource(DigitalHubResource item) async {
    final uri = Uri.tryParse(item.url);
    if (uri == null) {
      _showMessage('This resource link is not valid.');
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) _showMessage('Could not open ${item.title}.');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resource Locator')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: 'Search IU Digital Hub and saved resources',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => keyword = value),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: service.streamCollection(
                'resources',
                orderBy: 'createdAt',
                descending: true,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = _mergeResources(snapshot.data!.docs);
                if (items.isEmpty) {
                  return const Center(child: Text('No resources found.'));
                }

                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.folder,
                            color: Colors.orange,
                          ),
                          title: Text(item.title),
                          subtitle: Text(
                            '${item.category}\n${item.description}',
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            tooltip: 'Open resource',
                            onPressed: () => _openResource(item),
                            icon: const Icon(Icons.open_in_new),
                          ),
                          onTap: () => _openResource(item),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
