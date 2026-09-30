import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../widgets/app_tile.dart';
import '../widgets/empty_state.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cats = state.categories;
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: cats.isEmpty
          ? const EmptyState(
              icon: Icons.grid_view_outlined,
              title: 'No categories',
              message: 'Refresh the index to load apps.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: cats.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final entry = cats.entries.elementAt(i);
                return Card(
                  child: ListTile(
                    title: Text(entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${entry.value.length} apps'),
                    trailing: const Icon(Icons.chevron_right),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CategoryAppsPage(
                            category: entry.key, apps: entry.value),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class CategoryAppsPage extends StatelessWidget {
  const CategoryAppsPage({super.key, required this.category, required this.apps});

  final String category;
  final List<AppEntry> apps;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(category)),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: apps.length,
        separatorBuilder: (_, _) => const SizedBox(height: 2),
        itemBuilder: (context, i) => AppTile(
          entry: apps[i],
          subtitleSuffix: apps[i].repo.name,
        ),
      ),
    );
  }
}
