import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../pages/app_details_page.dart';
import 'app_icon.dart';

class AppTile extends StatelessWidget {
  const AppTile({super.key, required this.entry, this.trailing, this.subtitleSuffix});

  final AppEntry entry;
  final Widget? trailing;
  final String? subtitleSuffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pkg = entry.package;
    return InkWell(
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
              builder: (_) => AppDetailsPage(entry: entry))),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            AppIcon(url: entry.iconUrl, name: pkg.name, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pkg.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pkg.summary.isEmpty ? pkg.packageName : pkg.summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  if (subtitleSuffix != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitleSuffix!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
