import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_state.dart';
import 'repos_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _Header('Repositories'),
          for (final repo in state.repos)
            SwitchListTile(
              title: Text(repo.name),
              subtitle: Text(repo.url,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              value: repo.enabled,
              onChanged: (v) => state.setRepoEnabled(repo, v),
            ),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Manage repositories'),
            subtitle: Text('${state.repos.length} configured'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ReposPage()),
            ),
          ),
          const _Header('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('Auto'),
                    icon: Icon(Icons.brightness_auto)),
                ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode)),
                ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode)),
              ],
              selected: {state.themeMode},
              onSelectionChanged: (s) => state.setThemeMode(s.first),
            ),
          ),
          const _Header('Index'),
          SwitchListTile(
            title: const Text('Refresh on launch'),
            subtitle: const Text('Update repository indexes when the app opens'),
            value: state.autoRefresh,
            onChanged: state.setAutoRefresh,
          ),
          SwitchListTile(
            title: const Text('Show incompatible apps'),
            subtitle:
                const Text('List apps that do not support this device'),
            value: state.showIncompatible,
            onChanged: state.setShowIncompatible,
          ),
          const _Header('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('NewDroid'),
            subtitle: const _VersionText(),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Source code'),
            subtitle: const Text('gitlab.com/HttpAnimations/newdroid'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => launchUrl(
                Uri.parse('https://gitlab.com/HttpAnimations/newdroid'),
                mode: LaunchMode.externalApplication),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _VersionText extends StatefulWidget {
  const _VersionText();

  @override
  State<_VersionText> createState() => _VersionTextState();
}

class _VersionTextState extends State<_VersionText> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((p) => setState(() => _version = 'v${p.version}'))
        .catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) =>
      Text(_version.isEmpty ? 'Free software client for F-Droid' : '$_version · Free software client for F-Droid');
}

class _Header extends StatelessWidget {
  const _Header(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
