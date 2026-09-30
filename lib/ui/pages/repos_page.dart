import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';

class ReposPage extends StatelessWidget {
  const ReposPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Repositories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addRepoDialog(context, state),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.repos.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final repo = state.repos[i];
          return Card(
            child: ListTile(
              title: Text(repo.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(repo.url,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: repo.enabled,
                    onChanged: (v) => state.setRepoEnabled(repo, v),
                  ),
                  if (!repo.builtIn)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Remove',
                      onPressed: () => state.removeRepo(repo),
                    ),
                ],
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addRepoDialog(BuildContext context, AppState state) {
    final controller = TextEditingController();
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add repository'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'https://example.com/fdroid/repo',
            labelText: 'Repository URL',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              state.addRepo(controller.text);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
