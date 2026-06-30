import 'package:flutter/material.dart';
import 'bee_dashboard_screen.dart';

class HiveSelectionScreen extends StatelessWidget {
  const HiveSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Replace this with your real list of hives from your database/API
    final List<Map<String, String>> hives = [
      {'id': '1', 'name': 'Hive 1'},
      {'id': '2', 'name': 'Hive 2'},
      {'id': '3', 'name': 'Hive 3'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a Hive'),
        backgroundColor: Colors.amber[800],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: hives.length,
        itemBuilder: (context, index) {
          final hive = hives[index];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.hive, color: Colors.amber),
              title: Text(hive['name']!),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => BeeDashboardScreen(hiveId: hive['id']!),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
