import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_state.dart';
import '../../models/index_models.dart';
import '../widgets/app_icon.dart';
import '../widgets/download_button.dart';

class AppDetailsPage extends StatelessWidget {
  const AppDetailsPage({super.key, required this.entry});

  final AppEntry entry;

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pkg = entry.package;
    final best = entry.bestVersion;
    final shots = entry.screenshotUrls;

    return Scaffold(
      appBar: AppBar(
        title: Text(pkg.name,
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(url: entry.iconUrl, name: pkg.name, size: 72),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(pkg.name,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    if (pkg.authorName != null)
                      Text(pkg.authorName!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(entry.repo.name,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: scheme.outline)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          InstallButton(entry: entry),
          if (entry.signerMismatch) ...[
            const SizedBox(height: 10),
            _Banner(
              icon: Icons.key_off_outlined,
              text: 'Installed app was signed by a different key. '
                  'Updating requires uninstalling first.',
            ),
          ],
          if (pkg.antiFeatures.isNotEmpty) ...[
            const SizedBox(height: 10),
            _Banner(
              icon: Icons.warning_amber_outlined,
              text: pkg.antiFeatures.entries
                  .map((e) => e.key)
                  .join(' · '),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (best != null) Chip(label: Text('v${best.versionName}')),
              if (best != null && best.size > 0)
                Chip(label: Text(_formatSize(best.size))),
              if (pkg.license != null) Chip(label: Text(pkg.license!)),
              for (final c in pkg.categories) Chip(label: Text(c)),
            ],
          ),
          if (shots.isNotEmpty) ...[
            const SizedBox(height: 20),
            SizedBox(
              height: 260,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: shots.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    shots[i],
                    height: 260,
                    errorBuilder: (_, _, _) => Container(
                      width: 130,
                      color: scheme.surfaceContainerHighest,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (best != null && best.whatsNew.isNotEmpty) ...[
            const _SectionTitle('What\'s new'),
            Text(best.whatsNew,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ],
          if (pkg.summary.isNotEmpty || pkg.description.isNotEmpty) ...[
            const _SectionTitle('About'),
            if (pkg.summary.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(pkg.summary,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w500)),
              ),
            if (pkg.description.isNotEmpty)
              Html(
                data: pkg.description,
                style: {
                  'body': Style(
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                    fontSize: FontSize(14),
                    color: scheme.onSurfaceVariant,
                  ),
                  'a': Style(color: scheme.primary),
                },
                onLinkTap: (url, _, _) {
                  if (url != null) {
                    launchUrl(Uri.parse(url),
                        mode: LaunchMode.externalApplication);
                  }
                },
              ),
          ],
          if (_links(pkg).isNotEmpty) ...[
            const _SectionTitle('Links'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final link in _links(pkg))
                  ActionChip(
                    avatar: const Icon(Icons.open_in_new, size: 16),
                    label: Text(link.$1),
                    onPressed: () => launchUrl(Uri.parse(link.$2),
                        mode: LaunchMode.externalApplication),
                  ),
              ],
            ),
          ],
          if (pkg.versions.length > 1) ...[
            const _SectionTitle('Versions'),
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < pkg.versions.length && i < 8; i++) ...[
                    if (i > 0) const Divider(indent: 16, endIndent: 16),
                    _VersionRow(version: pkg.versions[i], entry: entry),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<(String, String)> _links(FdroidPackage pkg) {
    final links = <(String, String)>[];
    if (pkg.webSite != null) links.add(('Website', pkg.webSite!));
    if (pkg.sourceCode != null) links.add(('Source', pkg.sourceCode!));
    if (pkg.issueTracker != null) {
      links.add(('Issues', pkg.issueTracker!));
    }
    if (pkg.changelog != null) links.add(('Changelog', pkg.changelog!));
    if (pkg.donate != null) links.add(('Donate', pkg.donate!));
    return links;
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({required this.version, required this.entry});

  final AppVersion version;
  final AppEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${version.versionName} (${version.versionCode})',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  [
                    AppDetailsPage._formatSize(version.size),
                    if (version.minSdk != null)
                      'SDK ${version.minSdk}+',
                    if (version.added > 0)
                      _formatDate(version.added),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurface)),
          ),
        ],
      ),
    );
  }
}
