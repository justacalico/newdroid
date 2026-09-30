import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../widgets/app_tile.dart';
import '../widgets/download_button.dart';
import '../widgets/empty_state.dart';

class UpdatesPage extends StatelessWidget {
  const UpdatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final updates = state.updates;
    final installed = state.installedEntries;
    final upToDate = installed.where((e) => !e.hasUpdate).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Updates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Check installed apps',
            onPressed: state.refreshInstalled,
          ),
        ],
      ),
      body: updates.isEmpty && installed.isEmpty
          ? const EmptyState(
              icon: Icons.system_update_alt_outlined,
              title: 'Nothing installed',
              message: 'Apps you install will show up here.',
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (updates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Everything is up to date.'),
                  )
                else ...[
                  _Section('Updates available', updates.length),
                  for (final e in updates)
                    AppTile(
                      entry: e,
                      subtitleSuffix:
                          '${e.installed?.versionName ?? ''} → ${e.bestVersion?.versionName ?? ''}',
                      trailing: InstallButton(entry: e, compact: true),
                    ),
                ],
                if (upToDate.isNotEmpty) ...[
                  _Section('Installed', upToDate.length),
                  for (final e in upToDate)
                    AppTile(
                      entry: e,
                      subtitleSuffix: e.installed?.versionName,
                    ),
                ],
              ],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.count);

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        '$title · $count',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
