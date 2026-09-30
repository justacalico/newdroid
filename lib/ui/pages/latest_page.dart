import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../widgets/app_tile.dart';
import '../widgets/download_button.dart';
import '../widgets/empty_state.dart';

class LatestPage extends StatelessWidget {
  const LatestPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('NewDroid'),
        actions: [
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh index',
              onPressed: state.refreshIndexes,
            ),
        ],
      ),
      body: _body(context, state),
    );
  }

  Widget _body(BuildContext context, AppState state) {
    if (state.isLoading && state.apps.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == IndexStatus.error && state.apps.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load repositories',
        message: state.error,
        action: FilledButton.tonal(
          onPressed: state.refreshIndexes,
          child: const Text('Try again'),
        ),
      );
    }
    final apps = state.latest;
    if (apps.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No apps yet',
        message: 'Enable a repository in Settings, then refresh.',
        action: FilledButton.tonal(
          onPressed: state.refreshIndexes,
          child: const Text('Refresh'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: state.refreshIndexes,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: apps.length,
        separatorBuilder: (_, _) => const SizedBox(height: 2),
        itemBuilder: (context, i) {
          final entry = apps[i];
          return AppTile(
            entry: entry,
            subtitleSuffix: entry.repo.name,
            trailing: InstallButton(entry: entry, compact: true),
          );
        },
      ),
    );
  }
}
